#!/usr/bin/env python3
"""Adversarial coverage for guard.py's approved-amendment seam.

Run:  python scripts/test_guard_amendment.py

WHY THIS FILE EXISTS. The seam it tests is the ONLY sanctioned write path to
GAME-RULES.md — the most dangerous file in the repo, since code contradicting it is a bug
by definition. BRAIN records what an untested guard costs: a shared presentation component
lost a method with 416/416 green and a clean boot, because nothing exercised the surface
that mattered. A governance mechanism nobody attacks is that lesson queued up again.

So these tests are ATTACKS, not demonstrations. Each one is a specific way the seam could
betray the approval it claims to enforce:
  1. the file drifted since the text was reviewed  -> pre-edit state must fail closed
  2. the payload is not the approved payload       -> exact old text must fail closed
  3. the write lands something else                -> post-write verification must catch it

No pytest dependency (this repo has none); stdlib only, self-contained runner.
"""
import hashlib
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import guard  # noqa: E402

CONFIRM = [guard.AMEND_CONFIRM_FLAG]

ORIGINAL = (
    "# LAW\n"
    "\n"
    "- **Channel law:** states own MOTION — nothing else.\n"
    "  second line of the block.\n"
    "- unrelated bullet that must never move.\n"
    "\n"
    "| Date | Change |\n"
    "| 2026-08-14 | prior row |\n"
)

APPROVED_OLD = "- **Channel law:** states own MOTION — nothing else.\n  second line of the block."
APPROVED_NEW = "- **Channel law:** families own PATH, states own RHYTHM — orthogonal.\n  second line of the block."
APPROVED_ANCHOR = "| 2026-08-14 | prior row |\n"
APPROVED_ROW = "| 2026-08-18 | new row |\n"

_failures: list = []
_passes: list = []


def check(condition: bool, label: str) -> None:
    (_passes if condition else _failures).append(label)
    print(("  PASS  " if condition else "  FAIL  ") + label)


class Fixture:
    """A throwaway protected law file. `guard.PROTECTED_FILES` is patched so the seam's
    own "is this a law file" gate stays exercised rather than bypassed."""

    def __init__(self, content: str = ORIGINAL):
        self._dir = tempfile.TemporaryDirectory()
        self.path = Path(self._dir.name) / "GAME-RULES.md"
        self.path.write_bytes(content.encode("utf-8"))

    @property
    def sha(self) -> str:
        return hashlib.sha256(self.path.read_bytes()).hexdigest()

    def text(self) -> str:
        return self.path.read_text(encoding="utf-8")

    def manifest(self, pre_sha: str = None, edits: list = None) -> str:
        payload = {
            "target": str(self.path),
            "approval": "test approval citation",
            "pre_sha256": pre_sha if pre_sha is not None else self.sha,
            "edits": edits if edits is not None else [
                {"kind": "replace", "old": APPROVED_OLD, "new": APPROVED_NEW},
                {"kind": "insert_after", "anchor": APPROVED_ANCHOR, "text": APPROVED_ROW},
            ],
        }
        manifest_path = Path(self._dir.name) / "manifest.json"
        manifest_path.write_text(json.dumps(payload), encoding="utf-8")
        return str(manifest_path)

    def close(self) -> None:
        self._dir.cleanup()


def run(fixture: Fixture, manifest_path: str, argv=None, writer=None) -> int:
    # PROTECTED_FILES normally holds a bare filename; the fixture's file is named
    # GAME-RULES.md precisely so no patching is needed and the real gate runs.
    return guard.apply_amendment(manifest_path, CONFIRM if argv is None else argv, writer=writer)


# ---------------------------------------------------------------------------------
print("\nBASELINE — the seam must actually work, or every refusal below is vacuous")
# ---------------------------------------------------------------------------------
f = Fixture()
code = run(f, f.manifest())
check(code == 0, "an approved amendment applies cleanly")
check(APPROVED_NEW in f.text(), "the approved replacement landed")
check(APPROVED_ROW in f.text(), "the approved row landed")
check("- unrelated bullet that must never move.\n" in f.text(), "unrelated content survived")
check(f.text().count("| 2026-08-14 | prior row |") == 1, "the anchor row was kept, not consumed")
f.close()


# ---------------------------------------------------------------------------------
print("\nATTACK 1 — non-matching pre-edit state must fail closed")
# ---------------------------------------------------------------------------------
f = Fixture()
code = run(f, f.manifest(pre_sha="0" * 64))
check(code == 2, "a wrong pre-edit hash is refused")
check(f.text() == ORIGINAL, "...and the file is untouched")
f.close()

f = Fixture()
manifest = f.manifest()                       # hash captured from the pristine file...
f.path.write_bytes((ORIGINAL + "\ndrifted since review\n").encode("utf-8"))  # ...then it drifts
code = run(f, manifest)
check(code == 2, "a file that drifted after approval is refused")
check("drifted since review" in f.text() and APPROVED_NEW not in f.text(), "...and no edit was applied")
f.close()


