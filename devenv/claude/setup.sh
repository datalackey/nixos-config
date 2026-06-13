#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── prereq ────────────────────────────────────────────────────────────────────
if [ ! -e "$HOME/config" ]; then
  echo "❌ ~/config not found — run post-install-setup.sh first (Dropbox must be synced)."
  exit 1
fi

# ── backup existing targets (preserves full path under /tmp) ─────────────────
BACKUP_DIR="/tmp/claude-setup-backup-$(date +%Y%m%d-%H%M%S)"
BACKED_UP=0

save() {
  local p="$1"
  if [ -e "$p" ] || [ -L "$p" ]; then
    local rel="${p#"$HOME"/}"
    local bdst="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$bdst")"
    cp -aP "$p" "$bdst"
    BACKED_UP=1
  fi
}

save "$HOME/config/LLM"
save "$HOME/.claude/CLAUDE.md"
save "$HOME/.claude/LLM"
save "$HOME/.claude/settings.json"
save "$HOME/.claude/session-start.sh"
save "$HOME/.claude/generate-preamble.py"
save "$HOME/.claude/projects/-home-chris-build-tools/memory"

[ "$BACKED_UP" -eq 1 ] && echo "📦 Backup saved to: $BACKUP_DIR"

# ── re-point ~/config/LLM → git-versioned config files ───────────────────────
rm -f "$HOME/config/LLM"
ln -s "$SCRIPT_DIR/claude-config-files" "$HOME/config/LLM"
echo "✅ ~/config/LLM → $SCRIPT_DIR/claude-config-files"

# ── ~/.npmrc: add prefix if missing (never touch existing auth tokens) ────────
if ! grep -q "^prefix=" "$HOME/.npmrc" 2>/dev/null; then
  echo "prefix=$HOME/.npm-global" >> "$HOME/.npmrc"
  echo "✅ Added prefix to ~/.npmrc"
else
  echo "⏭️  ~/.npmrc prefix already set"
fi

# ── ensure ~/.npm-global/bin is in PATH ──────────────────────────────────────
if ! grep -q "npm-global/bin" "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
  echo "✅ Added ~/.npm-global/bin to PATH in ~/.bashrc"
else
  echo "⏭️  PATH already includes ~/.npm-global/bin"
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# ── install Claude Code ───────────────────────────────────────────────────────
if [ -d "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code" ]; then
  echo "⏭️  Claude Code already installed"
else
  echo "📦 Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
  echo "✅ Claude Code installed"
fi

# ── ~/.claude/ symlinks ───────────────────────────────────────────────────────
mkdir -p "$HOME/.claude"

lnk() {
  local src="$1" dst="$HOME/.claude/$2"
  rm -f "$dst"
  ln -s "$src" "$dst"
  echo "✅ ~/.claude/$2 → $src"
}

lnk "$HOME/config/LLM/CLAUDE.md"            CLAUDE.md
lnk "$HOME/config/LLM"                      LLM
lnk "$HOME/config/LLM/settings.json"        settings.json
lnk "$HOME/config/LLM/session-start.sh"     session-start.sh
lnk "$HOME/config/LLM/generate-preamble.py" generate-preamble.py

# ── memory dir → Dropbox ──────────────────────────────────────────────────────
MEMORY_SRC="$HOME/.claude/projects/-home-chris-build-tools/memory"
MEMORY_DST="$HOME/Dropbox/projects/devEnv/config/LLM/claude-memory"

mkdir -p "$MEMORY_DST"
mkdir -p "$(dirname "$MEMORY_SRC")"

if [ -d "$MEMORY_SRC" ] && [ ! -L "$MEMORY_SRC" ]; then
  echo "📦 Migrating memory files to Dropbox..."
  cp -a "$MEMORY_SRC/." "$MEMORY_DST/"
  mv "$MEMORY_SRC" "$BACKUP_DIR/memory-pre-migrate"
  ln -s "$MEMORY_DST" "$MEMORY_SRC"
  echo "✅ memory/ migrated → $MEMORY_DST"
elif [ -L "$MEMORY_SRC" ]; then
  echo "⏭️  memory/ already a symlink"
else
  ln -s "$MEMORY_DST" "$MEMORY_SRC"
  echo "✅ memory/ → $MEMORY_DST"
fi

# shellcheck disable=SC1090
source "$HOME/.bashrc" 2>/dev/null || true

echo ""
echo "🎯 Claude setup complete."
echo "⚠️  Run 'source ~/.bashrc' or open a new terminal before using the claude command."
