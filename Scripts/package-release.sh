#!/bin/zsh

set -euo pipefail
export COPYFILE_DISABLE=1

script_dir=${0:A:h}
project_dir=${script_dir:h}
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$project_dir/Configuration/Info.plist")
release_name="RewriteBar $version"
release_zip="$project_dir/dist/RewriteBar-$version.zip"
guide_source="$project_dir/AGENTS.md"

if [[ ! -s "$guide_source" ]]; then
    print -u2 "Missing agent guide: $guide_source"
    exit 1
fi

"$script_dir/build-app.sh"

staging_root=$(mktemp -d)
trap 'rm -rf "$staging_root"' EXIT
release_folder="$staging_root/$release_name"
source_folder="$staging_root/RewriteBar Source"
source_zip="$release_folder/RewriteBar Source.zip"

mkdir -p "$release_folder" "$source_folder"
ditto "$project_dir/dist/RewriteBar.app" "$release_folder/RewriteBar.app"
cp "$guide_source" "$release_folder/AGENTS.md"

for source_item in \
    .gitignore \
    .github \
    AGENTS.md \
    CHANGELOG.md \
    CODE_OF_CONDUCT.md \
    CONTRIBUTING.md \
    LICENSE \
    Package.swift \
    Package.resolved \
    README.md \
    RELEASING.md \
    SECURITY.md \
    BrandAssets \
    Configuration \
    ModelAssets/MLX \
    Scripts \
    Sources; do
    if [[ -e "$project_dir/$source_item" ]]; then
        ditto "$project_dir/$source_item" "$source_folder/$source_item"
    fi
done

(cd "$staging_root" && /usr/bin/zip -r -q -X -y "$source_zip" "${source_folder:t}")
mkdir -p "${release_zip:h}"
if [[ -e "$release_zip" ]]; then
    rm -f "$release_zip"
fi
(cd "$staging_root" && /usr/bin/zip -r -q -X -y "$release_zip" "${release_folder:t}")

print "Packaged $release_zip"
