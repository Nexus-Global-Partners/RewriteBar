# Contributing to RewriteBar

Thanks for helping improve RewriteBar.

## Before you start

Search existing Issues and Discussions. Open an issue before a large behavior, architecture, model, or interface change so the direction can be agreed first.

## Development

1. Fork the repository and create a focused branch.
2. Make the smallest coherent change.
3. Run the checks:

```sh
swift build
swift run RewriteCoreChecks
```

The normal checks do not require model weights. For a complete app build:

```sh
./Scripts/download-model.sh
./Scripts/build-app.sh
codesign --verify --deep --strict dist/RewriteBar.app
```

4. Describe the user facing effect and how you tested it in the pull request.

Never commit model weights, app bundles, release archives, benchmark output, clipboard content, or credentials.

## Product principles

RewriteBar should remain local, private, fast, focused, accessible, and visually restrained. New controls must justify their permanent cost in a tiny menu bar interface. Preserve the single slider and single action flow unless an issue explicitly agrees to change it.
