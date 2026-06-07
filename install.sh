#!/usr/bin/env bash
set -euo pipefail

AI_CLI_MCP_PACKAGE="${AI_CLI_MCP_PACKAGE:-ai-cli-mcp@latest}"
NPM_GLOBAL_PREFIX="${NPM_GLOBAL_PREFIX:-$HOME/.local}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_FILE:-$OPENCODE_CONFIG_DIR/opencode.jsonc}"
OPENCODE_MODEL="${OPENCODE_MODEL:-openai/gpt-5.5}"
OPENCODE_SMALL_MODEL="${OPENCODE_SMALL_MODEL:-openai/gpt-5.5}"
OPENCODE_SMALL_MODEL_VARIANT="${OPENCODE_SMALL_MODEL_VARIANT:-fast}"
OPENCODE_ENABLED_PROVIDERS="${OPENCODE_ENABLED_PROVIDERS:-openai}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run]

Options:
  --dry-run, -n   Show planned installation/configuration actions without changing files
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
      *)
        printf '[install] unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install] warning: %s\n' "$*" >&2
}

dry_log() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[install] dry-run: %s\n' "$*"
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

append_path_hint() {
  case ":$PATH:" in
    *":$NPM_GLOBAL_PREFIX/bin:"*) ;;
    *) export PATH="$NPM_GLOBAL_PREFIX/bin:$PATH" ;;
  esac
}

ensure_home_npm_prefix() {
  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would ensure npm global prefix at $NPM_GLOBAL_PREFIX"
    dry_log "would export NPM_CONFIG_PREFIX=$NPM_GLOBAL_PREFIX for this run"
    return
  fi

  mkdir -p "$NPM_GLOBAL_PREFIX/bin"
  export NPM_CONFIG_PREFIX="$NPM_GLOBAL_PREFIX"
  append_path_hint

  if has_cmd npm; then
    local current_prefix
    current_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [ "$current_prefix" != "$NPM_GLOBAL_PREFIX" ]; then
      log "setting npm global prefix to $NPM_GLOBAL_PREFIX"
      npm config set prefix "$NPM_GLOBAL_PREFIX" >/dev/null
    fi
  fi
}

ensure_home_path_in_shell_rc() {
  local shell_name rc_file path_line
  shell_name="$(basename "${SHELL:-}")"
  path_line="export PATH=\"$NPM_GLOBAL_PREFIX/bin:\$PATH\""

  case "$shell_name" in
    zsh) rc_file="$HOME/.zshrc" ;;
    bash) rc_file="$HOME/.bashrc" ;;
    *) rc_file="$HOME/.profile" ;;
  esac

  if [ ! -f "$rc_file" ] || ! grep -Fq "$path_line" "$rc_file"; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would add $NPM_GLOBAL_PREFIX/bin to $rc_file"
      return
    fi
    log "adding $NPM_GLOBAL_PREFIX/bin to $rc_file"
    {
      printf '\n# AI CLI worker tools\n'
      printf '%s\n' "$path_line"
    } >> "$rc_file"
  fi
}

install_node_if_missing() {
  if has_cmd node && has_cmd npm && has_cmd npx; then
    local node_major
    node_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || printf 0)"
    if [ "$node_major" -ge 20 ]; then
      return
    fi
    warn "Node.js 20+ is required for this setup; found $(node --version 2>/dev/null || printf unknown)"
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install/upgrade Node.js with Homebrew"
      return
    fi
    log "installing/upgrading Node.js with Homebrew"
    brew install node || brew upgrade node
    return
  fi

  if has_cmd apt-get; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Node.js with apt-get"
      return
    fi
    log "installing Node.js with apt-get"
    sudo apt-get update
    sudo apt-get install -y nodejs npm git
    local node_major
    node_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || printf 0)"
    if [ "$node_major" -lt 20 ]; then
      warn "apt-get installed Node.js $(node --version 2>/dev/null || printf unknown), but this setup requires Node.js 20+"
      warn "install Node.js 20+ with your distro's recommended method and rerun install.sh"
      return 1
    fi
    return
  fi

  warn "Node.js/npm/npx missing and no supported package manager was found"
  return 1
}

