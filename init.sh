#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$PWD"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: init.sh [--dry-run] [PROJECT_DIR]

Options:
  --dry-run, -n   Show planned file updates without changing files
  --help, -h      Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run|-n)
        DRY_RUN=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      -*)
        printf '[init] unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
      *)
        PROJECT_DIR="$1"
        ;;
    esac
    shift
  done
}

log() {
  printf '[init] %s\n' "$*"
}

dry_log() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[init] dry-run: %s\n' "$*"
  fi
}

prepend_managed_block() {
  local file="$1"
  local title="$2"
  local content="$3"
  local dir tmp begin_marker end_marker

  dir="$(dirname "$file")"
  begin_marker="<!-- BEGIN opencode-agent-orchestration: $title -->"
  end_marker="<!-- END opencode-agent-orchestration: $title -->"

  if [ "$DRY_RUN" = "1" ]; then
    if [ -f "$file" ] && grep -Fq "$begin_marker" "$file"; then
      dry_log "would replace managed block in $file"
    elif [ -f "$file" ]; then
      dry_log "would prepend managed block to existing $file"
    else
      dry_log "would create $file"
    fi
    return
  fi

  mkdir -p "$dir"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$begin_marker"
    printf '%s\n' "$content"
    printf '%s\n\n' "$end_marker"
    if [ -f "$file" ]; then
      awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        skip != 1 { print }
      ' "$file"
    fi
  } > "$tmp"

  cat "$tmp" > "$file"
  rm -f "$tmp"
  log "prepended $file"
}

main() {
  parse_args "$@"

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run mode: no files will be written"
  fi

  cd "$PROJECT_DIR"

  prepend_managed_block "AGENTS.md" "AGENTS" "$(cat <<'EOF'
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
EOF
)"

  prepend_managed_block "CLAUDE.md" "CLAUDE" "$(cat <<'EOF'
# Claude Code Instructions

You are the deep reasoning and refactoring agent for this repository.

Read this file together with:
- `AGENTS.md`
- `.agents/claude-worker.md`

Use Claude for:
- architecture analysis
- complex refactoring
- multi-file reasoning
- migration planning
- identifying hidden coupling
- explaining trade-offs

Avoid using Claude for:
- quick mechanical edits
- simple formatting
- trivial one-line fixes
- repetitive low-context tasks

Before editing, read relevant files, summarize the current design, and identify the smallest safe change.
Do not access secrets, run production deployment commands, modify infrastructure state, or rewrite large areas without an explicit plan.
EOF
)"

  prepend_managed_block "GEMINI.md" "GEMINI" "$(cat <<'EOF'
# Gemini CLI Instructions

You are the long-context analysis and documentation-review agent for this repository.

Read this file together with:
- `AGENTS.md`
- `.agents/gemini-worker.md`

Use Gemini for:
- broad repository understanding
- documentation review
- long-context analysis
- comparing code against docs
- identifying unclear boundaries
- producing structured summaries

Default mode:
- Prefer analysis over edits.
- Do not modify files unless explicitly asked.
- Read broadly before concluding.
- Look for inconsistencies across modules and documentation.
EOF
)"

  prepend_managed_block ".agents/codex-worker.md" "codex-worker" "$(cat <<'EOF'
# Codex Worker Prompt

You are Codex running as a worker through ai-cli-mcp.

Your strengths:
- implementation
- bug fixing
- test writing
- security review
- mechanical code changes
- verifying behavior with commands

Default mode:
- Be concrete.
- Prefer patches over abstract advice.
- Keep changes minimal.
- Run tests when possible.
- Return exact commands and results.

For review-only tasks, do not modify files. Return findings with severity and file paths.
For implementation tasks, modify only necessary files, preserve behavior unless asked otherwise, and run relevant verification commands.
EOF
)"

  prepend_managed_block ".agents/claude-worker.md" "claude-worker" "$(cat <<'EOF'
# Claude Worker Prompt

You are Claude Code running as a worker through ai-cli-mcp.

Your strengths:
- architecture analysis
- complex refactoring
- multi-file reasoning
- migration planning
- identifying hidden coupling
- explaining trade-offs

Default mode:
- Think through architecture and dependencies before proposing changes.
- Prefer incremental refactoring over broad rewrites.
- Preserve behavior unless asked otherwise.
- Identify tests that protect changed behavior.
- Return concrete risks, trade-offs, and implementation order.

For review-only tasks, do not modify files. Focus on architecture, coupling, testability, and maintainability.
For planning tasks, produce a step-by-step plan with risks and verification strategy.
EOF
)"

  prepend_managed_block ".agents/gemini-worker.md" "gemini-worker" "$(cat <<'EOF'
# Gemini Worker Prompt

You are Gemini running as a long-context analysis worker through ai-cli-mcp.

Your strengths:
- broad repository understanding
- documentation review
- long-context analysis
- comparing code against docs
- identifying unclear boundaries
- producing structured summaries

Default mode:
- Prefer analysis over edits.
- Do not modify files unless explicitly asked.
- Read broadly before concluding.
- Look for inconsistencies across modules and documentation.

Output format:
1. High-level summary
2. Important modules
3. Data/control flow
4. Inconsistencies
5. Documentation gaps
6. Suggested follow-up tasks
EOF
)"

  prepend_managed_block ".opencode/command/codex-security.md" "codex-security-command" "$(cat <<'EOF'
---
description: Run Codex security review through ai-cli-mcp
---

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
EOF
)"

  prepend_managed_block ".opencode/command/codex-tests.md" "codex-tests-command" "$(cat <<'EOF'
---
description: Ask Codex to find missing tests and propose implementation
---

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
EOF
)"

  prepend_managed_block ".opencode/command/claude-refactor.md" "claude-refactor-command" "$(cat <<'EOF'
---
description: Run Claude deep refactor review through ai-cli-mcp
---

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
EOF
)"

  prepend_managed_block ".opencode/command/claude-plan.md" "claude-plan-command" "$(cat <<'EOF'
---
description: Ask Claude to produce a deep implementation plan
---

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
EOF
)"

  prepend_managed_block ".opencode/command/gemini-architecture.md" "gemini-architecture-command" "$(cat <<'EOF'
---
description: Run Gemini long-context architecture overview through ai-cli-mcp
---

Use ai-cli-mcp to run Gemini in the current repository.

Worker profile:
Read AGENTS.md, GEMINI.md, and `.agents/gemini-worker.md`.

Task:
Create a long-context architecture overview of this repository.

Rules:
- Do not modify files.
- Read broadly.
- Identify main modules, data flow, runtime assumptions, and unclear boundaries.
- Compare docs against actual code where possible.
- Highlight missing or outdated documentation.
EOF
)"

  prepend_managed_block ".opencode/command/multi-review.md" "multi-review-command" "$(cat <<'EOF'
---
description: Run Codex, Claude, and Gemini in parallel and compare results
---

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
EOF
)"

  log "done"
}

main "$@"
