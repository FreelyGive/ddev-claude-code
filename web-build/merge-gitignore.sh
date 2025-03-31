#ddev-generated
#!/bin/bash

ADDON_GITIGNORE="web-build/copy.gitignore"
ROOT_GITIGNORE=".gitignore"

# Ensure the root .gitignore exists
touch "$ROOT_GITIGNORE"

# Append non-duplicate lines from add-on's .gitignore
grep -Fxvf "$ROOT_GITIGNORE" "$ADDON_GITIGNORE" >> "$ROOT_GITIGNORE"
rm "$ADDON_GITIGNORE"
