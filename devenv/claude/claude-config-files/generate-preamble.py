#!/usr/bin/env python3
import json, re, os

role = os.environ.get('HOOK_ROLE', '')
directives_path = os.path.expanduser('~/.claude/LLM/LLM-directives.txt')

SKIP = {'if','when','while','prefer','as','for','in','to','the','a','an','of','with','by','since'}

def short_label(text):
    """Derive a short area label from an unlabeled directive's first line."""
    words = text.split()
    word = next((w for w in words if w.lower() not in SKIP), words[0] if words else 'General')
    return word.capitalize().rstrip('.,;:')

def join_block(lines):
    """Join all lines of a directive block, stripping leading bullet chars."""
    parts = []
    for l in lines:
        l = l.strip().lstrip('-').strip()
        if l:
            parts.append(l)
    return ' '.join(parts)

rows = []

if role and os.path.exists(directives_path):
    text = open(directives_path).read()

    m = re.search(rf'## ROLE: {re.escape(role)}\n(.*?)(?=\n## ROLE:|\Z)', text, re.DOTALL)
    if m:
        section = m.group(1)

        # DESCRIPTION → Identity row
        desc_m = re.search(r'DESCRIPTION:\s*(.+?)(?=\n\n)', section, re.DOTALL)
        if desc_m:
            desc = ' '.join(desc_m.group(1).split())
            rows.append(('Identity', desc[:120] + ('…' if len(desc) > 120 else '')))

        # NEAR TERM DIRECTIVES
        near_m = re.search(r'NEAR TERM DIRECTIVES:(.*?)(?=DIRECTIVES:)', section, re.DOTALL)
        if near_m:
            for b in re.findall(r'\*\s+(.+?)(?=\n\*|\Z)', near_m.group(1), re.DOTALL):
                b = ' '.join(b.split())
                rows.append(('Near-term', b[:120] + ('…' if len(b) > 120 else '')))

        # DIRECTIVES — split on * bullets (handles *Label and * Label and *Label\n)
        dir_m = re.search(r'^DIRECTIVES:(.*)', section, re.DOTALL | re.MULTILINE)
        if dir_m:
            for b in re.split(r'\n\*\s*', dir_m.group(1)):
                b = b.strip()
                if not b:
                    continue
                lines = b.split('\n')
                first = lines[0].strip().rstrip(':').strip()

                if len(first) < 20 and not first.endswith('.') and len(lines) > 1:
                    # Labeled section: area = first line, body = joined sub-items
                    area = first
                    body = join_block(lines[1:])
                else:
                    # Unlabeled: derive area from first meaningful word
                    area = short_label(first)
                    body = join_block(lines)

                body = body[:140] + ('…' if len(body) > 140 else '')
                if area and body:
                    rows.append((area, body))

def pipe(s):
    return s.replace('|', '\\|')

if rows:
    table = [
        f"Active role: {role}", "",
        "| Area | Directive |",
        "|------|-----------|",
    ] + [f"| {pipe(a)} | {pipe(d)} |" for a, d in rows]
    preamble = '\n'.join(table)

    additional = (
        "MANDATORY SESSION PREAMBLE\n"
        "Your first response MUST begin with the following block copied verbatim "
        "(do not paraphrase or reorder rows). Output it before addressing anything else:\n\n"
        "---\n" + preamble + "\n---"
    )
else:
    additional = f"Session started. Active role: {role or '(none detected)'}"

print(json.dumps({'additionalContext': additional}))
