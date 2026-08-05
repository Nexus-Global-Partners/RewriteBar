#!/bin/zsh

set -euo pipefail

release_url="https://github.com/Nexus-Global-Partners/RewriteBar/releases/latest/download/RewriteBar.zip"
checksum_url="https://github.com/Nexus-Global-Partners/RewriteBar/releases/latest/download/RewriteBar.zip.sha256"
install_dir=${REWRITEBAR_INSTALL_DIR:-"$HOME/Applications"}
installed_app="$install_dir/RewriteBar.app"

download_root=$(mktemp -d)
trap 'rm -rf "$download_root"' EXIT
archive="$download_root/RewriteBar.zip"
checksum_file="$download_root/RewriteBar.zip.sha256"
expanded="$download_root/expanded"

download() {
    local url=$1
    local output=$2
    local attempt=1
    local maximum_attempts=10

    while (( attempt <= maximum_attempts )); do
        if curl \
            --fail \
            --location \
            --progress-bar \
            --connect-timeout 30 \
            --speed-limit 1024 \
            --speed-time 30 \
            --continue-at - \
            "$url" \
            --output "$output"; then
            return 0
        fi

        if (( attempt < maximum_attempts )); then
            print -u2 "Download interrupted. Resuming in 2 seconds."
            sleep 2
        fi
        (( attempt++ ))
    done

    print -u2 "Could not download RewriteBar after $maximum_attempts attempts."
    return 1
}

print "Downloading RewriteBar"
download "$release_url" "$archive"
download "$checksum_url" "$checksum_file"

expected_checksum=$(awk '{print $1}' "$checksum_file")
actual_checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ -z "$expected_checksum" || "$expected_checksum" != "$actual_checksum" ]]; then
    print -u2 "RewriteBar archive verification failed."
    exit 1
fi

mkdir -p "$expanded" "$install_dir"
ditto -x -k "$archive" "$expanded"
source_apps=("$expanded"/**/RewriteBar.app(N/))
if (( ${#source_apps} == 0 )); then
    print -u2 "RewriteBar.app was not found in the release archive."
    exit 1
fi
source_app=${source_apps[1]}

case "$installed_app" in
    "$install_dir/RewriteBar.app") ;;
    *) print -u2 "Unexpected installation path"; exit 1 ;;
esac

pkill -x RewriteBar 2>/dev/null || true
if [[ -e "$installed_app" ]]; then
    rm -rf "$installed_app"
fi
ditto "$source_app" "$installed_app"
codesign --verify --deep --strict "$installed_app"

print "Installed $installed_app"
if [[ ${REWRITEBAR_NO_OPEN:-0} != 1 ]]; then
    open -n "$installed_app"
fi
