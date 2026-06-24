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

## Drupal CLAUDE.md
For Drupal, we recommend using https://www.drupal.org/project/claude_code. You
can install by running:

```shell
ddev composer config extra.drupal-scaffold.allowed-packages --json --merge '["drupal/claude_code"]'
ddev composer require --dev drupal/claude_code
```
