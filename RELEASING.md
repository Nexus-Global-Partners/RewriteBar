# Releasing RewriteBar

RewriteBar releases are built by GitHub Actions from a version tag. The app itself never checks the network for updates. Existing users update by rerunning the verified install command from the README.

## Prepare the release

1. Create a focused branch from `main`.
2. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Configuration/Info.plist`.
3. Add the new version at the top of `CHANGELOG.md`.
4. Run:

```sh
./Scripts/publish-release.sh --check
```

5. Open a pull request. Wait for CI and review before merging.

## Publish after merge

```sh
git switch main
git pull --ff-only
./Scripts/publish-release.sh
```

The script refuses to publish unless:

* the current branch is `main`
* the worktree is clean
* local `main` exactly matches `origin/main`
* the changelog contains the app version
* the tag does not already exist
* the project checks pass

It creates and pushes the matching version tag, waits for the Release workflow, then prints the published release URL. The workflow downloads the checksum pinned model, builds and signs the app, creates `RewriteBar.zip`, creates its SHA256 file, and publishes both assets.

## Verify the public update

Use a temporary installation directory so the live app is untouched:

```sh
test_dir=$(mktemp -d)
curl -fsSL https://raw.githubusercontent.com/Nexus-Global-Partners/RewriteBar/main/Scripts/install-release.sh \
  | REWRITEBAR_INSTALL_DIR="$test_dir" REWRITEBAR_NO_OPEN=1 zsh
codesign --verify --deep --strict "$test_dir/RewriteBar.app"
```

Then check the [latest release](https://github.com/Nexus-Global-Partners/RewriteBar/releases/latest) and confirm that its version, archive, checksum, and generated notes are present.

## User update instruction

Users install and update with the same command:

```sh
curl -fsSL https://raw.githubusercontent.com/Nexus-Global-Partners/RewriteBar/main/Scripts/install-release.sh | zsh
```

The installer verifies the published checksum, replaces the previous copy in `~/Applications`, validates the app signature, and opens the new version.
