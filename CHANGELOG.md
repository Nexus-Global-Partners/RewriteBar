# Changelog

## 1.4.0

* Adds an optional Codex Luna online processing mode backed by a user's ChatGPT subscription, while keeping the bundled Qwen model as the default.
* Isolates RewriteBar's Codex sign-in and ephemeral rewrite threads from the user's other Codex projects, tools, skills, and configuration.
* Gives Luna a short first attempt inside the existing rewrite deadline, then retries automatically with the warmed on-device model when Codex, the network, the account, the model, or the response is unavailable.
* Prepares the isolated Luna runtime when online mode is selected, briefly reuses verified account and model readiness, and scales the online attempt so short rewrites fall back faster without weakening output quality.
* Applies the same source-instruction protection, output cleanup, custom preferences, and meaning validation to both processing modes.
* Adds explicit online-processing disclosure, managed Codex connection status, and a local restore default in Settings without changing the menu bar popover.
* Keeps the Option R shortcut connected to the active editor when macOS temporarily omits the focused application from its system wide Accessibility object.
* Shows a native animated progress indicator in the menu bar while a shortcut rewrite is running.
* Adds a second native replacement path for editors such as WhatsApp that expose selected text but reject direct selected text updates.

## 1.3.2

* Removes Settings dividers for a cleaner, quieter surface in both appearances.
* Lets the shortcut rewrite any readable Accessibility selection, even when an editor incorrectly reports the selected text as read only. RewriteBar now attempts the native replacement at completion and safely copies the result if that editor rejects the replacement.

## 1.3.1

* Uses Option R by default, migrates the previous Command R default, and preserves custom shortcuts.
* Rewrites selections in editors that expose an editable plain text value instead of a directly writable selected text attribute.
* Keeps shortcut failures quiet by removing the system alert sound while retaining visible menu bar feedback.
* Lets custom instructions either add to the selected writing style or become the only added style direction.
* Enforces requests to avoid contractions after generation while preserving exact quoted passages.
* Makes Accessibility setup easier to notice and condenses the enabled state into a quiet status pin.
* Starts permission recovery automatically when a local rebuild invalidates an older Accessibility grant.
* Aligns the custom instruction placeholder with the native text cursor.
* Refines dark mode with a deeper graphite glass surface, softer text contrast, and restrained frosted controls.
* Expands the standard suite and real model benchmark coverage for personalization, fidelity, styles, intensity, and latency.

## 1.3.0

* Gives every intensity from 0 through 10 an explicit rewrite contract, from strict proofreading to full transformation.
* Adds five faithful writing styles: RewriteBar, Clear, Professional, Conversational, and Persuasive.
* Adds a configurable global shortcut that rewrites selected editable text and copies the result without leaving the current app.
* Adds a native Settings window for shortcut intensity, writing style, keyboard shortcut, Accessibility access, and optional custom instructions.
* Saves custom instructions automatically and turns common writing preferences into explicit model acceptance cues.
* Separates lowercase presentation from generation so spelling, grammar, punctuation, and sentence boundaries remain fully corrected.
* Retries safely without personalization when a preference causes an unchanged draft with obvious errors or introduces a sentence fragment.
* Adds a quiet Settings control inside the existing action surface without changing the popover height.
* Gives Settings the same neutral frosted glass surface as the menu bar popover.
* Shows rewrite progress and completion directly in the menu bar during shortcut use.
* Preserves the original selection if focus or content changes while the local model is working.
* Serializes menu and shortcut generation so concurrent use cannot corrupt shared model state.
* Adds deterministic protection for source instructions, facts, quoted text, uncertainty, commitments, and causal relationships.
* Falls back safely to a minimally cleaned source when a generated result fails meaning validation.
* Replaces the confusing Accessibility permission loop with one guided setup action and automatic permission detection.
* Refreshes stale Accessibility records created by older local builds before macOS asks for access to the current app.
* Closes the macOS Accessibility alert automatically once RewriteBar reports that access is ready.
* Shows a temporary Dock icon while Settings is open so the window remains easy to return to.
* Adds a standard 25 test suite and expands the model benchmark across every intensity, five styles, custom instructions, fidelity, and latency.
* Documents RewriteBar as an experiment in focused, local software that augments existing keyboard workflows.

## 1.2.7

* Makes rewrite progress follow text actually generated instead of appearing stuck near completion.
* Rejects document sized input immediately with a clear 2,000 character boundary.
* Copies every completed rewrite automatically, confirms Copied to Clipboard, closes the popover, and returns focus to the previous app when macOS permits it.
* Makes clipboard restore follow the same automatic confirmation and close flow.
* Adds one project check command, one agent guide, and a guarded release command for contributors and maintainers.

## 1.2.6

* Resumes interrupted release downloads and detects stalled transfers sooner.

## 1.2.5

* Keeps the menu bar item available during long idle periods with an AppKit-owned status item.

## 1.2.4

* Starts model warmup at foreground priority so the first rewrite is ready sooner.
* Removes the pause between finishing a rewrite and copying it to the clipboard.
* Keeps the local model ready for the next rewrite with a simpler runtime lifecycle.
* Keeps RewriteBar running when macOS hides its menu bar item.
* Hides the restore arrow after a rewrite has already been copied.

## 1.2.2

* Copies a finished rewrite automatically when the popover remains open.
* Confirms automatic copies with a clear checkmark and Copied state.
* Keeps background results ready for an intentional copy after reopening.
* Transforms the intensity slider into a smooth progress rail while rewriting.

## 1.2.1

* Uses Qwen3 1.7B with MLX for substantially faster local rewriting.
* Keeps the model warm while RewriteBar runs.
* Provides levels 0 through 10 with level 3 as the default.
* Uses a compact light glass interface with one slider and one action button.
* Adds a one step clipboard undo after copying a rewrite.
* Improves natural language rules and removes artificial corporate phrasing.
* Adds verified public installation and reproducible release automation.
