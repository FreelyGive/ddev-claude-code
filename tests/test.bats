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