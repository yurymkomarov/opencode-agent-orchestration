## <!-- BEGIN opencode-agent-orchestration: claude-plan-command -->

## description: Ask Claude to produce a deep implementation plan

Use ai-cli-mcp to run Claude Code in the current repository.

Worker profile:
Read AGENTS.md, CLAUDE.md, and `.agents/claude-worker.md`.

Task:
Create a detailed implementation plan for the task I describe.

Rules:

- Do not modify files.
- Inspect relevant files.
- Produce a step-by-step plan.
- Identify risks and test strategy.
- Prefer small, reviewable commits.
- Mark each task with [ ] checkboxes.
<!-- END opencode-agent-orchestration: claude-plan-command -->