install_opencode_if_missing() {
  if has_cmd opencode; then
    log "OpenCode already installed: $(opencode --version 2>/dev/null || printf unknown)"
    return
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install OpenCode with Homebrew"
      return
    fi
    log "installing OpenCode with Homebrew"
    brew install anomalyco/tap/opencode
    return
  fi

  if has_cmd curl; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install OpenCode with curl installer"
      return
    fi
    log "installing OpenCode with curl installer"
    curl -fsSL https://opencode.ai/install | bash
    return
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would install OpenCode with npm fallback"
    return
  fi
  log "installing OpenCode with npm fallback"
  npm install -g opencode-ai
}

install_codex_if_missing() {
  if has_cmd codex; then
    log "Codex already installed: $(codex --version 2>/dev/null || printf unknown)"
    return
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Codex CLI with Homebrew"
      return
    fi
    log "installing Codex CLI with Homebrew"
    brew install --cask codex
    return
  fi

  if has_cmd curl; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Codex CLI with curl installer"
      return
    fi
    log "installing Codex CLI with curl installer"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    return
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would install Codex CLI with npm fallback"
    return
  fi
  log "installing Codex CLI with npm fallback"
  npm install -g @openai/codex
}

install_claude_if_missing() {
  if has_cmd claude; then
    log "Claude Code already installed: $(claude --version 2>/dev/null || printf unknown)"
    return
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Claude Code with Homebrew"
      return
    fi
    log "installing Claude Code with Homebrew"
    brew install --cask claude-code
    return
  fi

  if has_cmd curl; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Claude Code with curl installer"
      return
    fi
    log "installing Claude Code with curl installer"
    curl -fsSL https://claude.ai/install.sh | bash
    return
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would install Claude Code with npm fallback"
    return
  fi
  log "installing Claude Code with npm fallback"
  npm install -g @anthropic-ai/claude-code
}

install_gemini_if_missing() {
  if has_cmd gemini; then
    log "Gemini CLI already installed: $(gemini --version 2>/dev/null || printf unknown)"
    return
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Gemini CLI compatibility backend with Homebrew"
      return
    fi
    log "installing Gemini CLI with Homebrew"
    brew install gemini-cli
    return
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would install Gemini CLI compatibility backend with npm fallback"
    return
  fi
  log "installing Gemini CLI with npm fallback"
  npm install -g @google/gemini-cli@latest
}

install_antigravity_if_missing() {
  if has_cmd agy; then
    log "Antigravity CLI already installed: $(agy --version 2>/dev/null || printf unknown)"
    return
  fi

  if has_cmd brew; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Antigravity CLI with Homebrew"
      return
    fi
    log "installing Antigravity CLI with Homebrew"
    brew install --cask antigravity-cli
    return
  fi

  if has_cmd curl; then
    if [ "$DRY_RUN" = "1" ]; then
      dry_log "would install Antigravity CLI with curl installer"
      return
    fi
    log "installing Antigravity CLI with curl installer"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    return
  fi

  warn "Antigravity CLI missing and neither Homebrew nor curl was found"
  return 1
}

install_ai_cli_mcp_if_missing() {
  if has_cmd ai-cli; then
    log "ai-cli already installed"
    return
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_log "would install ai-cli-mcp into npm prefix $NPM_GLOBAL_PREFIX"
    return
  fi
  log "installing ai-cli-mcp into npm prefix $NPM_GLOBAL_PREFIX"
  npm install -g "$AI_CLI_MCP_PACKAGE"
}

