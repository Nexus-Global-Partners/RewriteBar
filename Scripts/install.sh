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

if [[ -e "$installed_app" ]]; then
    rm -rf "$installed_app"
fi

ditto "$source_app" "$installed_app"
print "Installed $installed_app"
print "Open it once from Finder, then use the infinity icon in the menu bar."
