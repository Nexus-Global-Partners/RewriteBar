#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
model_dir="$project_dir/ModelAssets/Qwen3-1.7B-4bit"
checksums="$project_dir/Configuration/model-checksums.sha256"
base_url="https://huggingface.co/mlx-community/Qwen3-1.7B-4bit/resolve/main"

model_files=(
    added_tokens.json
    config.json
    merges.txt
    model.safetensors
    model.safetensors.index.json
    special_tokens_map.json
    tokenizer.json
    tokenizer_config.json
    vocab.json
)

verify_model() {
    local candidate=$1
    [[ -d "$candidate" ]] || return 1
    (cd "$candidate" && shasum -a 256 -c "$checksums" >/dev/null)
}

if verify_model "$model_dir"; then
    print "Model is already present and verified."
    exit 0
fi

download_root=$(mktemp -d)
trap 'rm -rf "$download_root"' EXIT
download_dir="$download_root/Qwen3-1.7B-4bit"
mkdir -p "$download_dir"

for model_file in $model_files; do
    print "Downloading $model_file"
    curl --fail --location --retry 3 --retry-delay 2 \
        "$base_url/$model_file?download=true" \
        --output "$download_dir/$model_file"
done

if ! verify_model "$download_dir"; then
    print -u2 "Model checksum verification failed. No project files were changed."
    exit 1
fi

mkdir -p "${model_dir:h}"
case "$model_dir" in
    "$project_dir/ModelAssets/Qwen3-1.7B-4bit") ;;
    *) print -u2 "Unexpected model destination"; exit 1 ;;
esac

if [[ -e "$model_dir" ]]; then
    rm -rf "$model_dir"
fi
ditto "$download_dir" "$model_dir"
print "Installed and verified $model_dir"
