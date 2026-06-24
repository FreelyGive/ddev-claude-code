# ddev-claude-code <!-- omit in toc -->

## Claude Code
Claude Code is installed inside the DDEV container and is run with `ddev claude`.

### Authenticating
The first time you run `ddev claude`, Claude Code walks you through its built-in
guided login. This is the recommended way to authenticate and covers the common
cases:

- **Claude subscription (Pro/Max)** — choose the subscription option and complete
  the browser login with your Claude.ai account.
- **Anthropic Console (pay-as-you-go API billing)** — choose the API option and
  complete the browser login with your [console.anthropic.com](https://console.anthropic.com)
  account.

If the container can't open a browser for you, Claude Code prints a URL to open
yourself and prompts for the code it gives you back.

Your credentials and configuration are stored under `.ddev/claude-code/` (the
`.claude.json` file and the `.claude/` directory, which holds the login
credentials in `.claude/.credentials.json`), and persist across restarts and
rebuilds. You can also copy an existing `.claude.json` / `.claude/` into
`.ddev/claude-code/` to reuse credentials, settings, or allowed tools from
another machine.

### API keys, cloud providers and self-hosted endpoints
For the cases the guided login doesn't cover — a raw API key, Amazon Bedrock,
Google Vertex AI, or a self-hosted/proxy endpoint — set the relevant environment
variables for the web container. DDEV reads them from a `.ddev/.env.web` file, so
create one with the variables for your chosen method:

```shell
# Anthropic API key (instead of the guided login)
ANTHROPIC_API_KEY=sk-ant-...

# Amazon Bedrock (AWS credentials must also be available in the container)
CLAUDE_CODE_USE_BEDROCK=1
AWS_REGION=us-east-1
AWS_PROFILE=my-profile

# Google Vertex AI (GCP credentials must also be available in the container)
CLAUDE_CODE_USE_VERTEX=1
ANTHROPIC_VERTEX_PROJECT_ID=my-project
CLOUD_ML_REGION=global

# Self-hosted / proxy endpoint (Anthropic API format)
ANTHROPIC_BASE_URL=https://gateway.example.com
ANTHROPIC_AUTH_TOKEN=...
```

These are secrets, so keep the file out of your repo by adding it to your
project's top-level `.gitignore`:

```shell
echo '.ddev/.env.web' >> .gitignore
```

Then `ddev restart` to apply. When these variables are set, Claude Code uses them
instead of the guided login.

Alternatively, set the variables globally so they apply to every project on your
machine without any per-project file. This also keeps them out of the repo:

```shell
ddev config global --web-environment-add="ANTHROPIC_API_KEY=sk-ant-..."
ddev restart
```

## Updating Claude Code

Claude Code is installed into the web container image, so it is pinned to whatever
version was current when that image was built. It is **not** updated automatically.

This add-on provides `ddev claude-update` to manage updates. On every `ddev start`
it also runs automatically (in report-only mode) and tells you when a newer version
is available.

```shell
# Check whether an update is available and how to apply it.
ddev claude-update -n

# Update straight away, no prompts.
ddev claude-update -y

# Prompt to choose how to update (when run in a terminal).
ddev claude-update
```

There are two ways to apply an update, and they differ in how long they last:

- **Instant (in the running container).** `ddev claude-update -y` updates Claude
  Code inside the current container in a few seconds. This is fast, but the change
  lives only in the running container and is lost the next time the image is
  rebuilt (for example on `ddev restart --no-cache` or a DDEV upgrade).
- **Permanent (rebuild the image).** Rebuilding the web image re-runs the installer
  and bakes in the latest version, so it survives future rebuilds. On DDEV v1.25.0
  or higher:

  ```shell
  ddev restart --no-cache
  ```

  This is slower (it rebuilds the image) but the update persists.

### Updating automatically on start

To always pick up the latest Claude Code instantly whenever a project starts, set
the `DDEV_CLAUDE_CODE_AUTOUPDATE` environment variable in your **host** shell (the
update command runs on the host, so a DDEV web-environment variable won't be seen):

```shell
# Add to your ~/.bashrc, ~/.zshrc, etc.
export DDEV_CLAUDE_CODE_AUTOUPDATE=1
```

With this set, the post-start hook applies the instant update on every start
instead of just reporting it. Remember this is the instant update, so for a version
that persists across rebuilds you still want `ddev restart --no-cache`.

## Drupal CLAUDE.md
For Drupal, we recommend using https://www.drupal.org/project/claude_code. You
can install by running:

```shell
ddev composer config extra.drupal-scaffold.allowed-packages --json --merge '["drupal/claude_code"]'
ddev composer require --dev drupal/claude_code
```
