# OpenCode Agent Orchestration Setup Guide

A practical setup for using OpenCode as the main AI coding interface with ai-cli-mcp workers for Codex CLI, Claude Code, and Google Gemini / Antigravity.

## Why this exists

Modern AI coding tools are fragmented:

- Codex CLI is useful for implementation and tests.
- Claude Code is strong for deep reasoning and refactoring.
- Gemini / Antigravity is useful for broad context and documentation review.
- OpenCode can act as the main terminal interface.

This repository wires them together through ai-cli-mcp so OpenCode can orchestrate local CLI agents as MCP workers.

> **Status:** Ready for implementation  
> **Audience:** Developers using OpenCode as the main AI coding interface and local CLI agents as workers  
> **Scope:** macOS and Linux  
> **Assumption:** OpenAI, Anthropic, and Google accounts already exist  
> **Last verified:** 2026-06-07

> [!WARNING]
> This setup can run local coding agents with elevated/non-interactive permissions.
> Use a disposable workspace, worktree, devcontainer, or VM.
> Do not run it in `$HOME` or in repositories containing real secrets.

---

## Table of Contents

1. [Target Architecture](#target-architecture)
2. [Prerequisites](#prerequisites)
3. [Create a Safe Workspace](#create-a-safe-workspace)
4. [Recommended Script Workflow](#recommended-script-workflow)
5. [Install and Configure OpenCode](#install-and-configure-opencode)
6. [Install and Configure Codex CLI](#install-and-configure-codex-cli)
7. [Install and Configure Claude Code CLI](#install-and-configure-claude-code-cli)
8. [Install and Configure Antigravity CLI and Gemini Compatibility](#install-and-configure-antigravity-cli-and-gemini-compatibility)
9. [Install and Validate ai-cli-mcp](#install-and-validate-ai-cli-mcp)
10. [Connect ai-cli-mcp to OpenCode](#connect-ai-cli-mcp-to-opencode)
11. [Create Agent Profiles](#create-agent-profiles)
12. [Create OpenCode Commands](#create-opencode-commands)
13. [Run Smoke Tests](#run-smoke-tests)
14. [Recommended Workflow](#recommended-workflow)
15. [Security Rules](#security-rules)
16. [Troubleshooting](#troubleshooting)
17. [Final Readiness Checklist](#final-readiness-checklist)
18. [Recommended Repository Structure](#recommended-repository-structure)
19. [Upstream References](#upstream-references)

---

## Target Architecture

The goal is to use **OpenCode** as the main interface and orchestrator, while **ai-cli-mcp** exposes local CLI agents as MCP tools.

```text
OpenCode
  └── MCP server: ai-cli-mcp
        ├── Codex CLI
        ├── Google Antigravity CLI / Gemini compatibility
        └── Claude Code CLI
```

### Responsibility Model

| Component                                     | Role                                                                                             |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| OpenCode                                      | Main interface; should run on a Codex/OpenAI model by default                                    |
| ai-cli-mcp                                    | MCP bridge that starts local CLI agents as background workers                                    |
| Codex / OpenAI model in OpenCode              | Default operator model through ChatGPT/OpenAI                                                    |
| Codex CLI                                     | Implementation, tests, bug fixing, security review                                               |
| Claude Code CLI                               | Mandatory deep reasoning, architecture review, complex refactoring worker                        |
| Google Antigravity CLI / Gemini compatibility | Mandatory long-context overview, documentation review, broad repository analysis, second opinion |

> **Important:** This setup does not create one shared context across all agents. Each worker receives a prompt and a working directory, then returns a result to OpenCode.

### Version and Source Notes

This guide intentionally prefers package-manager installs that stay easy to upgrade:

```text
1. Homebrew first where an official or project-recommended formula/cask exists
2. curl installer second where the upstream project documents one
3. npm/npx as fallback or where it is the only documented install path
```

As of 2026-06-07, the local validation environment used:

```text
OpenCode CLI: 1.16.2
Codex CLI: 0.137.0
Claude Code CLI: 2.1.153
Antigravity CLI: available as `agy`
Gemini CLI: 0.45.2
ai-cli-mcp: 2.21.0
```

### Google CLI Transition Note

Google announced on 2026-05-19 that Gemini CLI is transitioning to Antigravity CLI. Antigravity CLI is available now, and Gemini CLI / Gemini Code Assist IDE requests for consumer free, Google AI Pro, and Google AI Ultra users stop being served on 2026-06-18. Enterprise and paid API-key usage remains supported according to Google's announcement.

This setup therefore installs **Antigravity CLI** as the future Google CLI. It also keeps **Gemini CLI** installed for now because `ai-cli-mcp@2.21.0` still exposes Google worker models through the `gemini` backend. Once `ai-cli-mcp` adds an Antigravity/`agy` adapter, the Google worker commands should move from Gemini compatibility to Antigravity directly.

Do not hard-code these versions in a team setup unless you need reproducibility. Prefer checking current versions with the commands in the readiness checklist.

---

## Prerequisites

This document assumes:

```text
OS: macOS or Linux
Shell: zsh or bash
Node.js: installed
npm/npx: installed
git: installed
Accounts: OpenAI, Anthropic, and Google accounts are available
```

Check the local environment:

```bash
node --version
npm --version
npx --version
git --version
```

Recommended Node.js version:

```text
Node.js 20+
```

Node.js 20+ is recommended because the current Gemini compatibility backend requires Node.js 20 or higher. Claude Code's npm path requires Node.js 18 or higher. If you use only native Homebrew/curl installers for OpenCode, Codex, Claude, and Antigravity, Node is still useful for `ai-cli-mcp`, Gemini compatibility, and `npx`-based MCP startup.

### Install Node.js on macOS

```bash
brew install node
```

### Install Node.js on Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y nodejs npm git
```

---

## Create a Safe Workspace

Do not run AI agents directly in the home directory or in folders containing credentials.

Create a dedicated workspace:

```bash
mkdir -p ~/ai-workspaces
cd ~/ai-workspaces
```

Clone the target repository into a safe agent workspace:

```bash
git clone <YOUR_REPO_URL> my-project-agent
cd my-project-agent
```

Alternatively, create a Git worktree from an existing repository:

```bash
cd ~/projects/my-project
git worktree add ~/ai-workspaces/my-project-agent agent-playground
cd ~/ai-workspaces/my-project-agent
```

> **Security note:** Prefer a copy, Git worktree, devcontainer, ephemeral VM, or separate local user account for AI-agent experimentation.

---

## Recommended Script Workflow

This repository includes two scripts:

```text
install.sh  machine-level installation and global OpenCode MCP setup under $HOME
init.sh     project-level agent instructions and OpenCode commands in the target repository
```

Run `install.sh` once per machine:

```bash
./install.sh
```

Preview machine-level changes without installing packages or writing config:

```bash
./install.sh --dry-run
```

What `install.sh` does:

```text
- checks Node.js, npm, npx, OpenCode, Codex CLI, Claude Code CLI, Antigravity CLI, Gemini CLI compatibility, and ai-cli-mcp
- installs missing tools using Homebrew first, curl second where documented, and npm as fallback
- installs Claude, Antigravity CLI, and Gemini CLI compatibility as required worker tooling
- sets npm global prefix to $HOME/.local so npm-installed worker tooling stays under $HOME
- adds $HOME/.local/bin to the current shell rc file if needed
- creates or updates $HOME/.config/opencode/opencode.jsonc with OpenAI/Codex model defaults and the ai-cli-mcp MCP server
- prints version and diagnostic output
- supports `--dry-run` to preview package installs, PATH changes, and OpenCode config updates without writing files
```

Optional environment overrides:

```bash
AI_CLI_MCP_PACKAGE=ai-cli-mcp@2.21.0 ./install.sh
NPM_GLOBAL_PREFIX="$HOME/.local" ./install.sh
OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc" ./install.sh
OPENCODE_MODEL="openai/gpt-5.5" ./install.sh
OPENCODE_SMALL_MODEL="openai/gpt-5.5" OPENCODE_SMALL_MODEL_VARIANT="fast" ./install.sh
```

Run `init.sh` once per project workspace:

```bash
cd ~/ai-workspaces/my-project-agent
/path/to/opencode-agent-orchestration/init.sh
```

Or pass the project path explicitly:

```bash
./init.sh ~/ai-workspaces/my-project-agent
```

Preview project-level file changes without writing files:

```bash
./init.sh --dry-run ~/ai-workspaces/my-project-agent
```

What `init.sh` does:

```text
- creates or updates AGENTS.md
- creates or updates CLAUDE.md
- creates or updates GEMINI.md
- creates or updates .agents/codex-worker.md
- creates or updates .agents/claude-worker.md
- creates or updates .agents/gemini-worker.md
- creates or updates .opencode/command/*.md
- supports `--dry-run` to preview which files would be created or updated
```

If a file already exists, `init.sh` writes the managed block at the beginning of the file and keeps existing content below it. Re-running `init.sh` replaces the previous managed block instead of duplicating it.

---

## Install and Configure OpenCode

Install OpenCode with Homebrew first:

```bash
brew install anomalyco/tap/opencode
```

The OpenCode docs recommend the OpenCode tap for the most up-to-date Homebrew releases. The plain Homebrew formula may lag.

Alternatively, install with the official curl installer:

```bash
curl -fsSL https://opencode.ai/install | bash
```

Fallback via npm:

```bash
npm install -g opencode-ai
```

Verify installation:

```bash
opencode --version
opencode --help
```

Start OpenCode for the first time:

```bash
opencode
```

Inside OpenCode, connect a provider:

```text
/connect
```

Select the provider you want to use as the main OpenCode backend, for example:

```text
OpenAI / ChatGPT
Anthropic
GitHub Copilot
```

Then select a model:

```text
/models
```

Exit OpenCode:

```text
/q
```

Run a basic one-shot test:

```bash
opencode run "Summarize this repository in 5 bullet points."
```

Run with an explicit model:

```bash
opencode models openai
opencode run -m openai/<MODEL_FROM_LIST> "Summarize this repository."
```

or:

```bash
opencode models anthropic
opencode run -m anthropic/<MODEL_FROM_LIST> "Summarize this repository."
```

List available models:

```bash
opencode models
opencode models openai
opencode models anthropic
```

---

## Install and Configure Codex CLI

Install Codex CLI with Homebrew first:

```bash
brew install --cask codex
```

Alternatively, install with the official curl installer:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Fallback via npm:

```bash
npm install -g @openai/codex
```

Verify installation:

```bash
codex --version
codex --help
```

Authenticate:

```bash
codex login
```

On remote or headless machines, use device-code authentication if browser login cannot complete:

```bash
codex login --device-auth
```

For diagnostics:

```bash
codex doctor
```

Run a smoke test:

```bash
cd ~/ai-workspaces/my-project-agent
codex "Summarize this repository in 5 bullet points."
```

Run a non-interactive smoke test:

```bash
codex exec "Summarize this repository in 5 bullet points."
```

Recommended Codex model defaults currently start with `gpt-5.5` for complex coding work. For OpenCode's lightweight helper agents, this setup uses `openai/gpt-5.5` with `variant: fast` instead of a separate mini model. To pin the default local Codex CLI model:

```toml
model = "gpt-5.5"
```

> **Supply-chain warning:** Avoid unofficial npm packages or wrappers with names similar to Codex. Install only official packages or documented entrypoints.

---

## Install and Configure Claude Code CLI

Install Claude Code CLI with Homebrew first:

```bash
brew install --cask claude-code
```

For the latest release channel rather than the stable cask:

```bash
brew install --cask claude-code@latest
```

Alternatively, install with the official curl installer:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Fallback via npm:

```bash
npm install -g @anthropic-ai/claude-code
```

To upgrade an npm install, use:

```bash
npm install -g @anthropic-ai/claude-code@latest
```

Avoid `sudo npm install -g`; fix npm permissions instead.

Verify installation:

```bash
claude --version
claude --help
```

Authenticate:

```bash
claude auth login
```

Complete the login flow in the browser or terminal. Check auth state:

```bash
claude auth status
```

Run a smoke test:

```bash
cd ~/ai-workspaces/my-project-agent
claude -p "Summarize this repository in 5 bullet points."
```

### Non-interactive Permission Setup

For use through `ai-cli-mcp`, Claude Code may need to be initialized once in a non-interactive mode.

Run this only inside the safe workspace:

```bash
cd ~/ai-workspaces/my-project-agent
claude --dangerously-skip-permissions
```

Accept the required prompts, verify that the command starts correctly, then exit.

> **Warning:** `--dangerously-skip-permissions` is risky. Never run this in a directory containing production secrets, real kubeconfigs, SSH keys, or cloud credentials.

---

## Install and Configure Antigravity CLI and Gemini Compatibility

Install Antigravity CLI with Homebrew first:

```bash
brew install --cask antigravity-cli
```

Alternatively, install with the official curl installer:

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

The curl installer installs the `agy` binary under `~/.local/bin/agy`.

Verify installation:

```bash
agy --version
agy --help
```

Authenticate:

```bash
agy
```

Antigravity CLI uses Google sign-in and secure local token storage. On a local machine it can open the browser automatically; over SSH it prints an authorization URL and asks you to paste back the resulting code.

### Gemini CLI Compatibility

For now, install Gemini CLI as a compatibility backend for `ai-cli-mcp`.

Install with Homebrew first:

```bash
brew install gemini-cli
```

Fallback via npm:

```bash
npm install -g @google/gemini-cli@latest
```

Run without installing:

```bash
npx https://github.com/google-gemini/gemini-cli
```

Verify installation:

```bash
gemini --version
gemini --help
```

Authenticate:

```bash
gemini
```

Choose Google sign-in and complete the browser login flow. Alternative authentication options include `GEMINI_API_KEY` and Vertex AI environment variables.

> **Transition note:** For consumer free, Google AI Pro, and Google AI Ultra usage, Gemini CLI request serving ends on 2026-06-18. Keep Gemini CLI here only while `ai-cli-mcp` still requires the `gemini` binary for Google worker models. Treat Antigravity CLI as the forward-looking Google CLI.

Run a smoke test:

```bash
cd ~/ai-workspaces/my-project-agent
gemini -p "Summarize this repository in 5 bullet points."
```

Run with a specific model:

```bash
gemini -m gemini-2.5-flash -p "Summarize this repository in 5 bullet points."
```

---

## Install and Validate ai-cli-mcp

`ai-cli-mcp` is currently distributed through npm. There is no official Homebrew formula or curl installer documented for this package.

Install globally for easier diagnostics:

```bash
npm install -g ai-cli-mcp
```

Verify installation:

```bash
ai-cli --help
```

Do not use `ai-cli-mcp --help` as a help check. The `ai-cli-mcp` binary starts the MCP server over stdio.

Run diagnostics:

```bash
ai-cli doctor
```

List available model aliases:

```bash
ai-cli models
```

Current `ai-cli-mcp@2.21.0` model groups include:

```text
Claude: sonnet, sonnet[1m], opus, opusplan, haiku
Codex: gpt-5.4, gpt-5.5, gpt-5.4-mini, gpt-5.3-codex, gpt-5.3-codex-spark, gpt-5.2
Gemini: gemini-2.5-pro, gemini-2.5-flash, gemini-3.1-pro-preview, gemini-3-pro-preview, gemini-3-flash-preview
Aliases: claude-ultra, codex-ultra, gemini-ultra
Optional adapters may also appear in `ai-cli models`, depending on the installed `ai-cli-mcp` release.
```

Always run `ai-cli models` after install because these aliases can change between releases.

### Validate Workers Without OpenCode

Before connecting anything to OpenCode, verify that `ai-cli` can launch each local CLI agent.

Enter the workspace:

```bash
cd ~/ai-workspaces/my-project-agent
```

Test Claude worker:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model sonnet \
  --prompt "Summarize this repository in 5 bullet points."
```

Test Codex worker:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model gpt-5.5 \
  --prompt "Summarize this repository in 5 bullet points."
```

Test Gemini worker:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model gemini-2.5-pro \
  --prompt "Summarize this repository in 5 bullet points."
```

Optional OpenCode-as-worker test:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model opencode \
  --prompt "Summarize this repository in 5 bullet points."
```

Inspect running jobs:

```bash
ai-cli ps
```

Read a result:

```bash
ai-cli result <PID>
```

Peek at a running process:

```bash
ai-cli peek <PID> --time 10
```

Wait for completion:

```bash
ai-cli wait <PID> --timeout 300
```

Read verbose result:

```bash
ai-cli result <PID> --verbose
```

Kill a stuck job:

```bash
ai-cli kill <PID>
```

Clean completed jobs:

```bash
ai-cli cleanup
```

---

## Connect ai-cli-mcp to OpenCode

The recommended setup is global user-level OpenCode configuration under `$HOME`, not a project-local `opencode.json`.

Use `install.sh` for the normal path:

```bash
./install.sh
```

It creates or updates:

```text
$HOME/.config/opencode/opencode.jsonc
```

There are also two manual patterns: interactive registration through OpenCode CLI, or direct user-level config editing.

### Option A: Add MCP Server Interactively

Run:

```bash
opencode mcp add
```

Choose a local MCP server and provide:

```text
Name: ai-cli-mcp
Command: npx
Args: -y ai-cli-mcp@latest
```

For reproducible team setup, pin the version you validated, for example:

```text
Args: -y ai-cli-mcp@2.21.0
```

Then start OpenCode in the project:

```bash
cd ~/ai-workspaces/my-project-agent
opencode
```

Ask OpenCode:

```text
What MCP tools are available?
```

OpenCode should list tools exposed by `ai-cli-mcp`.

### Option B: Configure Global OpenCode Config

Create or edit the user-level OpenCode config file:

```bash
mkdir -p ~/.config/opencode
touch ~/.config/opencode/opencode.jsonc
```

Minimal example:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.5",
  "small_model": "openai/gpt-5.5",
  "agent": {
    "title": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
    "summary": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
    "compaction": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
  },
  "enabled_providers": ["openai"],
  "mcp": {
    "ai-cli-mcp": {
      "type": "local",
      "command": ["npx", "-y", "ai-cli-mcp@latest"],
      "enabled": true,
    },
  },
}
```

Pinned example:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.5",
  "small_model": "openai/gpt-5.5",
  "agent": {
    "title": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
    "summary": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
    "compaction": {
      "model": "openai/gpt-5.5",
      "variant": "fast",
    },
  },
  "enabled_providers": ["openai"],
  "mcp": {
    "ai-cli-mcp": {
      "type": "local",
      "command": ["npx", "-y", "ai-cli-mcp@2.21.0"],
      "enabled": true,
    },
  },
}
```

> **Compatibility note:** If your OpenCode version expects a different MCP config shape, use `opencode mcp add` and then inspect the generated config.

OpenCode's top-level `small_model` value is a model string. Provider-specific speed or reasoning modes belong in `variant` fields, so `install.sh` applies `variant: fast` to the built-in `title`, `summary`, and `compaction` agents.

Project-local `opencode.json` can still be used for project-specific overrides, but the MCP server itself should usually live in `$HOME/.config/opencode/opencode.jsonc` so every workspace can use the same worker bridge.

---

## Create Agent Profiles

The goal is to route work to the right tool:

```text
Codex/OpenAI in OpenCode → default operator
Codex CLI                  → implementation, tests, bug fixing, security review
Claude                     → mandatory deep refactor, architecture reasoning, complex code changes
Google/Gemini compatibility → mandatory long-context overview, documentation, alternative review
```

OpenCode remains the interface and orchestrator. Run OpenCode on a Codex/OpenAI model by default, then use Codex CLI, Claude, and the Google worker as specialized workers through `ai-cli-mcp`. Today that Google worker is still the Gemini compatibility backend.

---

### Create Common Instructions for All Agents

Create `AGENTS.md` in the repository root:

```bash
cd ~/ai-workspaces/my-project-agent
touch AGENTS.md
```

Recommended `AGENTS.md`:

```md
# Project Agent Instructions

## Mission

This repository is managed through OpenCode with ai-cli-mcp workers:

- Codex as the default operator and implementation worker
- Gemini for long-context analysis, documentation, and alternative review
- Claude as a mandatory worker for deep refactoring and architecture reasoning

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

## Output Format for Reviews

When reviewing code, return:

1. Confirmed issues
2. Potential issues
3. False positives / things that look okay
4. Suggested implementation order
5. Commands that should be run to verify the result

## Output Format for Implementation

When implementing, return:

1. Summary of changes
2. Files changed
3. Tests run
4. Remaining risks
5. Suggested next step

## Codex Worker Profile

Use Codex for:

- concrete implementation tasks
- bug fixing
- test generation
- security review
- code cleanup
- type errors
- failing tests
- small-to-medium scoped changes

Codex should avoid:

- broad architecture rewrites without a plan
- speculative abstractions
- changing public behavior without tests
- touching deployment credentials or production configs

When Codex receives an implementation task:

1. Inspect the relevant files.
2. Identify the minimal change.
3. Edit only the necessary files.
4. Run the most relevant tests.
5. Run formatter/linter/typecheck if available.
6. Report exact commands run.

When Codex receives a review task:

1. Do not edit files.
2. Focus on correctness, security, tests, and maintainability.
3. Rank findings by severity.
4. Include file paths and concrete examples.
5. Avoid vague advice.
```

---

### Create Claude Code Instructions

Claude is best suited for:

```text
- deep refactoring
- complex changes across multiple files
- architecture reasoning
- legacy code explanation
- migration planning
```

Create `CLAUDE.md`:

```bash
touch CLAUDE.md
```

Recommended `CLAUDE.md`:

```md
# Claude Code Instructions

## Role

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

## Refactoring Rules

- Preserve existing behavior unless explicitly asked to change it.
- Do not introduce broad abstractions without clear benefit.
- Prefer incremental refactoring over large rewrites.
- Keep public APIs stable unless the task explicitly asks to change them.
- When refactoring, identify tests that protect the changed behavior.
- If tests are missing, suggest minimal tests before changing risky code.

## Architecture Review Checklist

When asked to review architecture, check:

- module boundaries
- dependency direction
- hidden coupling
- duplicated business logic
- state management
- error handling
- observability
- testability
- deployment/runtime assumptions

## Implementation Discipline

Before editing:

1. Read relevant files.
2. Summarize the current design.
3. Identify the smallest safe change.
4. Ask for confirmation only if the task is ambiguous or destructive.

After editing:

1. Show changed files.
2. Explain why each change was needed.
3. Run or suggest tests.
4. Call out risks honestly.

## Forbidden Actions

- Do not access secrets.
- Do not run production deployment commands.
- Do not modify infrastructure state.
- Do not rewrite large areas of code without an explicit plan.
```

Validate Claude instructions:

```bash
cd ~/ai-workspaces/my-project-agent
claude
```

Inside Claude Code:

```text
Read AGENTS.md, CLAUDE.md, and `.agents/claude-worker.md`. Summarize how you should behave in this repository.
```

---

### Create Claude Worker Prompt

Create a dedicated prompt file:

```bash
mkdir -p .agents
touch .agents/claude-worker.md
```

Recommended `.agents/claude-worker.md`:

```md
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
```

---

### Create Codex Worker Prompt

Create a dedicated prompt file:

```bash
mkdir -p .agents
touch .agents/codex-worker.md
```

Recommended `.agents/codex-worker.md`:

```md
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

For review-only tasks:

- Do not modify files.
- Return findings with severity.
- Include file paths.
- Include suggested fixes.

For implementation tasks:

- Modify only necessary files.
- Preserve behavior unless asked otherwise.
- Add or update tests when appropriate.
- Run relevant verification commands.
```

Smoke test:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model gpt-5.5 \
  --prompt "$(cat .agents/codex-worker.md)

Task:
Review this repository for missing tests. Do not modify files."
```

---

### Create Gemini Worker Prompt

Gemini is best suited for:

```text
- long-context repository overview
- documentation review
- broad codebase analysis
- independent second opinion
- finding inconsistencies between documentation and code
```

Create `GEMINI.md`:

```bash
touch GEMINI.md
```

Recommended `GEMINI.md`:

```md
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
```

Create a prompt file:

```bash
mkdir -p .agents
touch .agents/gemini-worker.md
```

Recommended `.agents/gemini-worker.md`:

```md
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
- Produce concise, structured output.

Use Gemini for:

- system overview
- architecture map
- module boundary review
- documentation gaps
- onboarding guides
- alternative second opinion

Avoid using Gemini for:

- risky production changes
- narrow mechanical edits
- secrets handling
- deployment execution

Output format:

1. High-level summary
2. Important modules
3. Data/control flow
4. Inconsistencies
5. Documentation gaps
6. Suggested follow-up tasks
```

Smoke test:

```bash
ai-cli run \
  --cwd "$PWD" \
  --model gemini-2.5-pro \
  --prompt "$(cat .agents/gemini-worker.md)

Task:
Create a high-level architecture overview of this repository. Do not modify files."
```

---

## Create OpenCode Commands

Create a command directory:

```bash
mkdir -p .opencode/command
```

These commands make it easier to launch workers from OpenCode with consistent instructions.

---

### Codex Security Review

Create `.opencode/command/codex-security.md`:

```bash
cat > .opencode/command/codex-security.md <<'EOF'
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

After Codex finishes:
- Wait for the result.
- Summarize confirmed findings.
- Separate likely false positives.
- Propose a safe implementation order.
EOF
```

---

### Codex Test Review

Create `.opencode/command/codex-tests.md`:

```bash
cat > .opencode/command/codex-tests.md <<'EOF'
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

After Codex finishes:
- Wait for the result.
- Produce a prioritized test implementation plan.
EOF
```

---

### Claude Refactor Review

Claude is a mandatory worker in the default workflow. `init.sh` creates this command by default.

Create `.opencode/command/claude-refactor.md`:

```bash
cat > .opencode/command/claude-refactor.md <<'EOF'
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
- Identify risky rewrites that should be avoided.

After Claude finishes:
- Wait for the result.
- Summarize the top refactoring opportunities.
- Group them into safe incremental steps.
EOF
```

---

### Claude Implementation Plan

Claude is a mandatory worker in the default workflow. `init.sh` creates this command by default.

Create `.opencode/command/claude-plan.md`:

```bash
cat > .opencode/command/claude-plan.md <<'EOF'
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

After Claude finishes:
- Wait for the result.
- Compress the plan into an actionable checklist.
EOF
```

---

### Gemini Architecture Overview

Create `.opencode/command/gemini-architecture.md`:

```bash
cat > .opencode/command/gemini-architecture.md <<'EOF'
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

After Gemini finishes:
- Wait for the result.
- Summarize the architecture in a concise way.
- List documentation gaps and follow-up questions.
EOF
```

---

### Multi-Agent Review

Create `.opencode/command/multi-review.md`:

```bash
cat > .opencode/command/multi-review.md <<'EOF'
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
6. Suggest which agent should handle each follow-up task.
EOF
```

---

## Run Smoke Tests

Start OpenCode:

```bash
cd ~/ai-workspaces/my-project-agent
opencode
```

List MCP tools:

```text
What MCP tools are available?
```

Run Codex from OpenCode:

```text
Use ai-cli-mcp to run Codex on this repository.
Task: summarize the architecture and identify the 5 riskiest files.
Do not modify files.
```

Run Claude from OpenCode:

```text
Use ai-cli-mcp to run Claude Code on this repository.
Task: review the current codebase for maintainability issues.
Do not modify files.
```

Run Gemini from OpenCode:

```text
Use ai-cli-mcp to run Gemini on this repository.
Task: produce a high-level system overview and point out unclear module boundaries.
Do not modify files.
```

Run the multi-agent command:

```text
/multi-review

Use the configured Codex, Claude, and Gemini worker profiles.
Each worker should first state which profile instructions it used.
Do not modify files.
Return a combined action plan.
```

Expected result:

```text
- Codex provides security/correctness findings
- Claude provides refactor/architecture findings
- Gemini provides architecture/docs findings
- OpenCode deduplicates and prioritizes all results
```

---

## Recommended Workflow

Use this flow for serious work:

```text
1. Google/Gemini compatibility → broad overview
2. Claude → deep plan
3. Codex → concrete implementation/test suggestions
4. OpenCode → final aggregation
5. Human → approve scope
6. OpenCode or Codex → implement
7. Codex → test/lint verification
8. Claude → final refactor sanity check
```

Example OpenCode prompt:

```text
Use the multi-agent workflow.

Goal:
Refactor the authentication module to make session handling easier to test.

Steps:
1. Ask Gemini for a broad overview of the auth/session flow.
2. Ask Claude for a safe refactoring plan.
3. Ask Codex for concrete test cases.
4. Compare the outputs.
5. Do not modify files yet.
6. Return a final plan with risks and test commands.
```

### Routing Matrix

| Task                  | Best Worker                          | Reason                                                   |
| --------------------- | ------------------------------------ | -------------------------------------------------------- |
| Implement small fix   | Codex                                | Fast, concrete, good for scoped edits                    |
| Fix failing test      | Codex                                | Can iterate with test output                             |
| Add missing tests     | Codex                                | Strong at test-focused implementation                    |
| Security review       | Codex + Claude                       | Codex finds concrete issues, Claude reasons about design |
| Deep refactor         | Claude                               | Better for multi-file reasoning and trade-offs           |
| Migration plan        | Claude                               | Better for step-by-step architecture planning            |
| Architecture overview | Google/Gemini compatibility          | Good for broad long-context analysis                     |
| Documentation gaps    | Google/Gemini compatibility          | Good at comparing docs and code                          |
| Second opinion        | Google/Gemini compatibility or Codex | Useful disagreement signal                               |
| Final implementation  | OpenCode or Codex                    | Keep one agent responsible for final edits               |

---

## Security Rules

This stack intentionally gives agents the ability to run other local coding agents. Treat it as a privileged automation setup.

`ai-cli-mcp` starts worker CLIs in automation-friendly modes. Current package behavior includes:

```text
Claude Code: uses --dangerously-skip-permissions
Codex CLI: uses --dangerously-bypass-approvals-and-sandbox
Gemini CLI: uses automatic approval mode
OpenCode CLI: uses non-interactive run mode
```

Therefore, rely on external containment before relying on individual agent prompts:

```text
safe copy of the repository
Git worktree without secrets
devcontainer
ephemeral VM
separate local user account
least-privilege cloud credentials
```

Do not run this setup in:

```text
~
~/.ssh
~/.kube
~/Library
/etc
production repository with real .env files
directories containing cloud credentials
```

Preferred execution locations:

```text
~/ai-workspaces/<project>
devcontainer
separate user account
ephemeral VM
git worktree without secrets
```

Recommended ignore patterns:

```text
.env
.env.*
.npmrc
.pypirc
.netrc
*.pem
*.key
id_rsa
id_ed25519
kubeconfig
config
secrets.yaml
values-prod.yaml
```

For Kubernetes or home lab repositories:

```text
- Do not expose a real kubeconfig to AI agents by default.
- Do not allow agents to run kubectl against production contexts.
- Use read-only or fake configs for analysis.
- Keep production Helm values and secrets outside the agent workspace.
```

---

## Troubleshooting

### OpenCode Does Not See MCP Tools

Check MCP configuration:

```bash
opencode mcp
opencode mcp list
```

Re-add the MCP server:

```bash
opencode mcp add
```

Check whether the MCP server starts manually:

```bash
npx -y ai-cli-mcp@latest
```

This command should print setup lines and `AI CLI MCP server running on stdio`, then wait for MCP input.

---

### ai-cli Does Not See Codex / Claude / Gemini Compatibility

Check PATH:

```bash
which codex
which claude
which agy
which gemini
```

Check versions:

```bash
codex --version
claude --version
agy --version
gemini --version
```

Run diagnostics:

```bash
ai-cli doctor
```

---

### Codex Is Not Authenticated

Run:

```bash
codex login
```

Then test:

```bash
codex "Say hello"
```

---

### Claude Is Not Authenticated

Run:

```bash
claude
```

Then initialize non-interactive mode inside a safe workspace:

```bash
cd ~/ai-workspaces/my-project-agent
claude --dangerously-skip-permissions
```

---

### Antigravity / Gemini Compatibility Is Not Authenticated

Run:

```bash
agy
gemini
```

Choose Google login and complete authentication. `agy` is the forward-looking Google CLI; `gemini` is currently still needed by `ai-cli-mcp` for the Google worker backend.

---

### Worker Job Is Stuck

List jobs:

```bash
ai-cli ps
```

Peek at output:

```bash
ai-cli peek <PID> --time 10
```

Kill the job:

```bash
ai-cli kill <PID>
```

Clean completed jobs:

```bash
ai-cli cleanup
```

---

### Unknown or Wrong Model Names

List available aliases and models:

```bash
ai-cli models
opencode models
opencode models openai
opencode models anthropic
```

---

## Final Readiness Checklist

The setup is ready when all of these pass:

```bash
opencode --version
codex --version
claude --version
agy --version
gemini --version
ai-cli doctor
```

`ai-cli doctor` checks binary availability and path resolution. It does not prove that every CLI is authenticated or that first-run terms were accepted.

Verify authentication separately:

```bash
codex doctor
claude auth status
agy
gemini -p "Say hello."
```

And these smoke tests work:

```bash
cd ~/ai-workspaces/my-project-agent

opencode run "Summarize this repository."

ai-cli run --cwd "$PWD" --model sonnet --prompt "Summarize this repository."
ai-cli run --cwd "$PWD" --model gpt-5.5 --prompt "Summarize this repository."
ai-cli run --cwd "$PWD" --model gemini-2.5-pro --prompt "Summarize this repository."
```

Final OpenCode test:

```text
Use ai-cli-mcp to run Codex, Claude, and Gemini in parallel.
Ask each to summarize this repository.
Wait for all results and compare their answers.
```

Until `ai-cli-mcp` exposes an Antigravity/`agy` backend, the Google worker in the final OpenCode test still uses the Gemini compatibility backend.

---

## Recommended Repository Structure

This orchestration repository should contain:

```text
opencode-agent-orchestration/
  install.sh
  init.sh
  README.md
```

After running `init.sh`, the target project workspace should look like this:

```text
my-project-agent/
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  .agents/
    codex-worker.md
    claude-worker.md
    gemini-worker.md
  .opencode/
    command/
      codex-security.md
      codex-tests.md
      claude-refactor.md
      claude-plan.md
      gemini-architecture.md
      multi-review.md
  docs/
    architecture.md
    local-dev.md
    deployment.md
  src/
  tests/
```

The OpenCode MCP server config should live outside the project:

```text
~/.config/opencode/opencode.jsonc
```

---

## Practical Summary

After this setup:

```text
- You work in OpenCode.
- OpenCode can edit the project directly.
- OpenCode can call ai-cli-mcp as an MCP server.
- ai-cli-mcp can run Codex, Claude, and the Gemini compatibility backend as local CLI workers.
- Antigravity CLI is installed as the forward-looking Google CLI.
- Worker outputs return to OpenCode.
- OpenCode aggregates results and performs the final implementation when requested.
```

The key limitation remains:

```text
This is not a single shared context across all agents.
Each worker receives a task-specific prompt and working directory, then returns a result.
```

Therefore, make worker prompts explicit and ask OpenCode to aggregate, compare, and deduplicate results.

---

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Upstream References

Use these as the source of truth when refreshing this guide:

```text
OpenCode docs: https://dev.opencode.ai/docs/
Codex manual: https://developers.openai.com/codex/codex-manual.md
Codex GitHub README: https://github.com/openai/codex
Claude Code install docs: https://code.claude.com/docs/en/installation
Claude Code CLI docs: https://code.claude.com/docs/en/cli-usage
Google Gemini CLI to Antigravity CLI announcement: https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
Antigravity CLI install docs: https://antigravity.google/docs/cli-install
Antigravity CLI migration docs: https://antigravity.google/docs/gcli-migration
Gemini CLI docs: https://google-gemini.github.io/gemini-cli/
ai-cli-mcp package docs: https://www.npmjs.com/package/ai-cli-mcp
```
