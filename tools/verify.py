"""VERIFICATION TIERS (test-harness rule, 2026-10-27). Every Godot step goes through
tools/godot_run.py: one process at a time, refused while any Godot is open, timed, logged to
build/test_timing.csv. Steps run in order and the run STOPS at the first refusal.

  Tier 1  development   loop lint; the named test files (and test names, if given); a 20-seed
                        sweep of each named recipe with integrity and metrics OFF (reported
                        NOT_EVALUATED). Minutes.
  Tier 2  integration   loop lint; the named test files; a 40-seed sweep of each named recipe with
                        FAST integrity (the voluntary set-down not modelled) and metrics on; guard.
  Tier 3  certification loop lint; the FULL suite; a 200-seed sweep of each named recipe with FULL
                        integrity and metrics; the named mutation specs; 300-frame boots of the main
                        scene and of each named recipe on seeds 1, 7, 42; guard.

Coverage is never reduced silently: Tier 3 has no reduced options, and the reduced sweeps of
Tiers 1-2 say so in their own output. Recipes are named explicitly: an UNCHANGED recipe is not
re-swept merely because another one was edited.

usage: python -I tools/verify.py --tier 1|2|3 [--files a.gd,b.gd] [--tests name1,name2]
                                 [--recipes r1,r2] [--mutation spec1.json,spec2.json]
"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import godot_run  # noqa: E402

REPO = godot_run.REPO
GUT = ["--headless", "-s", "addons/gut/gut_cmdln.gd"]


def _python(label, args):
    started = time.time()
    proc = subprocess.run([sys.executable, "-I"] + args, cwd=REPO, capture_output=True, text=True, errors="replace")
    wall = time.time() - started
    outcome = "ok" if proc.returncode == 0 else "failed"
    tail = (proc.stdout + proc.stderr).strip().splitlines()[-1:] or [""]
    return {"label": label, "outcome": outcome, "wall": wall, "note": tail[0]}


def _godot(label, args, timeout):
    result = godot_run.run(args, label, timeout, os.path.join(REPO, "build", "verify_%s.log" % label.replace(" ", "_").replace("/", "_")))
    counts = result["counts"]
    note = "tests %s passing %s failing %s" % (counts.get("tests", "-"), counts.get("passing", "-"), counts.get("failing", "-")) if counts else ""
    if result["outcome"] == "ok" and counts and counts.get("failing"):
        result["outcome"] = "failed"
    return {"label": label, "outcome": result["outcome"], "wall": result["wall"], "note": note}


def main(argv):
    opts = {"--tier": "1", "--files": "", "--tests": "", "--recipes": "", "--mutation": ""}
    i = 0
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = argv[i + 1]; i += 2
        else:
            print(__doc__); return 2
    tier = int(opts["--tier"])
    files = [f for f in opts["--files"].split(",") if f]
    tests = [t for t in opts["--tests"].split(",") if t]
    recipes = [r for r in opts["--recipes"].split(",") if r]
    specs = [m for m in opts["--mutation"].split(",") if m]
    steps = [("loop lint", lambda: _python("loop lint", ["tools/check_test_loops.py"]))]
    if tier in (1, 2):
        for f in files:
            if tests and tier == 1:
                for t in tests:
                    steps.append(("tests %s:%s" % (f, t), lambda f=f, t=t: _godot("t%d %s %s" % (tier, f, t), GUT + ["-gselect=" + f, "-gunit_test_name=" + t], 300)))
            else:
                steps.append(("tests " + f, lambda f=f: _godot("t%d %s" % (tier, f), GUT + ["-gselect=" + f], 600)))
        for r in recipes:
            seeds, integrity, metrics = ("20", "off", "off") if tier == 1 else ("40", "fast", "on")
            steps.append(("sweep " + r, lambda r=r, s=seeds, g=integrity, m=metrics: _godot("t%d sweep %s" % (tier, r),
                ["--headless", "-s", "tools/compose_floor_sweep.gd", "--", "--seeds=" + s, "--depth=1", "--recipe=" + r, "--integrity=" + g, "--metrics=" + m], 900)))
    if tier == 3:
        steps.append(("full suite", lambda: _godot("t3 full suite", GUT, 1200)))
        for r in recipes:
            steps.append(("sweep " + r, lambda r=r: _godot("t3 sweep %s" % r,
                ["--headless", "-s", "tools/compose_floor_sweep.gd", "--", "--seeds=200", "--depth=1", "--recipe=" + r, "--integrity=full", "--metrics=on"], 1800)))
        for spec in specs:
            steps.append(("mutation " + spec, lambda spec=spec: _python("mutation " + spec, ["tools/mutate.py", spec])))
        steps.append(("boot main", lambda: _godot("t3 boot main", ["--headless", "--path", ".", "--quit-after", "300"], 180)))
        for r in recipes:
            for s in ("1", "7", "42"):
                steps.append(("boot %s %s" % (r, s), lambda r=r, s=s: _godot("t3 boot %s %s" % (r, s),
                    ["--headless", "--path", ".", "tools/composed_floor_playground.tscn", "--quit-after", "300", "--", "--seed=" + s, "--recipe=" + r], 180)))
    if tier >= 2:
        steps.append(("guard", lambda: _python("guard", ["scripts/guard.py", "--scan"])))
    started = time.time()
    results = []
    for name, step in steps:
        r = step()
        results.append(r)
        print("%-9s %7.1f s  %-55s %s" % (r["outcome"].upper(), r["wall"], name[:55], r["note"]), flush=True)
        if r["outcome"] == "refused":
            print("STOPPED: a Godot process is open (the owner's editor or game?) -- nothing further was run")
            break
        if r["outcome"] == "refused_memory":
            print("STOPPED: the host is short of physical memory (close the browser?) -- nothing further was run")
            break
    bad = [r for r in results if r["outcome"] != "ok"]
    print("tier %d: %d step(s), %d not ok, %.1f s total" % (tier, len(results), len(bad), time.time() - started))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
