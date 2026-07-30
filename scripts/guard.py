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
from pathlib import Path

# SK IP must never enter the repo (CLAUDE.md Prime Directive 5). Repo-wide except
# root-level *.md docs, which may legitimately name the inspiration (README, etc).
IP_BLOCKED_CONTENT = [
    "spiral knights", "grey havens", "three rings",
    # Common signs of ripped assets
    "projectx-pcode", "clyde.jar",
]

PROTECTED_FILES = [
    # Domain law changes require explicit human approval (GAME-RULES header)
    "GAME-RULES.md",
]

# LEXICON.md "Banned & Watch Terms" -- hard-block, scoped to shipped/tested content
# only (game/, tests/, content/). Case-insensitive; matched against both path and
# written content, since these terms show up in filenames as often as in prose.
LEXICON_BANNED = [
    "navi", "net king", "netking", "dark web", "undernet", "virus", "corruption",
]
LEXICON_SCOPE_DIRS = {"game", "tests", "content"}

# "knight" is retired (Envoy replaces it, LEXICON.md People) but only warn, never
# block -- scoped to game/ only. Exempt: asset filenames, the repo name, README.
WARN_TERM = "knight"
WARN_SCOPE_DIRS = {"game"}
REPO_NAME = "knight depths"
ASSET_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tga", ".svg",
    ".glb", ".gltf", ".fbx", ".blend", ".obj",
    ".wav", ".ogg", ".mp3", ".ttf", ".otf",
}
README_NAMES = {"readme.md", "readme"}


def resolve_relative(path_str: str) -> Path | None:
    """Resolve a hook-supplied path (relative or absolute, either is possible)
    to a path relative to the repo root, per BRAIN's path-check lesson: never
    string-match path shape, always resolve with pathlib."""
    if not path_str:
        return None
    raw = Path(path_str)
    try:
        if raw.is_absolute():
            return raw.resolve().relative_to(Path.cwd().resolve())
        return raw
    except (OSError, ValueError):
        return None


def path_in_dirs(rel_path: Path | None, dirs: set[str]) -> bool:
    if rel_path is None:
        return False
    return any(part.lower() in dirs for part in rel_path.parts)


def extract_written_text(tool_input: dict) -> str:
    """Pull all text a Write/Edit/MultiEdit call would introduce into the file."""
    parts = [
        str(tool_input.get("content", "")),
        str(tool_input.get("new_string", "")),
        str(tool_input.get("file_text", "")),
    ]
    for edit in tool_input.get("edits", []) or []:
        if isinstance(edit, dict):
            parts.append(str(edit.get("new_string", "")))
    return "\n".join(p for p in parts if p)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # never break the session on malformed input; fail open, log nothing

    tool_input = payload.get("tool_input", {}) or {}
    path = str(tool_input.get("file_path", "") or tool_input.get("path", ""))
    lowered_path = path.lower()
    content = extract_written_text(tool_input)
    lowered_content = content.lower()
    rel_path = resolve_relative(path)

    # This file must contain the banned/IP terms verbatim as data to detect them --
    # scanning its own content is a permanent false positive. Exempt by identity,
    # not by directory scope, so the exemption can't accidentally widen.
    if rel_path is not None and rel_path.as_posix().lower() == "scripts/guard.py":
        return 0

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
    is_root_doc = False
    if lowered_path.endswith(".md"):
        try:
            is_root_doc = Path(path).resolve().parent == Path.cwd().resolve()
        except OSError:
            is_root_doc = False
    if not is_root_doc:
        for term in IP_BLOCKED_CONTENT:
            if term in lowered_content or term in lowered_path:
                print(
                    f"BLOCKED: '{term}' violates Prime Directive 5 (no reference-game IP "
                    "in game files). Use original names/assets; log them in ASSETS.md.",
                    file=sys.stderr,
                )
                return 2

    # LEXICON.md banned terms: hard-block within game/, tests/, content/ only.
    # Files outside that scope (root docs, ASSETS.md, etc.) may legitimately discuss
    # these terms -- e.g. GAME-RULES change-log history, BRAIN retrospectives.
    if path_in_dirs(rel_path, LEXICON_SCOPE_DIRS):
        for term in LEXICON_BANNED:
            if term in lowered_content or term in lowered_path:
                print(
                    f"BLOCKED: '{term}' is a banned term (LEXICON.md Banned & Watch "
                    "Terms). Use the vocabulary law's replacement instead.",
                    file=sys.stderr,
                )
                return 2

    # "knight" watch term: warn only, never block. Scoped to game/; exempt asset
    # filenames, the repo name ("Knight Depths"), and README.
    if path_in_dirs(rel_path, WARN_SCOPE_DIRS):
        suffix = Path(path).suffix.lower()
        basename = Path(path).name.lower()
        is_asset = suffix in ASSET_EXTENSIONS
        is_readme = basename in README_NAMES
        if not is_asset and not is_readme:
            scrubbed = (lowered_path + "\n" + lowered_content).replace(REPO_NAME, "")
            if WARN_TERM in scrubbed:
                print(
                    "WARN: 'knight' found in new game/ code — LEXICON.md retired this "
                    "term (Envoy replaces it everywhere except the repo name/README/"
                    "asset filenames). Not blocked; rename when convenient.",
                    file=sys.stderr,
                )

    return 0


if __name__ == "__main__":
    sys.exit(main())
