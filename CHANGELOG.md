# Changelog

## 1.3.0

* Gives every intensity from 0 through 10 an explicit rewrite contract, from strict proofreading to full transformation.
* Adds five faithful writing styles: RewriteBar, Clear, Professional, Conversational, and Persuasive.
* Adds a configurable global shortcut that rewrites selected editable text and copies the result without leaving the current app.
* Adds a native Settings window for shortcut intensity, writing style, keyboard shortcut, Accessibility access, and optional custom instructions.
* Shows rewrite progress and completion directly in the menu bar during shortcut use.
* Preserves the original selection if focus or content changes while the local model is working.
* Adds direct intensity contrast measurements to the model benchmark.
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
