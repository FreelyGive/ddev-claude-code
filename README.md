# ddev-claude-code <!-- omit in toc -->

## Claude Code
Claude Code is installed inside the DDEV container and is accesible using
`ddev claude`. When you first run, you will be prompted to do this
interactively. Your configuration will be stored in `.ddev/.claude.json`
and `.ddev/.claude/`, and will be persisted across restarts.

You can copy in an existing `.ddev/.claude.json`, for example if you want to
use an existing key, or allowed functions etc.

To let Claude interact with GitLab, you will need to authenticate `glab`. This
can be done using `ddev glab auth login`. Configuration will be stored in
`.ddev/.glab-cli/` and will also be persisted across restarts.

## Drupal CLAUDE.me
For Drupal, we recommend using https://www.drupal.org/project/claude_code. You
can install by running:

```shell
ddev composer config extra.drupal-scaffold.allowed-packages --json --merge '["drupal/claude_code"]'
ddev composer require --dev drupal/claude_code
```
