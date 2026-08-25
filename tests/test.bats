#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # When CI is re-run with debug logging (RUNNER_DEBUG=1), make `run` print the
  # $output of every command on failure. This surfaces the post-start hook log
  # captured by `run ddev restart`, which is otherwise swallowed on success.
  [ "${RUNNER_DEBUG:-}" = "1" ] && export BATS_VERBOSE_RUN=1

  # Override this variable for your add-on:
  export GITHUB_REPO=FreelyGive/ddev-claude-code

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats:/usr/local/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site --omit-containers db,ddev-ssh-agent
  assert_success
  run ddev start -y
  assert_success
}

# DDEV runs post-start hooks non-fatally: a failing hook is logged but the command
# still exits 0. Assert the preceding command's output reported no failed hook, so a
# silently-broken hook (the class of bug behind the config-wiring regressions) is
# caught at the source.
refute_hook_failure() {
  refute_output --partial "Task failed"
}

health_checks() {
  # The whole point of the add-on: `ddev claude` runs the Claude Code CLI inside the
  # web container. --version needs no auth or network, so it just proves the binary
  # is installed and reachable on PATH.
  run ddev claude --version
  assert_success
  assert_output --partial "Claude Code"
}

# The user's config (API key, settings, MCP servers, auth state) lives in the host
# project under .ddev/claude-code and is wired into the container so Claude Code reads
# and writes it live — no restart needed. Verify BOTH directions through Claude's OWN
# behavior rather than by inspecting symlinks.
assert_config_round_trips() {
  # Host -> container: seed an MCP server into the persisted config and confirm Claude,
  # running in the container, detects it immediately. An MCP entry is a convenient probe
  # — plain JSON in ~/.claude.json (the file the add-on persists) that `claude mcp get`
  # reads back. The dummy command never connects, but detection is all we're testing.
  cat > "${TESTDIR}/.ddev/claude-code/.claude.json" <<'EOF'
{"mcpServers":{"ddev-host-marker":{"type":"stdio","command":"/bin/true","args":[]}}}
EOF
  # `claude mcp get` exits non-zero for an unknown server, so a successful lookup means
  # Claude Code actually parsed our config.
  run ddev claude mcp get ddev-host-marker
  assert_success
  assert_output --partial "ddev-host-marker"
  # "User config" scope confirms Claude read it from ~/.claude.json specifically — the
  # file the add-on symlinks into the container — and not some project-local config.
  assert_output --partial "User config"

  # Container -> host: write config via `ddev claude` and confirm it lands back in the
  # host-side file, so interactive setup (auth, etc.) persists into the project. Claude
  # writes its config atomically, so this also guards against the write replacing the
  # symlink with a detached regular file.
  run ddev claude mcp add ddev-claude-marker -s user -- /bin/true
  assert_success
  run cat "${TESTDIR}/.ddev/claude-code/.claude.json"
  assert_success
  assert_output --partial "ddev-claude-marker"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  refute_hook_failure
  health_checks
  assert_config_round_trips
}

