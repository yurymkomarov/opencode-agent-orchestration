<!-- BEGIN opencode-agent-orchestration: AGENTS -->

# Project Agent Instructions

## Mission

This repository is managed through OpenCode with ai-cli-mcp workers:

- Codex/OpenAI is the default operator model for OpenCode.
- Claude is a mandatory deep-refactor and architecture reasoning worker.
- Google/Gemini compatibility is a mandatory long-context overview, documentation, and second-opinion worker.
- Codex CLI can also be used as an implementation, tests, bug fixing, and security-review worker.

Agent-specific worker profiles:

- Codex worker: `.agents/codex-worker.md`
- Claude worker: `.agents/claude-worker.md`
- Gemini worker: `.agents/gemini-worker.md`

## Safety Rules

- Do not access or modify files outside this repository.
- Do not read or print secrets.
- Do not modify `.env`, `.env.*`, private keys, kubeconfigs, production credentials, or deployment secrets.
- Do not run destructive commands unless explicitly requested.
- Do not run `kubectl`, `terraform apply`, `helm upgrade`, or production deployment commands unless explicitly requested.
- Prefer read-only analysis unless the user asks for implementation.

## Work Style

- Before changing code, inspect the relevant files.
- For non-trivial changes, produce a short plan first.
- Prefer small, reviewable changes.
- Keep diffs focused.
- Do not mix refactoring and feature changes unless explicitly requested.
- Run relevant tests, linters, and type checks before claiming success.
- If tests cannot be run, explain exactly why.
<!-- END opencode-agent-orchestration: AGENTS -->
