#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
source_app=${1:-$HOME/Applications/RewriteBar.app}
model_name="Qwen3-1.7B-4bit"
source_model="$source_app/Contents/Resources/Models/$model_name"
source_shader="$source_app/Contents/MacOS/mlx.metallib"
destination_model="$project_dir/ModelAssets/$model_name"
destination_shader="$project_dir/ModelAssets/MLX/mlx.metallib"

if [[ ! -d "$source_app" ]]; then
    print -u2 "RewriteBar app not found at: $source_app"
    exit 1
fi

if [[ ! -s "$source_model/model.safetensors" ]]; then
    print -u2 "The app does not contain the expected local model."
    exit 1
fi

if [[ ! -s "$source_shader" ]]; then
    print -u2 "The app does not contain the expected MLX Metal library."
    exit 1
fi

case "$destination_model" in
    "$project_dir/ModelAssets/$model_name") ;;
    *) print -u2 "Unexpected model destination"; exit 1 ;;
esac

mkdir -p "${destination_model:h}" "${destination_shader:h}"
ditto "$source_model" "$destination_model"
cp "$source_shader" "$destination_shader"

print "Local model restored from $source_app"
print "Run ./Scripts/install.sh to build and install RewriteBar."
