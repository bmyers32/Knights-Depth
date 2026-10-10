#!/usr/bin/env python3
"""Adversarial coverage for guard.py's vocabulary/IP enforcement.

Run:  python scripts/test_guard_scan.py

WHY THIS FILE EXISTS. Until 2026-10-09 the blocking half of the guard had no tests at all,
and it showed: run bare it read nothing and exited 0, and it substring-matched so hard that
"navigation" was a banned word (BRAIN #19). A scanner never proven to fail is not a scanner.

So every claim here is made twice: a KNOWN-POSITIVE that must go red and a KNOWN-NEGATIVE
that must stay green. The positives and negatives are FIXED LITERALS, never iterated out of
the guard's own lists -- a test that reads its expectations from the code under test passes
when that code is wrong. That is why this file holds banned terms verbatim, and why it is one
of exactly two files the guard exempts by identity.

Prohibited commits are attempted ONLY in throwaway repositories under the temp directory,
through the real hook file installed by the real installer. Nothing here stages or commits
in the game repository.

No pytest dependency (this repo has none); stdlib only, self-contained runner.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REAL_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REAL_ROOT / "scripts"))
import guard  # noqa: E402

REAL_GUARD = REAL_ROOT / "scripts" / "guard.py"
REAL_HOOK = REAL_ROOT / ".githooks" / "pre-commit"

LEXICON_OK = (
    "# LEXICON\n\n"
    "## Banned & Watch Terms (guard.py enforcement)\n"
    "**Banned strings** (block in game/, tests/, content/, tools/): `navi` · `net king` ·\n"
    "`netking` · `dark web` · `undernet` · `virus` · `corruption` (the phenomenon is Drift).\n"
    "**Watch (warn, don't block):** `knight` in new game/ code identifiers (rename law —\n"
    "asset filenames and repo name exempt) · Pattern/Loom/Thread appearing together.\n"
    "\n"
    "Notes that follow the spec may use `backticks` freely.\n"
)

CLEAN_GD = "var navigation_target: int = 1\n"

_failures: list = []
_passes: list = []


def check(condition: bool, label: str) -> None:
    (_passes if condition else _failures).append(label)
    print(("  PASS  " if condition else "  FAIL  ") + label)


def blocked(rel: str, text) -> bool:
    return any(f.severity == "BLOCK" for f in guard.check_file(rel, text))


class Repo:
    """A throwaway git repository carrying a COPY of the real guard and the real hook file."""

    def __init__(self, lexicon=LEXICON_OK, git: bool = True, seed: bool = True):
        self._dir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.root = Path(self._dir.name).resolve()
        if git:
            self.git("init", "-q")
            for key, value in (
                ("user.name", "guard test"), ("user.email", "guard@test.invalid"),
                ("commit.gpgsign", "false"), ("core.autocrlf", "false"),
            ):
                self.git("config", "--local", key, value)
        if seed:
            self.write("scripts/guard.py", REAL_GUARD.read_bytes())
            self.write(".githooks/pre-commit", REAL_HOOK.read_bytes())
            self.write("game/ok.gd", CLEAN_GD)
            if lexicon is not None:
                self.write("LEXICON.md", lexicon)

    def write(self, rel: str, content) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode("utf-8"))

    def git(self, *args) -> subprocess.CompletedProcess:
        return subprocess.run(["git", *args], cwd=str(self.root), capture_output=True, text=True, encoding="utf-8", errors="replace")

    def guard(self, *args, stdin: bytes = b"", script: Path = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(script or self.root / "scripts" / "guard.py"), *args],
            cwd=str(self.root), input=stdin, capture_output=True,
        )

    def scan(self) -> tuple[int, str]:
        result = self.guard("--scan")
        return result.returncode, (result.stdout + result.stderr).decode("utf-8", "replace")

    def commits(self) -> int:
        result = self.git("rev-list", "--count", "HEAD")
        return int(result.stdout.strip()) if result.returncode == 0 else 0

    def commit_all_clean(self) -> None:
        self.git("add", "-A")
        result = self.git("commit", "-q", "-m", "baseline")
        assert result.returncode == 0, result.stderr

    def hook(self, tool_input, raw: bytes = None) -> int:
        payload = raw if raw is not None else json.dumps({"tool_name": "Write", "tool_input": tool_input}).encode("utf-8")
        return self.guard(stdin=payload).returncode

    def close(self) -> None:
        self._dir.cleanup()


# ---------------------------------------------------------------------------------
print("\nMATCHER — fixed known-positives must block, fixed known-negatives must pass")
# ---------------------------------------------------------------------------------
for line in (
    "var navi_mode = 1", "class NaviCore:", "const NAVI_MODE = 2", "the Navi answered.",
    "var corruption_level = 0", "var netKing", "net_king_hp", "the dark web", "DarkWeb",
    "darkweb", "three viruses", "func undernet():", "CorruptionMeter",
):
    check(blocked("game/x.gd", line), "blocks  %r" % line)

for line in (
    "no navigation, no NavigationServer3D", "a navigator", "navigational aids", "antivirus",
    "incorruptible", "the network king", "an undernetworked room", "darkness on the web page",
    "[node name=\"Nav\" type=\"NavigationRegion3D\"]",
):
    check(not blocked("game/x.gd", line), "passes  %r" % line)

for line in ("Spiral Knights", "spiral_knights", "SpiralKnights", "by Three Rings", "clyde.jar"):
    check(blocked("addons/x.gd", line), "blocks IP  %r" % line)
for line in ("a spiral of knights", "spiral staircase", "three ringed planets"):
    check(not blocked("addons/x.gd", line), "passes  %r" % line)

check(blocked("game/navi_helper.gd", None), "a banned word in a PATH blocks even with no readable content")
check(not blocked("game/navigation_helper.gd", None), "...and 'navigation' in a path does not")


# ---------------------------------------------------------------------------------
print("\nSCOPE — every governed directory blocks; ungoverned ones do not")
# ---------------------------------------------------------------------------------
for scope in ("game", "tests", "content", "tools"):
    check(blocked("%s/sub/x.gd" % scope, "var virus = 1"), "vocabulary is enforced under %s/" % scope)
for rel in ("addons/gut/x.gd", "scripts/x.py", "NOTES.md", "docs/tools/x.md", "addons/tools/x.gd"):
    check(not blocked(rel, "var virus = 1"), "vocabulary is NOT enforced at %s" % rel)
check(blocked("scripts/x.py", "spiral knights"), "IP terms are enforced outside the vocabulary scope")
check(blocked("docs/notes.md", "spiral knights"), "...including in a non-root markdown file")
check(not blocked("README.md", "inspired by Spiral Knights"), "a root-level doc may name the inspiration")

watch = guard.check_file("game/a.gd", "var knight = 1")
check([f.severity for f in watch] == ["WARN"], "the watch term warns and never blocks")
check(guard.check_file("game/a.gd", "# Knight Depths") == [], "the repo name is not a watch hit")
check(guard.check_file("game/m/Knight.glb.import", "path=\"res://game/m/Knight.glb\"") == [], "an asset's Godot sidecar inherits the asset exemption")
check(guard.check_file("tools/a.gd", "var knight = 1") == [], "the watch term is scoped to game/ only")


# ---------------------------------------------------------------------------------
print("\nEXEMPTIONS — exactly two files, by identity, and they cannot widen silently")
# ---------------------------------------------------------------------------------
check(guard.SELF_EXEMPT == frozenset({"scripts/guard.py", "scripts/test_guard_scan.py"}), "the exempt set is exactly the guard and this test file")
check(guard.check_file("scripts/guard.py", "spiral knights") == [], "the guard's own term data is exempt")
check(blocked("scripts/guard_notes.py", "spiral knights"), "a sibling with a similar name is NOT exempt")
check(blocked("tests/scripts/guard.py", "var virus = 1"), "the same filename at another path is NOT exempt")
check(blocked("game/examples.gd", "# example of a banned word: virus"), "a file is not exempt merely for containing examples")


# ---------------------------------------------------------------------------------
print("\n--scan — reports what it read, and fails when it should")
# ---------------------------------------------------------------------------------
r = Repo()
r.write("tests/t.gd", CLEAN_GD)
r.write("tools/t.gd", CLEAN_GD)
r.write("game/scene.tscn", "[node name=\"Nav\" type=\"NavigationRegion3D\" parent=\".\"]\n")
r.write("game/res.tres", "[gd_resource type=\"Resource\" format=3]\nnavigation_layers = 1\n")
r.write("game/model.glb", b"glTF\x02\x00\x00\x00binary\x00virus\x00")
code, out = r.scan()
check(code == 0, "a clean repo with Godot resources and a binary passes")
check("files inspected: 8  (text 7, binary path-only 1)" in out, "it reports the exact file counts")
check("content/ 0, game/ 4, tests/ 1, tools/ 1" in out, "it reports the count under each governed scope")
check("exempt by identity: 1  (scripts/guard.py)" in out, "it names the exempt file it skipped")
check("NOT enforced" in out and "does not define them" in out, "it does not claim sync for the undefined watch rule or the IP list")
check("RESULT: PASS" in out, "it prints an explicit result line")
r.close()

for scope in ("game", "tests", "content", "tools"):
    r = Repo()
    r.write("%s/bad.gd" % scope, "var corruption_level = 0\n")
    code, out = r.scan()
    check(code == 1 and "%s/bad.gd:1" % scope in out, "an UNTRACKED banned file under %s/ fails the scan, with path:line" % scope)
    r.close()

r = Repo()
r.write("game/bad.gd", "var corruption_level = 0\n")
r.git("add", "-A")
code, out = r.scan()
check(code == 1, "a tracked/staged banned file fails the scan too")
r.close()

r = Repo()
r.write(".gitignore", "build/\n")
r.write("build/bad.gd", "spiral knights\n")
code, out = r.scan()
check(code == 0, "an ignored file is outside the scan (it cannot be committed)")
r.close()

r = Repo()
r.write("addons/thing/spiral_knights_port.gd", "pass\n")
code, out = r.scan()
check(code == 1 and "(path)" in out, "an IP term in a FILENAME outside the vocabulary scope fails the scan")
r.close()

r = Repo(seed=False)
result = r.guard("--scan", script=REAL_GUARD)
check(result.returncode == 1 and b"zero files inspected" in result.stdout, "a repo with no files FAILS: zero inspected is not a pass")
r.close()

r = Repo(seed=False)
r.write("LEXICON.md", LEXICON_OK)
r.write("README.md", "hello\n")
result = r.guard("--scan", script=REAL_GUARD)
check(result.returncode == 1 and b"under any governed scope" in result.stdout, "files present but none in a governed scope also FAILS")
r.close()

r = Repo(git=False, seed=False)
r.write("game/ok.gd", CLEAN_GD)
result = r.guard("--scan", script=REAL_GUARD)
check(result.returncode == 1 and b"GUARD FAILED TO COMPLETE" in result.stderr, "outside a git repository the scan fails visibly")
r.close()


# ---------------------------------------------------------------------------------
print("\nLEXICON SYNC — the scan fails when the spec and the guard disagree")
# ---------------------------------------------------------------------------------
for label, lexicon in (
    ("LEXICON bans a term the guard lacks", LEXICON_OK.replace("`undernet` ·", "`undernet` · `malware` ·")),
    ("the guard bans a term LEXICON dropped", LEXICON_OK.replace("`undernet` · ", "")),
    ("LEXICON's scope omits a governed directory", LEXICON_OK.replace(", tools/)", ")")),
    ("LEXICON's scope adds an ungoverned directory", LEXICON_OK.replace(", tools/)", ", tools/, addons/)")),
    ("LEXICON's watch term differs", LEXICON_OK.replace("`knight`", "`squire`")),
    ("LEXICON has no banned-terms section", "# LEXICON\n\nnothing here\n"),
    ("LEXICON.md is missing", None),
):
    r = Repo(lexicon=lexicon)
    code, out = r.scan()
    check(code == 1 and "LEXICON sync: FAIL" in out, "fails when %s" % label)
    r.close()


# ---------------------------------------------------------------------------------
print("\nPRE-COMMIT — the real hook, really installed, in a throwaway repository")
# ---------------------------------------------------------------------------------
r = Repo()
status = r.guard("--hook-status")
check(status.returncode == 1 and b"NOT INSTALLED" in status.stdout, "before installation the status says NOT INSTALLED and exits non-zero")
install = r.guard("--install-hook")
check(install.returncode == 0 and b"INSTALLED" in install.stdout, "--install-hook installs into a repo with no hook configuration")
check(r.git("config", "--local", "--get", "core.hooksPath").stdout.strip() == ".githooks", "...by setting core.hooksPath=.githooks")
check(r.guard("--install-hook").returncode == 0, "installing twice is a no-op success")
check(r.guard("--hook-status").returncode == 0, "after installation the status exits zero")

r.git("add", "-A")
result = r.git("commit", "-q", "-m", "clean baseline")
check(result.returncode == 0 and r.commits() == 1, "a clean commit passes through the hook")

r.write("game/bad.gd", "var corruption_level = 0\n")
r.git("add", "game/bad.gd")
result = r.git("commit", "-q", "-m", "should be refused")
check(result.returncode != 0 and r.commits() == 1, "PROHIBITED STAGED CONTENT BLOCKS THE COMMIT")
check("COMMIT REFUSED" in result.stderr and "game/bad.gd:1" in result.stderr, "...and the refusal names the file and line")

r.write("game/bad.gd", CLEAN_GD)  # working file cleaned up, index still holds the banned blob
result = r.git("commit", "-q", "-m", "clean tree, dirty index")
check(result.returncode != 0 and r.commits() == 1, "A CLEAN WORKING TREE CANNOT CONCEAL PROHIBITED STAGED CONTENT")

r.git("add", "game/bad.gd")  # now the index is clean...
r.write("game/bad.gd", "var corruption_level = 0\n")  # ...and the working tree is not
result = r.git("commit", "-q", "-m", "clean index, dirty tree")
check(result.returncode == 0 and r.commits() == 2, "a prohibited WORKING-TREE edit does not contaminate a clean staged commit")
check("corruption" not in r.git("show", "HEAD:game/bad.gd").stdout, "...and what was committed is the clean staged blob")
code, out = r.scan()
check(code == 1 and "game/bad.gd:1" in out, "...while --scan independently catches the working-tree content")

r.write("game/bad.gd", CLEAN_GD)
r.write("addons/x/three_rings.gd", "pass\n")
r.git("add", "-A")
result = r.git("commit", "-q", "-m", "ip filename")
check(result.returncode != 0 and r.commits() == 2, "an IP term in a staged FILENAME blocks the commit")
r.git("rm", "-q", "--cached", "addons/x/three_rings.gd")

(r.root / "scripts" / "guard.py").unlink()  # the hook can no longer run its guard
result = r.git("commit", "-q", "-m", "guard missing")
check(result.returncode != 0 and r.commits() == 2, "if the guard cannot run, the commit is REFUSED, not waved through")
r.close()

r = Repo()
r.git("config", "--local", "core.hooksPath", "some/other/hooks")
result = r.guard("--install-hook")
check(result.returncode == 1 and b"FOREIGN" in result.stderr, "--install-hook refuses when core.hooksPath already points elsewhere")
check(r.git("config", "--local", "--get", "core.hooksPath").stdout.strip() == "some/other/hooks", "...and leaves that setting untouched")
r.close()

r = Repo()
r.write(".git/hooks/pre-commit", "#!/bin/sh\nexit 0\n")
result = r.guard("--install-hook")
check(result.returncode == 1 and b"CUSTOM" in result.stderr, "--install-hook refuses when a custom .git/hooks hook exists")
check(r.git("config", "--get", "core.hooksPath").stdout.strip() == "", "...and does not set core.hooksPath over it")
r.close()


# ---------------------------------------------------------------------------------
print("\nEDIT HOOK — PreToolUse payloads, including ones that cannot be inspected")
# ---------------------------------------------------------------------------------
r = Repo()
check(r.hook({"file_path": "game/a.gd", "content": "var corruption_level = 0"}) == 2, "a banned Write under game/ is blocked")
check(r.hook({"file_path": "tools/a.gd", "old_string": "x", "new_string": "class NaviCore"}) == 2, "a banned Edit under tools/ is blocked")
check(r.hook({"file_path": str(r.root / "tests" / "a.gd"), "content": "the dark web"}) == 2, "an absolute path inside the repo is governed too")
check(r.hook({"file_path": "game/a.gd", "content": "no navigation, no NavigationServer"}) == 0, "legitimate 'navigation' is allowed")
check(r.hook({"file_path": "game/a.tres", "content": "navigation_layers = 1"}) == 0, "a Godot resource edit is allowed")
check(r.hook({"file_path": "scripts/a.py", "content": "spiral knights"}) == 2, "an IP term is blocked outside the vocabulary scope")
check(r.hook({"file_path": "GAME-RULES.md", "content": "anything"}) == 2, "GAME-RULES.md is still protected")
check(r.hook({"file_path": str(Path(tempfile.gettempdir()) / "elsewhere.txt"), "content": "var virus"}) == 0, "a file outside the repository is not governed")
check(r.guard().returncode == 1, "empty stdin prints usage and exits non-zero")
check(r.hook(None, raw=b"{not json") == 2, "MALFORMED JSON FAILS CLOSED (blocking exit)")
check(r.hook(None, raw=b"\xff\xfe\x00junk") == 2, "undecodable bytes fail closed")
check(r.hook(None, raw=b"[]") == 2, "a payload that is not an object fails closed")
check(r.hook(None, raw=b'{"tool_input": "nope"}') == 2, "a payload with no tool_input object fails closed")
check(r.hook({"content": "hello"}) == 2, "a payload naming no file path fails closed")
check(r.guard("--bogus").returncode == 1, "an unrecognised flag is a failure, never a silent pass")
r.close()


# ---------------------------------------------------------------------------------
print("\nTHE REAL REPOSITORY — read-only: the standing false-positive regression")
# ---------------------------------------------------------------------------------
real = subprocess.run([sys.executable, str(REAL_GUARD), "--scan"], cwd=str(REAL_ROOT), capture_output=True)
check(real.returncode == 0, "--scan passes on the actual game repository")
bare = subprocess.run([sys.executable, str(REAL_GUARD)], cwd=str(REAL_ROOT), input=b"", capture_output=True)
check(bare.returncode == 1 and b"NO INPUT" in bare.stderr, "a bare run in the actual repository fails informatively")


# ---------------------------------------------------------------------------------
print("\n%d passed, %d failed" % (len(_passes), len(_failures)))
if _failures:
    for label in _failures:
        print("  FAILED: " + label)
    sys.exit(1)
sys.exit(0)
