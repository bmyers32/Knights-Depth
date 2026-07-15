#!/usr/bin/env python3
"""PreToolUse guard — enforces red lines mechanically (GAME-RULES SS1.7, CLAUDE.md PD5).

Claude Code pipes tool-call JSON to stdin. Exit 0 = allow, exit 2 = block (stderr is
shown to Claude). Instructions can be rationalized around at 2am; this can't.

Wire-up lives in .claude/settings.json. Verify the current hook input schema against
the official docs (code.claude.com/docs -> hooks) before first use -- field names have
evolved across versions.
"""
import json
import sys

BLOCKED_CONTENT = [
    # SK IP must never enter the repo (CLAUDE.md Prime Directive 5)
    "spiral knights", "grey havens", "three rings",
    # Common signs of ripped assets
    "projectx-pcode", "clyde.jar",
]
PROTECTED_FILES = [
    # Domain law changes require explicit human approval (GAME-RULES header)
    "GAME-RULES.md",
]

def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # never break the session on malformed input; fail open, log nothing

    tool_input = payload.get("tool_input", {}) or {}
    path = str(tool_input.get("file_path", "") or tool_input.get("path", ""))
    content = str(
        tool_input.get("content", "")
        or tool_input.get("new_str", "")
        or tool_input.get("file_text", "")
    ).lower()

    for name in PROTECTED_FILES:
        if path.endswith(name):
            print(
                f"BLOCKED: {name} is domain law — amend it only via its Change Log, "
                "with explicit user approval in the conversation first.",
                file=sys.stderr,
            )
            return 2

    # IP guard is scoped: root-level planning docs (*.md at repo root) may legitimately
    # NAME the inspiration; game content, code, scenes, and assets may never contain it.
    lowered_path = path.lower().replace("\\", "/")
    is_root_doc = lowered_path.endswith(".md") and "/" not in lowered_path.strip("./")
    if not is_root_doc:
        for term in BLOCKED_CONTENT:
            if term in content or term in lowered_path:
                print(
                    f"BLOCKED: '{term}' violates Prime Directive 5 (no reference-game IP "
                    "in game files). Use original names/assets; log them in ASSETS.md.",
                    file=sys.stderr,
                )
                return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
