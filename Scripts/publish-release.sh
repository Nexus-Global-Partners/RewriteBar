#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
info_plist="$project_dir/Configuration/Info.plist"
mode=${1:-publish}

if [[ "$mode" != "publish" && "$mode" != "--check" ]]; then
    print -u2 "Usage: ./Scripts/publish-release.sh [--check]"
    exit 1
fi

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist")
tag="v$version"

cd "$project_dir"
"$script_dir/check-project.sh"

if git rev-parse "$tag" >/dev/null 2>&1 \
    || git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    print -u2 "Tag $tag already exists. Update the app version and changelog first."
    exit 1
fi

if [[ "$mode" == "--check" ]]; then
    print "Release $tag is ready for review."
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    print -u2 "GitHub CLI is required. Install gh and try again."
    exit 1
fi

gh auth status >/dev/null

branch=$(git branch --show-current)
if [[ "$branch" != "main" ]]; then
    print -u2 "Publish from main after the release pull request is merged."
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    print -u2 "The worktree must be clean before publishing."
    exit 1
fi

git fetch origin main --tags

if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    print -u2 "Local main must exactly match origin/main."
    exit 1
fi

git tag -a "$tag" -m "RewriteBar $version"
git push origin "$tag"

run_id=""
for _ in {1..30}; do
    run_id=$(gh run list \
        --workflow release.yml \
        --limit 20 \
        --json databaseId,headBranch \
        --jq ".[] | select(.headBranch == \"$tag\") | .databaseId" \
        | head -1)
    [[ -n "$run_id" ]] && break
    sleep 2
done

if [[ -z "$run_id" ]]; then
    print -u2 "The tag was pushed, but the Release workflow was not found."
    exit 1
fi

gh run watch "$run_id" --exit-status
release_url=$(gh release view "$tag" --json url --jq .url)
print "Published RewriteBar $version."
print "$release_url"
