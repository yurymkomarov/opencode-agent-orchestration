## <!-- BEGIN opencode-agent-orchestration: claude-refactor-command -->

## description: Run Claude deep refactor review through ai-cli-mcp

Use ai-cli-mcp to run Claude Code in the current repository.

Worker profile:
Read AGENTS.md, CLAUDE.md, and `.agents/claude-worker.md`.

Task:
Perform a deep refactoring review of the current repository.

Rules:

- Do not modify files.
- Focus on architecture, coupling, module boundaries, duplicated business logic, testability, and maintainability.
- Avoid cosmetic comments.
- Prefer incremental refactoring suggestions.
<!-- END opencode-agent-orchestration: claude-refactor-command -->
