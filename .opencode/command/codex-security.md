## <!-- BEGIN opencode-agent-orchestration: codex-security-command -->

## description: Run Codex security review through ai-cli-mcp

Use ai-cli-mcp to run Codex in the current repository.

Worker profile:
Read AGENTS.md and `.agents/codex-worker.md`.

Task:
Perform a security-focused review of the current repository.

Rules:

- Do not modify files.
- Focus on authentication, authorization, secrets, input validation, dependency risks, unsafe shell execution, and deployment risks.
- Return findings with severity: critical, high, medium, low.
- Include file paths and concrete examples.
- Ignore purely stylistic issues.
<!-- END opencode-agent-orchestration: codex-security-command -->
