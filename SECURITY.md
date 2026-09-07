# Security policy

Report vulnerabilities using GitHub's private vulnerability reporting, not a public issue. Include the affected version, reproduction steps, impact, and any suggested mitigation.

RewriteBar 2 sends explicitly selected text and enabled writing preferences to OpenAI through the user's ChatGPT subscription. It is an online app. It does not read text in the background and does not keep a rewrite history or application analytics.

The official signed Codex subprocess uses separate app-owned account storage and an empty working directory. It does not inherit the user's normal Codex configuration, projects, environment credentials, MCP servers, or skills. Command, image-view, web, browser, computer, app, plugin, skill, workspace-dependency, and dynamic tools are disabled at process startup. Model-action network access and approvals are disabled. Unexpected tool events fail closed, answers use a strict output schema, and threads are ephemeral. Account and usage status may be checked at startup or in Settings. Online processing remains subject to the user's OpenAI account terms and data controls.

Accessibility access is used only after the rewrite shortcut. Secure fields are refused. Results replace a selection only while the original process, focused field, and selection range remain valid. Otherwise the complete rewrite is copied with explicit feedback. Clipboard contents are not a generation input in version 2.

Reports involving credential or configuration crossover, tool execution, unintended data persistence, prompt injection, background text access, unsafe selection replacement, secure fields, or release/installer integrity are especially important.

Public builds are ad hoc signed and are not Apple notarized. The installer checks the published archive checksum and app signature. These checks establish consistency with the published artifact, not an Apple-verified developer identity.
