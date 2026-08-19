#!/usr/bin/env python3
"""PreToolUse guard — enforces red lines mechanically (GAME-RULES SS1.7, CLAUDE.md PD5).

Claude Code pipes tool-call JSON to stdin. Exit 0 = allow, exit 2 = block (stderr is
shown to Claude). Instructions can be rationalized around at 2am; this can't.

Wire-up lives in .claude/settings.json. Verify the current hook input schema against
the official docs (code.claude.com/docs -> hooks) before first use -- field names have
evolved across versions.
"""
import hashlib
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


# =====================================================================================
# APPROVED-AMENDMENT SEAM (added 2026-08-18, P17)
#
# The block above is absolute: nothing may Edit/Write GAME-RULES.md, ever. That is
# correct and stays. But it left domain law with NO application path at all -- an
# amendment the user had explicitly approved could not be applied by any means, which
# does not make the law safer, it just moves the pressure to working around the guard.
#
# This seam is the sanctioned alternative, and it is DELIBERATELY AWKWARD:
#   * it is not reachable from the hook path at all (different entry point, explicit
#     mode flag, plus a second flag whose name you cannot type by accident);
#   * it applies ONLY a pre-declared exact payload from a manifest -- never free text;
#   * it FAILS CLOSED on the pre-edit hash AND on the exact old text, so it cannot run
#     against a file that has drifted from what was reviewed;
#   * it verifies AFTER writing that the approved text landed exactly and that nothing
#     else in the file moved.
#
# Awkwardness is the feature. Applying domain law should feel like operating machinery,
# not like saving a file. Adversarial coverage lives in scripts/test_guard_amendment.py
# -- an untested governance mechanism guarding the most dangerous file in the repo is
# the TelegraphIndicator.set_active lesson waiting to recur (BRAIN).
# =====================================================================================

AMEND_MODE_FLAG = "--amend"
AMEND_CONFIRM_FLAG = "--i-have-explicit-user-approval"


def _amend_fail(message: str) -> int:
    print("AMENDMENT REFUSED: %s" % message, file=sys.stderr)
    return 2


def _payload_lines(edits: list) -> tuple[set, set]:
    """Every line the manifest is permitted to remove, and to add."""
    removable: set = set()
    addable: set = set()
    for edit in edits:
        removable.update(str(edit.get("old", "")).splitlines())
        addable.update(str(edit.get("new", "")).splitlines())
        addable.update(str(edit.get("text", "")).splitlines())
        # An insert_after keeps its anchor, so the anchor's lines legitimately appear on
        # both sides of the diff.
        anchor_lines = str(edit.get("anchor", "")).splitlines()
        removable.update(anchor_lines)
        addable.update(anchor_lines)
    return removable, addable


