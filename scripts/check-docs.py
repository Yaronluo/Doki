#!/usr/bin/env python3
"""Read-only checks for this repository's Markdown handoff package."""

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = [ROOT / "README.md", ROOT / "AGENTS.md"] + sorted(
    (ROOT / "docs").rglob("*.md")
)
ERRORS = []


def fail(path, line, message):
    ERRORS.append(f"{path.relative_to(ROOT)}:{line}: {message}")


for path in DOCUMENTS:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    fence = None
    fence_line = 0
    fence_language = ""
    body = []
    prose = []
    table_width = None
    definitions = set()
    references = set()

    for number, line in enumerate(lines, 1):
        if line.rstrip() != line:
            fail(path, number, "trailing whitespace")
        marker = re.match(r"^\s*(`{3,}|~{3,})(.*)$", line)
        if marker:
            delimiter, language = marker.groups()
            if fence is None:
                fence = delimiter
                fence_line = number
                fence_language = language.strip()
                body = []
            elif delimiter[0] == fence[0] and len(delimiter) >= len(fence) and not language.strip():
                if fence_language == "json":
                    try:
                        json.loads("\n".join(body))
                    except json.JSONDecodeError as error:
                        fail(path, fence_line, f"invalid JSON example: {error}")
                fence = None
            table_width = None
            continue
        if fence is not None:
            body.append(line)
            continue
        prose.append((number, line))
        if line.startswith("|"):
            width = len(re.findall(r"(?<!\\)\|", line))
            if table_width is not None and width != table_width:
                fail(path, number, "inconsistent Markdown table columns")
            table_width = width
        else:
            table_width = None
        definition = re.match(r"^\[([^\]]+)\]:\s*(\S+)", line)
        if definition:
            definitions.add(definition.group(1))
        references.update(re.findall(r"\[(参考 S\d+)\](?!:)", line))

    if fence is not None:
        fail(path, fence_line, "unclosed code fence")
    for reference in sorted(references - definitions):
        fail(path, 1, f"undefined source reference: {reference}")

    for number, line in prose:
        for match in re.finditer(r"!?\[[^\]]*\]\(([^)]+)\)", line):
            target = match.group(1).strip().strip("<>")
            url = urlsplit(target)
            if url.scheme or not url.path:
                continue
            resolved = (path.parent / unquote(url.path)).resolve()
            if not resolved.exists():
                fail(path, number, f"missing local link: {target}")

required = [
    "docs/Doki-设计方案-v0.4.md",
    "docs/design/APPLE_NATIVE_UI.md",
    "docs/integrations/DANDANPLAY.md",
    "docs/handoff/CURRENT_STATE.md",
    "docs/handoff/HANDOFF.md",
    ".env.example",
]
for relative in required:
    if not (ROOT / relative).is_file():
        ERRORS.append(f"missing required handoff file: {relative}")

if ERRORS:
    print("\n".join(ERRORS))
    sys.exit(1)
print(f"PASS: {len(DOCUMENTS)} Markdown files; local links, tables, fences, source references and JSON examples.")
print("Documentation checks only; no build, authenticated API, deployment or playback verification.")
