#!/bin/bash

set -e
set -o pipefail

echo "[create-gitconfig-local] Setting up .gitconfig.local."
name="$(git config --global --includes user.name)" || true
if [[ $name ]]; then
    echo "[create-gitconfig-local] Full name: $name"
    echo -n "[create-gitconfig-local] Is this correct? (y/n) "
    read answer
    if ! (echo "$answer" | grep -qi "^y"); then
        name=
    fi
fi
while [[ -z $name ]]; do
    echo -n "[create-gitconfig-local] Full name: "
    read name
done

email="$(git config --global --includes user.email)" || true
if [[ $email ]]; then
    echo "[create-gitconfig-local] Email address: $email"
    echo -n "[create-gitconfig-local] Is this correct? (y/n) "
    read answer
    if ! (echo "$answer" | grep -qi "^y"); then
        email=
    fi
fi
while [[ -z $email ]]; do
    echo -n "[create-gitconfig-local] Email address: "
    read email
done

editor="$(git config --global --includes core.editor)" || true
if [[ $editor ]]; then
    echo "[create-gitconfig-local] Editor: $editor"
    echo -n "[create-gitconfig-local] Is this correct? (y/n) "
    read answer
    if ! (echo "$answer" | grep -qi "^y"); then
        editor=
    fi
fi
if [[ -z $editor ]]; then
    echo -n "[create-gitconfig-local] Editor (leave blank to use \$EDITOR or, as a fallback, vim): "
    read editor
fi

contents=

format=$(cat <<'EOF'
[user]
        name = %s
        email = %s
EOF
      )
contents="$contents$(printf "$format" "$name" "$email")"$'\n'

if [[ $editor ]]; then
    format=$(cat <<'EOF'
[core]
        editor = %s
EOF
          )
    contents="$contents$(printf "$format" "$editor")"$'\n'
fi

echo -n "$contents" > ../../radian-local/.gitconfig.local
echo "[create-gitconfig-local] Wrote the following to radian-local/.gitconfig.local:"
cat ../../radian-local/.gitconfig.local
