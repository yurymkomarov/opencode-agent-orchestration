## <!-- BEGIN opencode-agent-orchestration: codex-tests-command -->

## description: Ask Codex to find missing tests and propose implementation

Use ai-cli-mcp to run Codex in the current repository.

Worker profile:
Read AGENTS.md and `.agents/codex-worker.md`.

Task:
Find the highest-value missing tests in this repository.

Rules:

- Do not modify files unless I explicitly ask in the next message.
- Identify risky untested behavior.
- Recommend specific test files and test cases.
- Include likely commands to run tests.
- Prioritize small tests with high value.
<!-- END opencode-agent-orchestration: codex-tests-command -->
