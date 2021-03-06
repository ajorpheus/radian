#!/bin/bash

set -e
set -o pipefail

echo "[create-zshrc-before-local] Setting up .zshrc.before.local."
echo "[create-zshrc-before-local] There are a number of configurable parameters. You can configure them or leave them at the defaults for now."
echo "[create-zshrc-before-local] Either way, you can configure them later in .zshrc.before.local."
echo -n "[create-zshrc-before-local] Configure parameters now? (y/n) "
read answer
if (echo "$answer" | egrep -qi "^y"); then
    configure=true
else
    configure=false
fi

contents=$(cat <<'EOF'
#!/usr/bin/env zsh
# This file is run at the very beginning of .zshrc. This is the best
# place to override the various parameters shown below. If a new
# parameter has been added, delete this file and re-run setup.sh
# to get it to show up here. Or, you can just add the 'export' line
# yourself.
EOF
        )
contents="$contents"$'\n'
collected_comments=
while read -u 10 line; do
    if [[ $line == \#* ]]; then
        collected_comments="$collected_comments$line"$'\n'
    else
        if (echo "$line" | egrep -q "\\\$radian_[a-z_]+ != false"); then
            variable=$(echo "$line" | egrep -o "radian_[a-z_]+" | head -n 1)
            setting=true
            if [[ $configure == true ]]; then
                echo -n "$collected_comments"
                echo -n "[create-zshrc-before-local] Do you want this customization ($variable)? (y/n) "
                read answer
                if ! (echo "$answer" | egrep -qi "^y"); then
                    setting=false
                fi
            fi
            contents="$contents"$'\n'"${collected_comments}export $variable=$setting"$'\n'
        fi
        collected_comments=
    fi
done 10<../.zshrc

echo -n "$contents" > ../../radian-local/.zshrc.before.local
echo "[create-zshrc-before-local] Wrote the following to radian-local/.zshrc.before.local:"
cat ../../radian-local/.zshrc.before.local
