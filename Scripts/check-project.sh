#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
info_plist="$project_dir/Configuration/Info.plist"
changelog="$project_dir/CHANGELOG.md"

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist")

plutil -lint "$info_plist" >/dev/null

if ! grep -q "^## $version$" "$changelog"; then
    print -u2 "CHANGELOG.md has no entry for RewriteBar $version."
    exit 1
fi

for required_file in AGENTS.md CONTRIBUTING.md README.md RELEASING.md SECURITY.md; do
    if [[ ! -s "$project_dir/$required_file" ]]; then
        print -u2 "Missing required project file: $required_file"
        exit 1
    fi
done

cd "$project_dir"
swift build
swift run RewriteCoreChecks

print "RewriteBar $version build $build checks passed."