configure_opencode_mcp() {
  if [ "$DRY_RUN" = "1" ]; then
    if [ -f "$OPENCODE_CONFIG_FILE" ]; then
      dry_log "would update OpenCode config at $OPENCODE_CONFIG_FILE"
    else
      dry_log "would create OpenCode config at $OPENCODE_CONFIG_FILE"
    fi
    dry_log "would set model=$OPENCODE_MODEL"
    dry_log "would set small_model=$OPENCODE_SMALL_MODEL with title/summary/compaction variant=$OPENCODE_SMALL_MODEL_VARIANT"
    dry_log "would configure MCP server ai-cli-mcp using npx -y $AI_CLI_MCP_PACKAGE"
    dry_log "would remove legacy OPENAI_API_KEY provider block if present"
    return
  fi

  mkdir -p "$OPENCODE_CONFIG_DIR"

  if [ ! -f "$OPENCODE_CONFIG_FILE" ]; then
    log "creating OpenCode MCP config at $OPENCODE_CONFIG_FILE"
    node - "$OPENCODE_CONFIG_FILE" "$AI_CLI_MCP_PACKAGE" <<'NODE'
const fs = require("fs");

const file = process.argv[2];
const pkg = process.argv[3];
const model = process.env.OPENCODE_MODEL || "openai/gpt-5.5";
const smallModel = process.env.OPENCODE_SMALL_MODEL || "openai/gpt-5.5";
const smallVariant = process.env.OPENCODE_SMALL_MODEL_VARIANT || "fast";
const enabledProviders = (process.env.OPENCODE_ENABLED_PROVIDERS || "openai")
  .split(",")
  .map((item) => item.trim())
  .filter(Boolean);

const config = {
  $schema: "https://opencode.ai/config.json",
  model,
  small_model: smallModel,
  agent: {
    title: {
      model: smallModel,
      variant: smallVariant,
    },
    summary: {
      model: smallModel,
      variant: smallVariant,
    },
    compaction: {
      model: smallModel,
      variant: smallVariant,
    },
  },
  enabled_providers: enabledProviders,
  mcp: {
    "ai-cli-mcp": {
      type: "local",
      command: ["npx", "-y", pkg],
      enabled: true,
    },
  },
};

fs.writeFileSync(file, `${JSON.stringify(config, null, 2)}\n`);
NODE
    return
  fi

  log "updating existing OpenCode config"
  if ! cp "$OPENCODE_CONFIG_FILE" "$OPENCODE_CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"; then
    warn "could not create OpenCode config backup; continuing without backup"
  fi
  node - "$OPENCODE_CONFIG_FILE" "$AI_CLI_MCP_PACKAGE" <<'NODE'
const fs = require("fs");

const file = process.argv[2];
const pkg = process.argv[3];
const raw = fs.readFileSync(file, "utf8");
const withoutComments = raw
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/(^|[^:])\/\/.*$/gm, "$1");

let config;
try {
  config = JSON.parse(withoutComments.trim() || "{}");
} catch (error) {
  console.error(`Cannot parse ${file} as JSON/JSONC: ${error.message}`);
  process.exit(1);
}

const smallModel = process.env.OPENCODE_SMALL_MODEL || "openai/gpt-5.5";
const smallVariant = process.env.OPENCODE_SMALL_MODEL_VARIANT || "fast";

config.$schema = config.$schema || "https://opencode.ai/config.json";
config.model = process.env.OPENCODE_MODEL || config.model || "openai/gpt-5.5";
config.small_model = smallModel;
if (process.env.OPENCODE_ENABLED_PROVIDERS || !config.enabled_providers) {
  config.enabled_providers = (process.env.OPENCODE_ENABLED_PROVIDERS || "openai").split(",").map((item) => item.trim()).filter(Boolean);
}
if (config.provider?.openai?.options?.apiKey === "{env:OPENAI_API_KEY}") {
  delete config.provider.openai.options.apiKey;
  if (Object.keys(config.provider.openai.options).length === 0) {
    delete config.provider.openai.options;
  }
  if (Object.keys(config.provider.openai).length === 0) {
    delete config.provider.openai;
  }
  if (Object.keys(config.provider).length === 0) {
    delete config.provider;
  }
}
config.agent = config.agent || {};
for (const agentName of ["title", "summary", "compaction"]) {
  config.agent[agentName] = {
    ...(config.agent[agentName] || {}),
    model: smallModel,
    variant: smallVariant,
  };
}
config.mcp = config.mcp || {};
config.mcp["ai-cli-mcp"] = {
  type: "local",
  command: ["npx", "-y", pkg],
  enabled: true,
};

