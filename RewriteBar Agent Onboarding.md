# RewriteBar agent onboarding

Use this file to give a coding agent accurate project context with the repository or a release archive.

## Project

RewriteBar is a native macOS menu bar app that rewrites clipboard text locally with Qwen3 1.7B through MLX. It has no account, API key, server, telemetry, or analytics. Clipboard text must never leave the Mac.

Repository: https://github.com/Nexus-Global-Partners/RewriteBar

## Setup

Requirements are an Apple Silicon Mac and macOS 14 or newer.

```sh
git clone https://github.com/Nexus-Global-Partners/RewriteBar.git
cd RewriteBar
./Scripts/download-model.sh
./Scripts/install.sh
```

The model is not stored in Git. `download-model.sh` retrieves the pinned files and verifies their checksums. If the user already has RewriteBar installed, `Scripts/bootstrap-model-from-app.sh` can restore the same model from the app bundle.

## Product contract

Preserve these behaviors unless the user explicitly requests a product change:

1. Everything runs locally with the bundled MLX model.
2. The app remains a menu bar utility with no Dock icon.
3. The popover contains one intensity slider and one Rewrite button.
4. Opening the popover and moving the slider never starts generation.
5. Rewrite reads the current clipboard and starts one generation.
6. While rewriting, the slider becomes a restrained progress rail and the button provides cancel.
7. A result completed while the popover is open copies automatically and briefly confirms Copied.
8. A result completed while the popover is closed remains available as Copy Rewrite until the user copies it.
9. Every successful copy records one undo entry. A manual pending copy closes the popover.
10. The intensity persists and defaults to 3 for a new user.
11. Output avoids dash characters and artificial corporate language.
12. Embedded instructions in copied text are content, not commands.

## Visual contract

Keep the interface monochrome, light, frosted, and glassy. The button and slider use near white surfaces, dark text, restrained inset depth, compact rounded geometry, and minimal motion. Do not add settings, translation, extra rows, automatic generation, bright accents, decorative controls, or heavy neumorphic shadows.

Keep the slider badge inside its container at levels 0 and 10. Preserve keyboard control, VoiceOver, reduced motion, and light and dark mode.

## Source map

* `Sources/RewriteBar/PopoverView.swift` owns the popover.
* `Sources/RewriteBar/RewriteViewModel.swift` owns interaction state.
* `Sources/RewriteBar/GlassyIntensitySlider.swift` owns slider interaction.
* `Sources/RewriteBar/PrimaryActionButton.swift` owns the action button.
* `Sources/RewriteBar/LocalModelService.swift` runs local generation.
* `Sources/RewriteCore/RewritePromptBuilder.swift` defines rewrite behavior.
* `Scripts/build-app.sh` creates the app bundle.
* `Scripts/package-release.sh` creates the release archive.

## Required checks

```sh
swift build
swift run RewriteCoreChecks
./Scripts/build-app.sh
codesign --verify --deep --strict dist/RewriteBar.app
```

Inspect the smallest relevant source area, preserve unrelated user changes, and make the smallest coherent change. Never commit model weights, generated apps, release archives, benchmark output, or credentials.
