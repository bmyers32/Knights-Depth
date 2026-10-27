"""NO TEST MAY WAIT FOREVER (test-harness rule, 2026-10-27).

Lists every `while` loop in tests/*.gd that is not visibly bounded. A loop passes when its
condition is CLOCK-DRIVEN (it compares `tick_count` against a value the loop does not move), or
carries a BUDGET (a `_budget_*`, `guard`, `budget` or `waited` counter in the condition), or its
line carries a `# bounded: <reason>` comment saying how it ends (a counter checked in the body, a
coordinate stepped toward a fixed end). Anything else could spin until an outer timeout --
three such loops cost about an hour of runs on 2026-10-27.

usage: python -I tools/check_test_loops.py      (exit 1 when an unbounded loop is found)
"""
import os, re, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET = re.compile(r"\b(_budget_\w+|guard|budget|waited)\b")
CLOCK = re.compile(r"\btick_count\s*<=?")


def unbounded(path):
    found = []
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        m = re.match(r"^\s*while (.+):\s*(#.*)?$", line.rstrip("\n"))
        if not m:
            continue
        condition, comment = m.group(1), m.group(2) or ""
        if CLOCK.search(condition) or BUDGET.search(condition) or comment.startswith("# bounded:"):
            continue
        found.append((number, line.strip()))
    return found


def main():
    tests = os.path.join(REPO, "tests")
    total = 0
    for name in sorted(os.listdir(tests)):
        if name.endswith(".gd"):
            for number, line in unbounded(os.path.join(tests, name)):
                print("tests/%s:%d: unbounded loop: %s" % (name, number, line))
                total += 1
    print("check_test_loops: %d unbounded loop(s)" % total)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