# `ddev claude-update` reports and applies Claude Code updates. Force an older version
# into the running container to create a deterministic "update available" state, then
# drive the command through its report (-n), update (-y), up-to-date and env-var paths.
@test "claude-update flow" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  refute_hook_failure

  # Discover a real, downloadable version older than "latest" to pin as the stale
  # starting point. There's no version-index endpoint, but each version exposes a
  # manifest.json (200 if it exists, 404 otherwise), so walk the patch number down
  # from latest until one resolves. This stays correct as releases come and go.
  local base="https://downloads.claude.ai/claude-code-releases"
  local latest_version maj min pat old_version=""
  latest_version="$(curl -fsSL --max-time 10 "$base/latest")"
  IFS=. read -r maj min pat <<< "${latest_version}"
  for ((p = pat - 1; p >= 0 && p > pat - 50; p--)); do
    if curl -fs --max-time 10 -o /dev/null "$base/${maj}.${min}.${p}/manifest.json"; then
      old_version="${maj}.${min}.${p}"
      break
    fi
  done
  [ -n "${old_version}" ] || fail "no Claude Code version older than ${latest_version} found to test against"
  echo "# pinning old_version=${old_version} (latest=${latest_version})" >&3

  # Pin the old version. The add-on exposes claude via ~/bin, but its native updater
  # wants ~/.local/bin on PATH, so add it here too.
  run ddev exec 'PATH="$HOME/.local/bin:$PATH" claude install '"${old_version}"' --force'
  assert_success
  run ddev exec claude --version
  assert_success
  assert_output --partial "${old_version}"

  # -n reports an update is available but must NOT change the installed version.
  run ddev claude-update -n
  assert_success
  assert_output --partial "update is available"
  assert_output --partial "${old_version}"
  run ddev exec claude --version
  assert_output --partial "${old_version}"

  # -y applies the instant update, moving the version from the pin up to latest.
  run ddev claude-update -y
  assert_success
  run ddev exec claude --version
  assert_success
  assert_output --partial "${latest_version}"

  # Now current: -n reports up to date.
  run ddev claude-update -n
  assert_success
  assert_output --partial "up to date"

  # The DDEV_CLAUDE_CODE_AUTOUPDATE host env var turns a flagless run into an update.
  # Re-pin the old version first so this genuinely exercises the update path rather
  # than running against the now up-to-date system.
  run ddev exec 'PATH="$HOME/.local/bin:$PATH" claude install '"${old_version}"' --force'
  assert_success
  run ddev exec claude --version
  assert_output --partial "${old_version}"
  export DDEV_CLAUDE_CODE_AUTOUPDATE=1
  run ddev claude-update
  unset DDEV_CLAUDE_CODE_AUTOUPDATE
  assert_success
  run ddev exec claude --version
  assert_output --partial "${latest_version}"

  # The env var also beats an explicit -n. The post-start hook passes -n so it can
  # never prompt, so opting into auto-updates has to keep working through that flag.
  run ddev exec 'PATH="$HOME/.local/bin:$PATH" claude install '"${old_version}"' --force'
  assert_success
  export DDEV_CLAUDE_CODE_AUTOUPDATE=1
  run ddev claude-update -n
  unset DDEV_CLAUDE_CODE_AUTOUPDATE
  assert_success
  run ddev exec claude --version
  assert_output --partial "${latest_version}"
}

# The post-start hook runs `ddev claude-update` on every start. By default it only
# reports; with DDEV_CLAUDE_CODE_AUTOUPDATE set it applies the update. Bake an old
# version into the image so a freshly-started container is genuinely out of date,
# then restart with and without the env var to prove both hook behaviours.
@test "post-start hook auto-updates when enabled" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  # Discover a real, downloadable version older than latest (see "claude-update flow").
  local base="https://downloads.claude.ai/claude-code-releases"
  local latest_version maj min pat old_version=""
  latest_version="$(curl -fsSL --max-time 10 "$base/latest")"
  IFS=. read -r maj min pat <<< "${latest_version}"
  for ((p = pat - 1; p >= 0 && p > pat - 50; p--)); do
    if curl -fs --max-time 10 -o /dev/null "$base/${maj}.${min}.${p}/manifest.json"; then
      old_version="${maj}.${min}.${p}"
      break
    fi
  done
  [ -n "${old_version}" ] || fail "no Claude Code version older than ${latest_version} found to test against"
  echo "# baking old_version=${old_version} (latest=${latest_version})" >&3

  # Pin that old version into the built image so a started container is out of date.
  # Mirrors the add-on's own install line but targets a specific version.
  cat >> "${TESTDIR}/.ddev/web-build/Dockerfile.claude-code" <<EOF
RUN curl -fsSL https://claude.ai/install.sh | sudo -u \${username} bash -s -- ${old_version}
EOF

  # First start builds the old image. Without the env var the hook only reports, so
  # the container stays on the old version (this also proves no surprise auto-update).
  run ddev restart -y
  assert_success
  refute_hook_failure
  run ddev exec claude --version
  assert_success
  assert_output --partial "${old_version}"

  # With the env var, the post-start hook applies the update during start. The image
  # is unchanged, so the container restarts on the old version and the hook updates it.
  export DDEV_CLAUDE_CODE_AUTOUPDATE=1
  run ddev restart -y
  unset DDEV_CLAUDE_CODE_AUTOUPDATE
  assert_success
  refute_hook_failure
  run ddev exec claude --version
  assert_success
  assert_output --partial "${latest_version}"
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  refute_hook_failure
  health_checks
  assert_config_round_trips
}