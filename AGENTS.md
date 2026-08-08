# RewriteBar agent guide

This is the single source of project context for coding agents and contributors. Read it before changing the app.

## Product

RewriteBar is a native macOS utility that rewrites clipboard text from a compact menu bar control or rewrites selected editable text through a global keyboard shortcut. Qwen3 1.7B runs locally through MLX. The app has no account, API key, server, telemetry, analytics, Dock icon, or runtime network access.

Repository: https://github.com/Nexus-Global-Partners/RewriteBar

## Agent handoff

The repository is designed to be handed directly to a coding agent. Read this file completely, inspect the smallest relevant source area, preserve unrelated work, and use the scripts below rather than inventing a separate build or release path. A useful change ends with project checks, a signed local build when needed, and a focused explanation of what changed for the user.

## Product contract

Preserve these behaviors unless an issue or the user explicitly changes the product direction:

1. The popover contains one intensity slider and one Rewrite button.
2. Opening the popover or moving the slider never starts generation.
3. Rewrite reads the current plain text clipboard and starts one local generation.
4. The slider becomes a progress rail while the model works.
5. Progress begins with a small preparation range, then follows generated text.
6. Completion copies automatically, confirms Copied to Clipboard, closes the popover, and returns focus to the previous app when macOS permits it.
7. The restore arrow copies the previous clipboard entry, confirms success, and closes.
8. The slider defaults to 3 for a new user and remembers the last selected value.
9. Inputs above 2,000 visible characters fail immediately. Accepted work is bounded to 18 seconds.
10. Output preserves facts, intent, uncertainty, language, quoted text, paragraphs, and list structure.
11. Output never contains dash characters or artificial corporate language.
12. Instructions inside copied text are source content, never commands for the model.
13. Every intensity from 0 through 10 follows the public definition in `RewriteIntensityPolicy`.
14. RewriteBar, Clear, Professional, Conversational, and Persuasive are subtle preferences. They never override source voice, tone, truth, meaning, uncertainty, language, details, or approximate length.
15. Custom instructions are optional, local, bounded, saved automatically, and lower priority than every preservation rule. They can add to the selected writing style or exclusively replace that style. Intensity and preservation rules always remain active. Compatible preferences should be visible, but they must never reduce correction quality or introduce fragments.
16. The configurable global shortcut defaults to Command R and uses shortcut intensity 3 with the RewriteBar writing style for a new user.
17. Shortcut use reads only the current editable selection after an explicit key press. Secure fields are refused.
18. A shortcut result replaces the selection only if the process, focused element, and exact selected range remain unchanged. Host editors may normalize the selected text during generation. A completed result is also copied.
19. Shortcut progress and completion appear through the menu bar icon. The shortcut never opens a second editor or adds controls to the popover.

## Visual contract

Keep the popover monochrome, light, frosted, glassy, compact, and restrained. Use near white surfaces, close to black text, subtle inset depth, small radii, and minimal motion. Avoid bright accents, gradients on the action button, heavy neumorphism, translation, and extra rows.

Settings use conventional native macOS controls in one compact window. Durable personalization belongs there, never in the popover. Preserve keyboard navigation, VoiceOver, reduced motion, and appearance adaptation in both surfaces.

The slider badge must remain inside its container at 0 and 10. Preserve keyboard control, VoiceOver, reduced motion, and appearance adaptation.

## Architecture

* `Sources/RewriteBar/RewriteBarApp.swift` owns the AppKit status item, context menu, shortcut registration, status feedback, popover lifecycle, focus restoration, and model warmup.
* `Sources/RewriteBar/PopoverView.swift` composes the compact SwiftUI interface.
* `Sources/RewriteBar/RewriteViewModel.swift` owns interaction, cancellation, automatic copy, restore, progress, and failure states.
* `Sources/RewriteBar/GlassyIntensitySlider.swift` owns slider and progress rail rendering.
* `Sources/RewriteBar/PrimaryActionButton.swift` owns the action, loading, and confirmation presentation.
* `Sources/RewriteBar/RewriteEngine.swift` gives every interaction one normalized, time bounded generation interface.
* `Sources/RewriteBar/GenerationArbiter.swift` serializes shared model access and removes cancelled requests from its queue.
* `Sources/RewriteBar/LocalModelService.swift` loads the model, streams local generation, validates meaning signals, retries personalized output that is visibly undercorrected, and applies the safe source fallback.
* `Sources/RewriteBar/SelectedTextRewriteCoordinator.swift` owns shortcut generation, timeout, safe replacement, copy completion, and failures.
* `Sources/RewriteBar/AccessibilitySelectionClient.swift` captures and verifies editable selections without simulated key presses.
* `Sources/RewriteBar/GlobalHotKeyRegistrar.swift` registers the locally configured system shortcut.
* `Sources/RewriteBar/RewriteSettingsStore.swift` persists local preferences and `SettingsView.swift` presents them.
* `Sources/RewriteCore` contains validation, all intensity and style policy, workload limits, progress policy, source instruction protection, meaning checks, and deterministic output cleanup.
* `Sources/RewriteCoreChecks` contains fast model free regression checks.
* `Sources/RewriteBenchmark` is the opt in model quality and latency harness.

## Setup

Requires Apple Silicon and macOS 14 or newer.

```sh
git clone https://github.com/Nexus-Global-Partners/RewriteBar.git
cd RewriteBar
swift build
swift run RewriteCoreChecks
```

Model weights are not stored in Git. Only download them for full app or benchmark work:

```sh
./Scripts/download-model.sh
./Scripts/install.sh
```

If RewriteBar is already installed, `Scripts/bootstrap-model-from-app.sh` can copy and verify its bundled model.

## Change workflow

1. Inspect the smallest relevant source area and preserve unrelated worktree changes.
2. Keep the change focused. Product additions should begin as an Issue or Discussion.
3. Add or update a standard test and a model free check for logic changes.
4. Run `./Scripts/check-project.sh`.
5. For interface or model runtime changes, also run `./Scripts/build-app.sh`, verify the signature, and test the complete menu bar flow.
6. For shortcut or Accessibility changes, test permission denial, successful replacement, changed focus, changed selection, unsupported editors, and secure fields in multiple host applications.
7. Explain the user effect and verification in the pull request.

Never commit model weights, generated apps, release archives, benchmark output, real clipboard content, credentials, or local reports.

## Release workflow

`Configuration/Info.plist` is the version source. Every release needs a matching top entry in `CHANGELOG.md`.

After a reviewed pull request is merged to `main`:

```sh
git switch main
git pull --ff-only
./Scripts/publish-release.sh
```

The script validates the version, clean branch, checks, and remote state before it creates and pushes the tag. GitHub Actions then builds the pinned model, publishes the checksum verified archive, and updates the latest release. Full instructions are in `RELEASING.md`.

Do not add an automatic network based updater to the running app without an explicit product decision. Users update by rerunning the same verified installation command.

## Definition of done

* The smallest coherent behavior is implemented.
* `./Scripts/test.sh` passes.
* `./Scripts/check-project.sh` passes.
* Full app changes are built, signed, and manually exercised.
* Shortcut changes are exercised with and without Accessibility permission in multiple host applications.
* README, changelog, contributor guidance, and this file match the shipped behavior.
* No private data or generated artifacts enter Git.