# ---------------------------------------------------------------------------------
print("\nATTACK 2 — text differing from the approved payload must fail closed")
# ---------------------------------------------------------------------------------
f = Fixture()
code = run(f, f.manifest(edits=[{"kind": "replace", "old": "- **Channel law:** states own MOTION - nothing else.", "new": APPROVED_NEW}]))
check(code == 2, "old text that is not verbatim (ASCII hyphen for an em dash) is refused")
check(f.text() == ORIGINAL, "...and the file is untouched")
f.close()

f = Fixture("dup\ndup\n")
code = run(f, f.manifest(edits=[{"kind": "replace", "old": "dup", "new": "x"}]))
check(code == 2, "an ambiguous payload matching twice is refused")
check(f.text() == "dup\ndup\n", "...and the file is untouched")
f.close()

f = Fixture()
code = run(f, f.manifest(edits=[{"kind": "replace", "old": "text that is simply not in the file", "new": "x"}]))
check(code == 2, "a payload matching zero times is refused")
f.close()

f = Fixture()
code = run(f, f.manifest(), argv=[])
check(code == 2, "amendment mode without the explicit approval flag is refused")
check(f.text() == ORIGINAL, "...and the file is untouched")
f.close()

f = Fixture()
bad = json.loads(Path(f.manifest()).read_text(encoding="utf-8"))
bad["approval"] = "   "
bad_path = Path(tempfile.mkdtemp()) / "m.json"
bad_path.write_text(json.dumps(bad), encoding="utf-8")
check(guard.apply_amendment(str(bad_path), CONFIRM) == 2, "a manifest with no approval citation is refused")
f.close()

f = Fixture()
non_law = json.loads(Path(f.manifest()).read_text(encoding="utf-8"))
non_law["target"] = str(Path(f.path).parent / "NOTES.md")
non_law_path = Path(tempfile.mkdtemp()) / "m.json"
non_law_path.write_text(json.dumps(non_law), encoding="utf-8")
check(guard.apply_amendment(str(non_law_path), CONFIRM) == 2, "the seam refuses any target that is not a protected law file")
f.close()

f = Fixture()
code = run(f, f.manifest(edits=[{"kind": "replace", "old": APPROVED_OLD, "new": APPROVED_OLD}]))
check(code == 2, "a no-op amendment is refused (an approval that changes nothing is a mistake)")
f.close()


# ---------------------------------------------------------------------------------
print("\nATTACK 3 — post-write verification must catch an unrelated-byte mutation")
# ---------------------------------------------------------------------------------
def saboteur_extra_byte(path, data):
    """Writes the approved bytes PLUS one unrelated line -- the shape of a 'helpful'
    reformat, a stray editor newline, or a tool that rewrites more than it was asked to."""
    Path(path).write_bytes(data + b"unrelated line snuck in\n")


f = Fixture()
code = run(f, f.manifest(), writer=saboteur_extra_byte)
check(code == 2, "an extra unrelated line written alongside the approved text is caught")
check(f.text() == ORIGINAL, "...and the damaged file is ROLLED BACK, never left half-amended")
f.close()


def saboteur_mutates_untouched_line(path, data):
    """Applies the approved edit correctly but quietly alters a line the approval never
    mentioned -- the exact failure 'no silent doc mutation under the label of cleanup' names."""
    text = data.decode("utf-8").replace(
        "- unrelated bullet that must never move.",
        "- unrelated bullet that must never move (tidied).",
    )
    Path(path).write_bytes(text.encode("utf-8"))


f = Fixture()
code = run(f, f.manifest(), writer=saboteur_mutates_untouched_line)
check(code == 2, "a mutated but approval-adjacent line is caught")
check(f.text() == ORIGINAL, "...and the file is rolled back")
f.close()


def saboteur_drops_an_edit(path, data):
    """Lands only the first approved edit. Post-verification must notice the approved
    text that is MISSING, not merely reject text that is extra."""
    text = data.decode("utf-8").replace(APPROVED_ROW, "")
    Path(path).write_bytes(text.encode("utf-8"))


f = Fixture()
code = run(f, f.manifest(), writer=saboteur_drops_an_edit)
check(code == 2, "a silently dropped approved edit is caught")
check(f.text() == ORIGINAL, "...and the file is rolled back")
f.close()


def saboteur_mangles_encoding(path, data):
    """Round-trips through cp1252-lossy replacement -- the documented Windows hazard that
    turns em dashes and section signs into mojibake while leaving the file 'looking fine'."""
    text = data.decode("utf-8").replace("—", "-").replace("§", "S")
    Path(path).write_bytes(text.encode("utf-8"))


f = Fixture()
code = run(f, f.manifest(), writer=saboteur_mangles_encoding)
check(code == 2, "non-ASCII characters degraded during the write are caught")
check(f.text() == ORIGINAL, "...and the file is rolled back")
f.close()


# ---------------------------------------------------------------------------------
print("\n%d passed, %d failed" % (len(_passes), len(_failures)))
if _failures:
    for label in _failures:
        print("  FAILED: " + label)
    sys.exit(1)
sys.exit(0)
