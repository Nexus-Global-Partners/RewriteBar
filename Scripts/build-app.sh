#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_bundle="$project_dir/dist/RewriteBar.app"
release_dir="$project_dir/.build/arm64-apple-macosx/release"
model_source="$project_dir/ModelAssets/Qwen3-1.7B-4bit"
model_destination="$app_bundle/Contents/Resources/Models/Qwen3-1.7B-4bit"
mlx_shader_source="$project_dir/ModelAssets/MLX/mlx.metallib"
mlx_shader_checksums="$project_dir/Configuration/mlx-metallib.sha256"
app_icon_source="$project_dir/BrandAssets/infinity-app-icon.svg"

required_model_files=(
    config.json
    tokenizer.json
    tokenizer_config.json
    model.safetensors
)

for required_file in $required_model_files; do
    if [[ ! -s "$model_source/$required_file" ]]; then
        print -u2 "Missing bundled model file: $model_source/$required_file"
        print -u2 "Run ./Scripts/download-model.sh, then build again."
        exit 1
    fi
done

if [[ ! -s "$app_icon_source" ]]; then
    print -u2 "Missing app icon source: $app_icon_source"
    exit 1
fi

if [[ ! -s "$mlx_shader_source" ]]; then
    print -u2 "Missing pinned MLX Metal library: $mlx_shader_source"
    exit 1
fi

if ! (cd "${mlx_shader_source:h}" && shasum -a 256 -c "$mlx_shader_checksums" >/dev/null); then
    print -u2 "The pinned MLX Metal library failed checksum verification."
    exit 1
fi

stale_app_resource_bundle="$release_dir/RewriteBar_RewriteBar.bundle"
if [[ -e "$stale_app_resource_bundle" ]]; then
    rm -rf "$stale_app_resource_bundle"
fi

cd "$project_dir"
swift build -c release --arch arm64 --product RewriteBar

case "$app_bundle" in
    "$project_dir/dist/RewriteBar.app") ;;
    *) print -u2 "Unexpected app output path"; exit 1 ;;
esac

if [[ -e "$app_bundle" ]]; then
    rm -rf "$app_bundle"
fi

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$release_dir/RewriteBar" "$app_bundle/Contents/MacOS/RewriteBar"
cp "$project_dir/Configuration/Info.plist" "$app_bundle/Contents/Info.plist"
mkdir -p "${model_destination:h}"
ditto "$model_source" "$model_destination"
mlx_resource_bundle="$app_bundle/Contents/Resources/mlx-swift_Cmlx.bundle"
mkdir -p "$mlx_resource_bundle"
cp "$mlx_shader_source" "$mlx_resource_bundle/default.metallib"

icon_work_dir=$(mktemp -d)
trap 'rm -rf "$icon_work_dir"' EXIT
iconset="$icon_work_dir/RewriteBar.iconset"
icon_master="$icon_work_dir/RewriteBar-1024.png"
mkdir -p "$iconset"
sips -s format png "$app_icon_source" --out "$icon_master" >/dev/null
sips -z 16 16 "$icon_master" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_master" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_master" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_master" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_master" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_master" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_master" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_master" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_master" --out "$iconset/icon_512x512.png" >/dev/null
cp "$icon_master" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app_bundle/Contents/Resources/RewriteBar.icns"

for resource_bundle in "$release_dir"/*.bundle(N); do
    cp -R "$resource_bundle" "$app_bundle/Contents/Resources/"
done

codesign --force --deep --sign - "$app_bundle"
print "Built $app_bundle"
