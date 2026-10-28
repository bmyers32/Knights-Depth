"""TARGETED MUTATION TESTING (test-harness rule, 2026-10-27).

A spec (JSON) lists mutants. Each mutant: a name, the file it edits, exact (old, new) pairs that
must each occur exactly once, the GUT test FILE and the relevant test NAMES. For each mutant the
driver edits the file, runs ONLY the relevant tests -- one Godot run per test name
(`-gselect=<file> -gunit_test_name=<name>`, both verified GUT 9 options) through
tools/godot_run.py, so process isolation and timing apply -- and restores the file in a
`finally`, then SHA-verifies the restoration and stops everything if it does not match.

VERDICTS, never blurred:
  CAUGHT        a relevant test failed by an assertion ([Failed]) and the run had no script error
  SURVIVED      every relevant test ran to completion and passed
  TIMEOUT       a run hit its timeout -- NOT a catch
  CRASH         a script/parse error, or a run that produced no GUT totals -- NOT a catch
  REFUSED       another Godot process was running, or the host was short of memory -- nothing was tested
  NOT_APPLIED   a pattern did not occur exactly once -- nothing was tested
The first CAUGHT stops that mutant's remaining runs (one assertion catch is the evidence).

usage: python -I tools/mutate.py SPEC.json [--only NAME1,NAME2] [--timeout SECONDS]
       Results: build/mutation/<spec stem>.json and one log per run beside it.
"""
import hashlib, io, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import godot_run  # noqa: E402

REPO = godot_run.REPO
_ANSI = re.compile(r"\x1b\[[0-9;]*m")


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def failed_tests(output):
    """Test names with a [Failed] line, attributed by the test header above it, before GUT's
    end-of-run summary (which repeats every failure under the LAST test's header)."""
    text = _ANSI.sub("", output).split("= Run Summary")[0]
    failed, current = [], None
    for line in text.splitlines():
        m = re.match(r"^\s*\*\s+(test_\w+)", line)
        if m:
            current = m.group(1)
        if "[Failed]" in line and current and current not in failed:
            failed.append(current)
    return failed


def run_mutant(mutant, timeout, out_dir):
    path = os.path.join(REPO, mutant["file"])
    original = open(path, "rb").read()
    before = sha(path)
    text = original.decode("utf-8")
    for old, new in mutant["pairs"]:
        if text.count(old) != 1:
            return {"verdict": "NOT_APPLIED", "detail": "pattern occurs %d times: %r" % (text.count(old), old[:60]), "runs": []}
        text = text.replace(old, new)
    runs = []
    verdict = "SURVIVED"
    try:
        with io.open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        for test_name in mutant["tests"]:
            tag = re.sub(r"\W+", "_", mutant["name"])[:40]
            log = os.path.join(out_dir, "%s__%s.log" % (tag, test_name[:60]))
            result = godot_run.run(["--headless", "-s", "addons/gut/gut_cmdln.gd", "-gselect=" + mutant["test_file"],
                                    "-gunit_test_name=" + test_name], "mutant " + mutant["name"], timeout, log)
            entry = {"test": test_name, "outcome": result["outcome"], "wall": round(result["wall"], 1), "counts": result["counts"]}
            runs.append(entry)
            if result["outcome"] in ("refused", "refused_memory"):
                verdict = "REFUSED"
                break
            if result["outcome"] == "timeout":
                verdict = "TIMEOUT"
                break
            script_error = bool(re.search(r"SCRIPT ERROR|Parse Error|Failed to load", result["output"]))
            if script_error or not result["counts"]:
                verdict = "CRASH"
                entry["detail"] = "script error" if script_error else "no GUT totals"
                break
            if result["counts"].get("tests", 0) == 0:
                verdict = "CRASH"
                entry["detail"] = "the filter selected no test"
                break
            if test_name in failed_tests(result["output"]):
                verdict = "CAUGHT"
                break
    finally:
        with open(path, "wb") as f:
            f.write(original)
    restored = sha(path) == before
    return {"verdict": verdict, "runs": runs, "restored": restored}


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    spec_path = argv[0]
    only = None
    timeout = 300
    i = 1
    while i < len(argv):
        if argv[i] == "--only":
            only = set(argv[i + 1].split(",")); i += 2
        elif argv[i] == "--timeout":
            timeout = int(argv[i + 1]); i += 2
        else:
            print("unknown option", argv[i]); return 2
    spec = json.load(open(spec_path, encoding="utf-8"))
    stem = os.path.splitext(os.path.basename(spec_path))[0]
    out_dir = os.path.join(REPO, "build", "mutation", stem)
    os.makedirs(out_dir, exist_ok=True)
    results = []
    started = time.time()
    for mutant in spec["mutants"]:
        if only and mutant["name"].split(" ")[0] not in only:
            continue
        result = run_mutant(mutant, int(mutant.get("timeout", spec.get("timeout", timeout))), out_dir)
        result["name"] = mutant["name"]
        results.append(result)
        print("%-11s %-60s %s" % (result["verdict"], mutant["name"][:60],
              ", ".join("%s:%s %.0fs" % (r["test"][:40], r["outcome"], r["wall"]) for r in result["runs"])), flush=True)
        if not result.get("restored", True):
            print("RESTORATION FAILED for %s -- stopping" % mutant["file"], flush=True)
            break
        if result["verdict"] == "REFUSED":
            print("REFUSED: a Godot process is running or memory is short -- stopping", flush=True)
            break
    caught = sum(1 for r in results if r["verdict"] == "CAUGHT")
    print("mutation %s: %d/%d caught, %.0f s total" % (stem, caught, len(results), time.time() - started))
    json.dump(results, open(os.path.join(REPO, "build", "mutation", stem + ".json"), "w"), indent=1)
    return 0 if caught == len(results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