def _unrelated_lines_changed(before: str, after: str, edits: list) -> list:
    """Lines that moved but are NOT attributable to an approved payload.

    Diff-based rather than hash-based on purpose: a hash mismatch says "something is
    wrong", this says WHICH line, which is the difference between a usable refusal and
    a mysterious one.
    """
    import difflib

    removable, addable = _payload_lines(edits)
    before_lines = before.splitlines()
    after_lines = after.splitlines()
    offenders: list = []
    matcher = difflib.SequenceMatcher(None, before_lines, after_lines, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        for line in before_lines[i1:i2]:
            if line not in removable:
                offenders.append("removed: %r" % line)
        for line in after_lines[j1:j2]:
            if line not in addable:
                offenders.append("added: %r" % line)
    return offenders


def apply_amendment(manifest_path: str, argv: list, writer=None) -> int:
    """Apply one approved amendment described by a manifest. Returns 0 on success.

    `writer` exists ONLY so the adversarial tests can inject a saboteur write and prove
    the post-write verification actually catches it. Production always uses the default.
    """
    if AMEND_CONFIRM_FLAG not in argv:
        return _amend_fail(
            "amendment mode also requires %s -- domain law is not amended by a flag you "
            "could pass by habit" % AMEND_CONFIRM_FLAG
        )

    try:
        manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return _amend_fail("manifest unreadable (%s)" % error)

    target = str(manifest.get("target", ""))
    if not any(target.endswith(name) for name in PROTECTED_FILES):
        return _amend_fail(
            "target %r is not a protected law file -- this seam exists ONLY for %s, "
            "everything else uses ordinary edits" % (target, ", ".join(PROTECTED_FILES))
        )
    if not str(manifest.get("approval", "")).strip():
        return _amend_fail("manifest carries no 'approval' citation naming the in-conversation approval")

    edits = manifest.get("edits") or []
    if not isinstance(edits, list) or not edits:
        return _amend_fail("manifest declares no edits")

    target_path = Path(target)
    try:
        before_bytes = target_path.read_bytes()
    except OSError as error:
        return _amend_fail("cannot read %s (%s)" % (target, error))

    # FAIL CLOSED #1: the file must be byte-identical to what was reviewed.
    actual_hash = hashlib.sha256(before_bytes).hexdigest()
    expected_hash = str(manifest.get("pre_sha256", ""))
    if actual_hash != expected_hash:
        return _amend_fail(
            "pre-edit state mismatch: %s is sha256 %s, manifest expects %s -- the file "
            "has drifted since the text was approved, so the approval no longer covers it"
            % (target, actual_hash, expected_hash)
        )

    try:
        before_text = before_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        return _amend_fail("%s is not valid UTF-8 (%s)" % (target, error))

    # FAIL CLOSED #2: every approved payload must anchor exactly once. Zero occurrences
    # means the approved text does not describe this file; more than one means the edit
    # is ambiguous about which site it governs.
    after_text = before_text
    for index, edit in enumerate(edits):
        kind = str(edit.get("kind", ""))
        if kind == "replace":
            old = str(edit.get("old", ""))
            new = str(edit.get("new", ""))
            if not old:
                return _amend_fail("edit %d: 'replace' with empty old text" % index)
            count = after_text.count(old)
            if count != 1:
                return _amend_fail(
                    "edit %d: approved old text matched %d times, expected exactly 1" % (index, count)
                )
            after_text = after_text.replace(old, new)
        elif kind == "insert_after":
            anchor = str(edit.get("anchor", ""))
            text = str(edit.get("text", ""))
            if not anchor or not text:
                return _amend_fail("edit %d: 'insert_after' needs both anchor and text" % index)
            count = after_text.count(anchor)
            if count != 1:
                return _amend_fail(
                    "edit %d: anchor matched %d times, expected exactly 1" % (index, count)
                )
            after_text = after_text.replace(anchor, anchor + text)
        else:
            return _amend_fail("edit %d: unknown kind %r" % (index, kind))

    if after_text == before_text:
        return _amend_fail("the manifest produces no change -- refusing a no-op amendment")

    # FAIL CLOSED #3: nothing outside the approved payloads may move, checked BEFORE the
    # write so a bad manifest never touches the file at all.
    offenders = _unrelated_lines_changed(before_text, after_text, edits)
    if offenders:
        return _amend_fail(
            "the manifest would change content outside its approved payload:\n  " + "\n  ".join(offenders[:10])
        )

    expected_bytes = after_text.encode("utf-8")
    write = writer if writer is not None else (lambda path, data: Path(path).write_bytes(data))
    try:
        write(target, expected_bytes)
    except OSError as error:
        return _amend_fail("write failed (%s)" % error)

    # POST-WRITE VERIFICATION, read back from disk. Everything above reasoned about
    # intent; this is the only step that knows what actually landed.
    #
    # ANY failure here ROLLS BACK to the pre-edit bytes. A refusal that leaves domain law
    # in a half-amended state is worse than either outcome it was choosing between: the
    # file would be neither what was approved nor what was reviewed, and the next run's
    # pre-edit hash check would refuse to touch it -- a self-inflicted deadlock on the one
    # file that must always be trustworthy.
    def _rollback(reason: str) -> int:
        try:
            target_path.write_bytes(before_bytes)
            restored = hashlib.sha256(target_path.read_bytes()).hexdigest() == actual_hash
        except OSError as error:
            return _amend_fail(
                "%s\n  ROLLBACK ALSO FAILED (%s) -- %s is in an UNKNOWN state, restore it "
                "from git before doing anything else" % (reason, error, target)
            )
        if not restored:
            return _amend_fail("%s\n  ROLLBACK VERIFICATION FAILED -- restore %s from git" % (reason, target))
        return _amend_fail("%s\n  rolled back: %s restored to sha256 %s" % (reason, target, actual_hash))

    written_bytes = target_path.read_bytes()
    try:
        written_text = written_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        return _rollback("POST-WRITE: %s is no longer valid UTF-8 (%s)" % (target, error))

    landed_offenders = _unrelated_lines_changed(before_text, written_text, edits)
    if landed_offenders:
        return _rollback(
            "POST-WRITE: unrelated content changed on disk:\n  " + "\n  ".join(landed_offenders[:10])
        )

    for index, edit in enumerate(edits):
        approved = str(edit.get("new", "")) or str(edit.get("text", ""))
        if approved and written_text.count(approved) != 1:
            return _rollback(
                "POST-WRITE: edit %d's approved text is not present exactly once on disk" % index
            )

    written_hash = hashlib.sha256(written_bytes).hexdigest()
    if written_hash != hashlib.sha256(expected_bytes).hexdigest():
        return _rollback(
            "POST-WRITE: %s hashed %s, expected %s -- the bytes on disk are not the bytes "
            "that were approved" % (target, written_hash, hashlib.sha256(expected_bytes).hexdigest())
        )

    print("AMENDMENT APPLIED: %s" % target)
    print("  approval:  %s" % manifest["approval"])
    print("  pre  sha256: %s" % actual_hash)
    print("  post sha256: %s" % written_hash)
    for name, char in (("SECT", "§"), ("EMDASH", "—"), ("ARROW", "→")):
        print("  %-7s before=%d after=%d" % (name, before_text.count(char), written_text.count(char)))
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == AMEND_MODE_FLAG:
        sys.exit(apply_amendment(sys.argv[2], sys.argv[3:]))
    sys.exit(main())
