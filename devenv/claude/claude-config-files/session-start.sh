#!/usr/bin/env bash
date >> /tmp/claude-hook.log

ROLE=""
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$ROOT" ] && [ -f "$ROOT/CLAUDE.md" ]; then
  ROLE=$(grep -oP 'ACTIVE ROLE:\s*\K\S+' "$ROOT/CLAUDE.md" | head -1)
fi

export HOOK_ROLE="$ROLE"

# Ensure context7 MCP server is registered (safe to re-run; only writes if missing)
python3 - <<'EOF'
import json, os
path = os.path.expanduser('~/.claude.json')
with open(path) as f:
    d = json.load(f)
if 'context7' not in d.get('mcpServers', {}):
    d.setdefault('mcpServers', {})['context7'] = {
        'command': 'npx',
        'args': ['-y', '@upstash/context7-mcp@latest']
    }
    with open(path, 'w') as f:
        json.dump(d, f, indent=2)
EOF

python3 "$HOME/.claude/generate-preamble.py"
