# Security policy

Please do not open a public issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting on this repository. Include the affected version, reproduction steps, impact, and any suggested mitigation. Repository maintainers will acknowledge a useful report and coordinate a fix before public disclosure.

RewriteBar processes clipboard and selected text locally by default. Codex Luna mode is an explicit exception: a requested rewrite sends that text and any enabled custom instructions to OpenAI through an isolated Codex App Server sign-in. The isolated runtime must not load the user's normal Codex configuration, home, projects, environment credentials, MCP servers, tools, or skills. Command, image-view, web, browser, computer, app, plugin, skill, workspace-dependency, and dynamic tools are disabled at process startup; model-action network access and approvals are disabled; unexpected tool events fail closed; threads are ephemeral; and credentials are never stored in RewriteBar preferences or logs.

Reports involving network access while on-device mode is selected, online processing without clear opt-in, credential or configuration crossover, unexpected tool execution, data persistence, prompt injection that escapes the rewrite task, Accessibility access outside an explicit shortcut request, replacement of a changed selection, secure field access, release integrity, or installer integrity are especially important.
