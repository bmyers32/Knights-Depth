#!/usr/bin/env python3
"""Vocabulary/IP guard -- enforces red lines mechanically (GAME-RULES SS1.7, SS6.7, CLAUDE.md PD5).

ONE rule function (`check_file`), three enforcement entry points:

  (stdin JSON)     PreToolUse hook, wired in .claude/settings.json. Sees ONE Edit/Write.
                   Exit 0 = allow, exit 2 = block (stderr is shown to Claude).
  --scan           Repository audit for /gate: every tracked and untracked, non-ignored
                   file, read from the WORKING TREE. Names what it read.
  --staged         Git pre-commit (.githooks/pre-commit): staged files, read from the INDEX.
  --install-hook   Point this clone's core.hooksPath at .githooks -- never over an
  --hook-status    existing custom hook setup.

Run with no input it prints this usage and exits non-zero: an exit code from a tool
that read nothing is not evidence (BRAIN #19). The Git hook is defence in depth, not a
security boundary (`git commit --no-verify` skips it) -- /gate's --scan stays required.

--amend is the separate approved-amendment seam for GAME-RULES.md, further down.
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import NamedTuple

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

# LEXICON.md "Banned & Watch Terms" -- hard-block, scoped by TOP-LEVEL directory to
# shipped/tested content and the tools that produce it. Case-insensitive; matched
# against both path and content, since these terms show up in filenames as often as
# in prose. LEXICON.md is the spec: --scan fails if this list or scope disagrees with it.
LEXICON_BANNED = [
    "navi", "net king", "netking", "dark web", "undernet", "virus", "corruption",
]
LEXICON_SCOPE_DIRS = {"game", "tests", "content", "tools"}
LEXICON_FILE = "LEXICON.md"

# These two files must hold the banned/IP terms verbatim as data to detect them, so
# scanning them is a permanent false positive. Exempt by exact identity, never by
# directory or pattern, so the exemption cannot widen; test_guard_scan.py pins the set.
SELF_EXEMPT = frozenset({"scripts/guard.py", "scripts/test_guard_scan.py"})

HOOKS_DIR = ".githooks"

# "knight" is retired (Envoy replaces it, LEXICON.md People) but only warn, never
# block -- scoped to game/ only. Exempt: asset filenames, the repo name, README.
WARN_TERM = "knight"
WARN_SCOPE_DIRS = {"game"}
REPO_NAME_TAILS = {"depth", "depths"}
# Godot writes a sidecar next to every asset; it inherits the asset's exemption.
ASSET_SIDECAR_SUFFIXES = (".import", ".uid")
ASSET_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tga", ".svg",
    ".glb", ".gltf", ".fbx", ".blend", ".obj",
    ".wav", ".ogg", ".mp3", ".ttf", ".otf",
}
README_NAMES = {"readme.md", "readme"}


class GuardError(Exception):
    """The guard could not complete its inspection. Always a failure, never a pass."""


class Finding(NamedTuple):
    severity: str  # "BLOCK" | "WARN"
    rule: str      # "IP" | "LEXICON" | "WATCH"
    term: str
    line: int      # 0 = the path itself


_RULE_MESSAGE = {
    "IP": "violates Prime Directive 5 (no reference-game IP in game files). "
          "Use original names/assets; log them in ASSETS.md.",
    "LEXICON": "is a banned term (LEXICON.md Banned & Watch Terms). "
               "Use the vocabulary law's replacement instead.",
    "WATCH": "is retired by LEXICON.md (Envoy replaces it everywhere except the repo "
             "name/README/asset filenames). Not blocked; rename when convenient.",
}


# ---- matching (R1, 2026-10-09) ------------------------------------------------------
# TOKEN matching, not substring matching: text is cut into words at punctuation,
# underscores, digits and camelCase humps, and a term must match whole words. So
# "navigation" and "NavigationServer3D" pass while "navi_mode", "NaviCore" and
# "NAVI_MODE" are caught.
#
# KNOWN LIMITS, accepted rather than solved with a parser:
#   * an all-lowercase run-on of a single-word term ("navimode") is one token and is
#     NOT caught -- catching it is the substring rule that blocked "navigation";
#   * a multi-word term split across two lines is not caught.
_SEGMENT = re.compile(r"[A-Za-z0-9]+")
_HUMP = re.compile(r"[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|[0-9]+")


def tokenize(text: str) -> list[str]:
    return [hump.lower() for segment in _SEGMENT.findall(text) for hump in _HUMP.findall(segment)]


def _same_word(token: str, word: str) -> bool:
    return token in (word, word + "s", word + "es")


def term_in_tokens(tokens: list[str], term: str) -> bool:
    """True when `term`'s words appear as a consecutive run of whole tokens. Simple
    plurals count, and a multi-word term also matches written as one word."""
    words = tokenize(term)
    if not words:
        return False
    count = len(words)
    joined = "".join(words)
    for index, token in enumerate(tokens):
        if count > 1 and _same_word(token, joined):
            return True
        window = tokens[index:index + count]
        if len(window) == count and window[:-1] == words[:-1] and _same_word(window[-1], words[-1]):
            return True
    return False


def _watch_term_in_tokens(tokens: list[str]) -> bool:
    for index, token in enumerate(tokens):
        if not _same_word(token, WARN_TERM):
            continue
        following = tokens[index + 1] if index + 1 < len(tokens) else ""
        if following not in REPO_NAME_TAILS:
            return True
    return False


def _is_asset_path(rel_lower: str) -> bool:
    name = rel_lower
    for sidecar in ASSET_SIDECAR_SUFFIXES:
        if name.endswith(sidecar):
            name = name[: -len(sidecar)]
    return PurePosixPath(name).suffix in ASSET_EXTENSIONS


def top_level_dir(rel: str) -> str:
    parts = PurePosixPath(rel).parts
    return parts[0].lower() if len(parts) > 1 else ""


def check_file(rel: str, text: str | None) -> list[Finding]:
    """THE rule function: every entry point calls this and none re-implements a rule.

    `rel` is the repo-relative POSIX path; `text` is the content to inspect, or None
    for a binary file (the path is still checked).
    """
    rel_lower = rel.lower()
    if rel_lower in SELF_EXEMPT:
        return []

    top = top_level_dir(rel)
    numbered = [(0, rel)] + list(enumerate((text or "").splitlines(), 1))
    tokenized = [(number, tokenize(line)) for number, line in numbered]
    findings: list[Finding] = []

    def scan(terms: list[str], severity: str, rule: str) -> None:
        for number, tokens in tokenized:
            if not tokens:
                continue
            for term in terms:
                if term_in_tokens(tokens, term):
                    findings.append(Finding(severity, rule, term, number))

    # Root-level planning docs (*.md at repo root) may legitimately NAME the
    # inspiration; game content, code, scenes, and assets may never contain it.
    is_root_doc = "/" not in rel and rel_lower.endswith(".md")
    if not is_root_doc:
        scan(IP_BLOCKED_CONTENT, "BLOCK", "IP")

    # Files outside the governed scope (root docs, ASSETS.md, etc.) may legitimately
    # discuss banned terms -- e.g. GAME-RULES change-log history, BRAIN retrospectives.
    if top in LEXICON_SCOPE_DIRS:
        scan(LEXICON_BANNED, "BLOCK", "LEXICON")

    if top in WARN_SCOPE_DIRS:
        is_readme = PurePosixPath(rel_lower).name in README_NAMES
        if not _is_asset_path(rel_lower) and not is_readme:
            for number, tokens in tokenized:
                if _watch_term_in_tokens(tokens):
                    findings.append(Finding("WARN", "WATCH", WARN_TERM, number))

    return findings


def _print_findings(findings_by_path: list[tuple[str, list[Finding]]], stream) -> int:
    """Prints every finding; returns the number of BLOCK findings."""
    blocks = 0
    for rel, findings in findings_by_path:
        for finding in findings:
            where = rel if finding.line == 0 else "%s:%d" % (rel, finding.line)
            label = "BLOCKED" if finding.severity == "BLOCK" else "WARN"
            if finding.line == 0:
                where += " (path)"
            print("%s: %s -- '%s' %s" % (label, where, finding.term, _RULE_MESSAGE[finding.rule]), file=stream)
            blocks += finding.severity == "BLOCK"
    return blocks


def _decode(data: bytes) -> str | None:
    """Text to inspect, or None for binary. A NUL byte means binary (glb, png, UTF-16).
    Anything else is read as UTF-8 with replacement, so a mis-encoded text file is
    still inspected rather than skipped."""
    if b"\0" in data:
        return None
    return data.decode("utf-8", errors="replace")


# ---- git plumbing -------------------------------------------------------------------
def _git(args: list[str], cwd: Path, allow_codes: tuple = (0,)) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True)
    except OSError as error:
        raise GuardError("could not run git (%s)" % error)
    if result.returncode not in allow_codes:
        raise GuardError(
            "git %s failed (exit %d): %s"
            % (" ".join(args), result.returncode, result.stderr.decode("utf-8", "replace").strip())
        )
    return result


def repo_root() -> Path:
    out = _git(["rev-parse", "--show-toplevel"], Path.cwd()).stdout.decode("utf-8").strip()
    if not out:
        raise GuardError("not inside a git working tree")
    return Path(out)


def _z_paths(raw: bytes) -> list[str]:
    return [item.decode("utf-8") for item in raw.split(b"\0") if item]


# ---- LEXICON synchronisation --------------------------------------------------------
def lexicon_problems(root: Path) -> list[str]:
    """Where the machine-enforced lists disagree with LEXICON.md's own definitions.

    Covers ONLY what LEXICON actually specifies: the banned strings, their scope, and
    the single watch term. See _SYNC_NOT_COVERED for what this does NOT establish.
    """
    try:
        text = (root / LEXICON_FILE).read_text(encoding="utf-8")
    except OSError as error:
        return ["cannot read %s (%s)" % (LEXICON_FILE, error)]

    section = re.search(r"\*\*Banned strings\*\*(.*?)\*\*Watch[^*]*\*\*(.*?)(?:\n\s*\n|\Z)", text, re.S)
    if section is None:
        return ["%s has no parseable '**Banned strings** ... **Watch**' section" % LEXICON_FILE]
    banned_text, watch_text = section.group(1), section.group(2)

    scope = re.search(r"\(block in ([^)]*)\)", banned_text)
    if scope is None:
        return ["%s banned-strings line has no '(block in ...)' scope list" % LEXICON_FILE]
    spec_dirs = {name.lower() for name in re.findall(r"([A-Za-z_]+)/", scope.group(1))}
    spec_terms = {term.lower() for term in re.findall(r"`([^`]+)`", banned_text.replace(scope.group(0), ""))}
    watch_terms = [term.lower() for term in re.findall(r"`([^`]+)`", watch_text)]

    problems: list[str] = []
    guard_terms = {term.lower() for term in LEXICON_BANNED}
    for term in sorted(spec_terms - guard_terms):
        problems.append("LEXICON bans '%s' but the guard does not enforce it" % term)
    for term in sorted(guard_terms - spec_terms):
        problems.append("the guard bans '%s' but LEXICON does not list it" % term)
    for name in sorted(spec_dirs - LEXICON_SCOPE_DIRS):
        problems.append("LEXICON scopes the ban to %s/ but the guard does not govern it" % name)
    for name in sorted(LEXICON_SCOPE_DIRS - spec_dirs):
        problems.append("the guard governs %s/ but LEXICON's scope does not list it" % name)
    if not spec_terms:
        problems.append("LEXICON lists no banned strings at all")
    if watch_terms[:1] != [WARN_TERM]:
        problems.append("LEXICON's first watch term is %r, the guard warns on '%s'" % (watch_terms[:1], WARN_TERM))
    return problems


_SYNC_NOT_COVERED = (
    "  NOT covered by that check:",
    "    - IP terms (%d): LEXICON.md does not define them; scripts/guard.py is their only home.",
    "    - 'Pattern/Loom/Thread appearing together': unspecified in LEXICON, NOT enforced.",
)


# ---- --scan -------------------------------------------------------------------------
def scan_repo() -> int:
    root = repo_root()
    listed = _z_paths(_git(["ls-files", "-co", "--exclude-standard", "-z"], root).stdout)

    per_scope = {name: 0 for name in sorted(LEXICON_SCOPE_DIRS)}
    text_count = binary_count = root_docs = 0
    exempt: list[str] = []
    missing: list[str] = []
    results: list[tuple[str, list[Finding]]] = []

    for rel in sorted(set(listed)):
        path = root / rel
        if not path.is_file():
            missing.append(rel)  # tracked but deleted in the working tree
            continue
        if rel.lower() in SELF_EXEMPT:
            exempt.append(rel)
            continue
        try:
            data = path.read_bytes()
        except OSError as error:
            raise GuardError("cannot read %s (%s)" % (rel, error))
        text = _decode(data)
        if text is None:
            binary_count += 1
        else:
            text_count += 1
        top = top_level_dir(rel)
        if top in per_scope:
            per_scope[top] += 1
        if "/" not in rel and rel.lower().endswith(".md"):
            root_docs += 1
        findings = check_file(rel, text)
        if findings:
            results.append((rel, findings))

    inspected = text_count + binary_count
    governed = sum(per_scope.values())
    print("GUARD SCAN  %s" % root)
    print("  source: working tree -- tracked + untracked, non-ignored (git ls-files -co --exclude-standard)")
    print("  files inspected: %d  (text %d, binary path-only %d)" % (inspected, text_count, binary_count))
    print("  vocabulary-governed: %d  (%s)" % (governed, ", ".join("%s/ %d" % item for item in per_scope.items())))
    print("  IP-governed: %d  (all inspected files except %d root-level *.md)" % (inspected - root_docs, root_docs))
    print("  exempt by identity: %d  (%s)" % (len(exempt), ", ".join(exempt) or "none present"))
    if missing:
        print("  listed but absent from the working tree (not inspected): %d" % len(missing))
    print("  terms: %d banned (LEXICON), %d IP, 1 watch" % (len(LEXICON_BANNED), len(IP_BLOCKED_CONTENT)))

    failed = False
    problems = lexicon_problems(root)
    if problems:
        failed = True
        print("  LEXICON sync: FAIL")
        for problem in problems:
            print("    - %s" % problem)
    else:
        print("  LEXICON sync: OK for banned strings, their scope, and the watch term")
    for line in _SYNC_NOT_COVERED:
        print(line % len(IP_BLOCKED_CONTENT) if "%d" in line else line)

    state, detail = hook_state(root)
    print("  pre-commit hook: %s -- %s" % (state, detail))

    blocks = _print_findings(results, sys.stdout)
    warns = sum(1 for _, findings in results for finding in findings if finding.severity == "WARN")

    if inspected == 0:
        failed = True
        print("FAIL: zero files inspected -- nothing was verified.")
    elif governed == 0:
        failed = True
        print("FAIL: zero files inspected under any governed scope -- the vocabulary rules checked nothing.")
    if blocks:
        failed = True
    print("RESULT: %s  (%d blocking, %d warnings)" % ("FAIL" if failed else "PASS", blocks, warns))
    return 1 if failed else 0


# ---- --staged -----------------------------------------------------------------------
def scan_staged() -> int:
    """Inspects what is about to be COMMITTED: paths and bytes come from the index, so
    neither a cleaned-up working file nor a dirty one changes the verdict."""
    root = repo_root()
    staged = _z_paths(_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"], root).stdout)
    results: list[tuple[str, list[Finding]]] = []
    governed = 0
    for rel in staged:
        if top_level_dir(rel) in LEXICON_SCOPE_DIRS:
            governed += 1
        text = _decode(_git(["cat-file", "blob", ":" + rel], root).stdout)
        findings = check_file(rel, text)
        if findings:
            results.append((rel, findings))
    blocks = _print_findings(results, sys.stderr)
    print(
        "guard --staged: %d staged file(s) inspected from the index (%d vocabulary-governed), %d blocking"
        % (len(staged), governed, blocks),
        file=sys.stderr,
    )
    if blocks:
        print("COMMIT REFUSED by scripts/guard.py. Fix the staged content and re-add it.", file=sys.stderr)
        return 1
    return 0


# ---- hook installation --------------------------------------------------------------
def hook_state(root: Path) -> tuple[str, str]:
    """(state, human detail). States: INSTALLED, NOT INSTALLED, FOREIGN, CUSTOM, BROKEN."""
    configured = _git(["config", "--get", "core.hooksPath"], root, allow_codes=(0, 1)).stdout.decode("utf-8").strip()
    hook_file = root / HOOKS_DIR / "pre-commit"
    if configured:
        if configured.replace("\\", "/").rstrip("/") != HOOKS_DIR:
            return "FOREIGN", "core.hooksPath is already '%s'; left untouched" % configured
        if not hook_file.is_file():
            return "BROKEN", "core.hooksPath is %s but %s/pre-commit does not exist" % (HOOKS_DIR, HOOKS_DIR)
        return "INSTALLED", "core.hooksPath=%s" % HOOKS_DIR
    common = _git(["rev-parse", "--git-common-dir"], root).stdout.decode("utf-8").strip()
    default_hooks = (root / common / "hooks")
    custom = sorted(
        entry.name for entry in default_hooks.iterdir() if entry.is_file() and entry.suffix != ".sample"
    ) if default_hooks.is_dir() else []
    if custom:
        return "CUSTOM", "existing hook(s) in .git/hooks would be disabled: %s; left untouched" % ", ".join(custom)
    if not hook_file.is_file():
        return "BROKEN", "%s/pre-commit does not exist" % HOOKS_DIR
    return "NOT INSTALLED", "run: python scripts/guard.py --install-hook"


def install_hook() -> int:
    root = repo_root()
    state, detail = hook_state(root)
    if state == "NOT INSTALLED":
        _git(["config", "--local", "core.hooksPath", HOOKS_DIR], root)
        state, detail = hook_state(root)
        print("pre-commit hook: %s -- %s (set by this run)" % (state, detail))
        return 0 if state == "INSTALLED" else 1
    if state == "INSTALLED":
        print("pre-commit hook: INSTALLED -- %s (already; nothing changed)" % detail)
        return 0
    print("pre-commit hook: NOT INSTALLED (%s) -- %s. Nothing was changed." % (state, detail), file=sys.stderr)
    return 1


def hook_status() -> int:
    state, detail = hook_state(repo_root())
    print("pre-commit hook: %s -- %s" % (state, detail))
    return 0 if state == "INSTALLED" else 1


# ---- PreToolUse hook ----------------------------------------------------------------
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


def _hook_refuse(reason: str) -> int:
    # FAIL CLOSED: an edit the guard could not inspect is not an edit the guard allowed.
    print("BLOCKED: guard could not inspect this tool call (%s)." % reason, file=sys.stderr)
    return 2


def hook_main() -> int:
    raw = b"" if sys.stdin is None or sys.stdin.isatty() else sys.stdin.buffer.read()
    if not raw.strip():
        print(__doc__.strip(), file=sys.stderr)
        print("\nNO INPUT: nothing was inspected. This is a failure, not a pass.", file=sys.stderr)
        return 1

    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        return _hook_refuse("payload is not valid UTF-8 JSON: %s" % error)
    if not isinstance(payload, dict) or not isinstance(payload.get("tool_input"), dict):
        return _hook_refuse("payload has no tool_input object")
    tool_input = payload["tool_input"]
    path = tool_input.get("file_path") or tool_input.get("path")
    if not isinstance(path, str) or not path.strip():
        return _hook_refuse("tool_input names no file path")

    for name in PROTECTED_FILES:
        if path.endswith(name):
            print(
                f"BLOCKED: {name} is domain law — amend it only via its Change Log, "
                "with explicit user approval in the conversation first.",
                file=sys.stderr,
            )
            return 2

    # Never string-match path shape, always resolve with pathlib (BRAIN path-check lesson).
    try:
        base = Path.cwd().resolve()
        resolved = (base / path).resolve()
    except OSError as error:
        return _hook_refuse("cannot resolve path %r: %s" % (path, error))
    try:
        rel = resolved.relative_to(base).as_posix()
    except ValueError:
        # Outside the repository: not repo content. It can only enter through a file
        # that --scan and --staged will read.
        return 0

    blocks = _print_findings([(rel, check_file(rel, extract_written_text(tool_input)))], sys.stderr)
    return 2 if blocks else 0


def main(argv: list[str]) -> int:
    modes = {"--scan": scan_repo, "--staged": scan_staged, "--install-hook": install_hook, "--hook-status": hook_status}
    if not argv:
        return hook_main()
    if len(argv) == 1 and argv[0] in modes:
        try:
            return modes[argv[0]]()
        except GuardError as error:
            print("GUARD FAILED TO COMPLETE (%s): %s" % (argv[0], error), file=sys.stderr)
            return 1
    print(__doc__.strip(), file=sys.stderr)
    print("\nUNRECOGNISED ARGUMENTS %r: nothing was inspected." % (argv,), file=sys.stderr)
    return 1


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
    sys.exit(main(sys.argv[1:]))
