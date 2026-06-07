## <!-- BEGIN opencode-agent-orchestration: multi-review-command -->

## description: Run Codex, Claude, and Gemini in parallel and compare results

Use ai-cli-mcp to run three workers in parallel in the current repository:

1. Codex:
   Task: security and correctness review.
   Use AGENTS.md and `.agents/codex-worker.md`.

2. Claude:
   Task: deep refactoring and architecture review.
   Use AGENTS.md, CLAUDE.md, and `.agents/claude-worker.md`.

3. Gemini:
   Task: long-context architecture and documentation review.
   Use AGENTS.md, GEMINI.md, and `.agents/gemini-worker.md`.

Rules for all workers:

- Do not modify files.
- Do not access secrets.
- Include file paths where relevant.
- Prefer concrete findings over generic advice.

After all workers finish:

1. Wait for all results.
2. Deduplicate findings.
3. Separate confirmed issues from weak signals.
4. Highlight disagreements between agents.
5. Produce one prioritized action plan.
<!-- END opencode-agent-orchestration: multi-review-command -->