fs.writeFileSync(file, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

print_versions() {
  log "tool summary"
  printf '  node:        %s\n' "$(node --version 2>/dev/null || printf 'missing')"
  printf '  npm:         %s\n' "$(npm --version 2>/dev/null || printf 'missing')"
  printf '  npx:         %s\n' "$(npx --version 2>/dev/null || printf 'missing')"
  printf '  opencode:    %s\n' "$(opencode --version 2>/dev/null || printf 'missing')"
  printf '  codex:       %s\n' "$(codex --version 2>/dev/null || printf 'missing')"
  printf '  claude:      %s\n' "$(claude --version 2>/dev/null || printf 'missing')"
  printf '  agy:         %s\n' "$(agy --version 2>/dev/null || printf 'missing')"
  printf '  gemini:      %s\n' "$(gemini --version 2>/dev/null || printf 'missing')"
  if has_cmd ai-cli; then
    printf '  ai-cli:      installed at %s\n' "$(command -v ai-cli)"
  else
    printf '  ai-cli:      missing\n'
  fi

  log "ai-cli-mcp doctor summary"
  local doctor_json
  doctor_json="$(ai-cli doctor 2>/dev/null || true)"
  if [ -z "$doctor_json" ]; then
    warn "ai-cli doctor did not return diagnostic output"
    return
  fi

  node - "$doctor_json" <<'NODE' || printf '%s\n' "$doctor_json"
const doctor = JSON.parse(process.argv[2]);
const checks = doctor.checks || {};
const names = ["codex", "claude", "gemini", "opencode"];

for (const name of names) {
  const item = doctor[name] || {};
  const status = item.available ? "ok" : "missing";
  const path = item.resolvedPath || "not found";
  console.log(`  ${name.padEnd(10)} ${status.padEnd(7)} ${path}`);
}

if (doctor.forge && !doctor.forge.available) {
  console.log("  forge      optional  not installed");
}

console.log(`  loginState          ${checks.loginState === true ? "ok" : "not confirmed by doctor"}`);
console.log(`  termsAcceptance     ${checks.termsAcceptance === true ? "ok" : "not confirmed by doctor"}`);
console.log("  antigravity/agy     installed separately; ai-cli-mcp currently uses Gemini compatibility backend");
NODE

  if [ "${VERBOSE_DOCTOR:-0}" = "1" ]; then
    log "raw ai-cli doctor output"
    printf '%s\n' "$doctor_json"
  fi
}

main() {
  parse_args "$@"

  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run mode: no files will be written and no packages will be installed"
  fi

  install_node_if_missing
  ensure_home_npm_prefix
  ensure_home_path_in_shell_rc

  install_opencode_if_missing
  install_codex_if_missing
  install_claude_if_missing
  install_antigravity_if_missing
  install_gemini_if_missing
  install_ai_cli_mcp_if_missing
  configure_opencode_mcp

  print_versions

  log "done"
  log "OpenCode config: $OPENCODE_CONFIG_FILE"
  log "OpenCode should use Codex/OpenAI through ChatGPT/OpenAI provider login, not OPENAI_API_KEY."
  log "If worker auth is missing, run: codex login, claude auth login, agy, and gemini while ai-cli-mcp still uses Gemini compatibility."
  log "For raw ai-cli diagnostics, rerun with VERBOSE_DOCTOR=1."
}

main "$@"
