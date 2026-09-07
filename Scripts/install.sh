#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
source_app="$project_dir/dist/RewriteBar.app"
install_dir="$HOME/Applications"
installed_app="$install_dir/RewriteBar.app"

"$script_dir/build-app.sh"
mkdir -p "$install_dir"

case "$installed_app" in
    "$HOME/Applications/RewriteBar.app") ;;
    *) print -u2 "Unexpected installation path"; exit 1 ;;
esac

pkill -x RewriteBar 2>/dev/null || true
for attempt in {1..30}; do
    pgrep -x RewriteBar >/dev/null || break
    sleep 0.1
done
if pgrep -x RewriteBar >/dev/null; then
    print -u2 "RewriteBar is still closing. Quit it and run the installer again."
    exit 1
fi
if [[ -e "$installed_app" ]]; then
    rm -rf "$installed_app"
fi

ditto "$source_app" "$installed_app"
print "Installed $installed_app"
codesign --verify --deep --strict "$installed_app"
open "$installed_app"
