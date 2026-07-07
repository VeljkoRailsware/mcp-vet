#!/usr/bin/env bash
# mcp-vet installer — wires the skill into Claude Code and, optionally, other agents.
# Run from inside a cloned mcp-vet repo:  ./install.sh [--cursor DIR] [--vscode DIR] [--codex [DIR]] [--codex-global]
# With no flags it installs the Claude Code skill and prints how to add the rest.

set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\033[1;32m•\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }

# --- Claude Code skill (always) ---------------------------------------------
DEST="$HOME/.claude/skills/mcp-vet"
mkdir -p "$DEST"
cp -R "$REPO/SKILL.md" "$REPO/references" "$REPO/scripts" "$DEST/"
chmod +x "$DEST/scripts/run_scanners.sh"
say "Claude Code skill installed → $DEST"

# --- Scanner CLI shim on PATH (always) --------------------------------------
# Makes the scanner layer available to Cursor / VS Code / Codex as `mcp-vet-scan`,
# so those adapters work even when this repo isn't in the workspace.
BIN_DIR="${MCP_VET_BIN:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
cp "$REPO/scripts/run_scanners.sh" "$BIN_DIR/mcp-vet-scan"
chmod +x "$BIN_DIR/mcp-vet-scan"
say "Scanner CLI installed → $BIN_DIR/mcp-vet-scan"
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) warn "$BIN_DIR is not on your PATH — add it:  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc" ;;
esac

# --- Optional adapters -------------------------------------------------------
CURSOR_DIR=""; VSCODE_DIR=""; CODEX_DIR=""; CODEX_GLOBAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cursor)       CURSOR_DIR="${2:-.}"; shift 2;;
    --vscode)       VSCODE_DIR="${2:-.}"; shift 2;;
    --codex)        CODEX_DIR="${2:-.}"; shift 2;;
    --codex-global) CODEX_GLOBAL=1; shift;;
    *) warn "unknown flag: $1"; shift;;
  esac
done

if [[ -n "$CURSOR_DIR" ]]; then
  mkdir -p "$CURSOR_DIR/.cursor/rules"
  cp "$REPO/adapters/cursor/mcp-vet.mdc" "$CURSOR_DIR/.cursor/rules/"
  say "Cursor rule installed → $CURSOR_DIR/.cursor/rules/mcp-vet.mdc"
fi
if [[ -n "$VSCODE_DIR" ]]; then
  mkdir -p "$VSCODE_DIR/.github/prompts"
  cp "$REPO/adapters/vscode/mcp-vet.prompt.md" "$VSCODE_DIR/.github/prompts/"
  say "VS Code prompt installed → $VSCODE_DIR/.github/prompts/mcp-vet.prompt.md  (invoke: /mcp-vet)"
fi
if [[ -n "$CODEX_DIR" ]]; then
  cat "$REPO/adapters/codex/mcp-vet.AGENTS.md" >> "$CODEX_DIR/AGENTS.md"
  say "Codex section appended → $CODEX_DIR/AGENTS.md"
fi
if [[ -n "$CODEX_GLOBAL" ]]; then
  mkdir -p "$HOME/.codex"
  cat "$REPO/adapters/codex/mcp-vet.AGENTS.md" >> "$HOME/.codex/AGENTS.md"
  say "Codex section appended → ~/.codex/AGENTS.md (global)"
fi

if [[ -z "$CURSOR_DIR$VSCODE_DIR$CODEX_DIR$CODEX_GLOBAL" ]]; then
  cat <<'EOF'

Also available (re-run with a target directory):
  ./install.sh --cursor  <project>   # → .cursor/rules/mcp-vet.mdc
  ./install.sh --vscode  <project>   # → .github/prompts/mcp-vet.prompt.md   (invoke: /mcp-vet)
  ./install.sh --codex   <project>   # → append to <project>/AGENTS.md
  ./install.sh --codex-global        # → append to ~/.codex/AGENTS.md

Optional scanners (sharper verdicts; the skill degrades gracefully without them):
  pipx install mcp-scan semgrep trufflehog3 guarddog   #  + brew install osv-scanner
EOF
fi
say "Done."
