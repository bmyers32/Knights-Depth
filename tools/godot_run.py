"""ONE GODOT AT A TIME, TIMED, AND NEVER LEFT RUNNING (test-harness rule, 2026-10-27).

Every automated Godot invocation -- tests, sweeps, mutation runs, boot checks -- goes through
run(). It:
  * REFUSES to start while any Godot process exists (the owner's editor, a playtest, a stray
    headless run) and names what it found. It never terminates a process it did not launch.
  * launches the command, enforces a wall-clock timeout, and on timeout or failure kills the
    whole process tree it launched (the console exe spawns a child);
  * checks afterwards that nothing it launched is still alive;
  * appends one row per run to build/test_timing.csv: when, label, wall seconds, exit code,
    outcome (ok / failed / timeout / refused / refused_memory), GUT test counts when the output
    has them.
  * REFUSES to start when the host has less than MIN_FREE_MB of physical memory free
    (2026-10-28: an S4 tier-3 run was killed by the host for memory while Godot itself held a
    flat ~100 MB -- the pressure came from other processes, so the guard is on the host, not Godot).
  * keeps build/.gdignore in place: without it `--import` scans build/ and imports
    test_timing.csv as a translation table.

A TIMEOUT IS ITS OWN OUTCOME, and so is a memory refusal. Neither is ever a pass, and a mutation
driver must not read either as a caught mutant.

CLI:  python -I tools/godot_run.py --label NAME [--timeout SECONDS] [--log FILE] -- <godot args...>
      (the Godot executable is supplied here; pass only its arguments)
"""
import csv, ctypes, os, re, subprocess, sys, time

GODOT = r"C:\Godot\Godot_v4.7-stable_win64_console.exe"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMING_CSV = os.path.join(REPO, "build", "test_timing.csv")
EXIT_REFUSED = 90
EXIT_TIMEOUT = 91
EXIT_REFUSED_MEMORY = 92
MIN_FREE_MB = 1500


class _MemoryStatus(ctypes.Structure):
    _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong), ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong), ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong), ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]


def free_memory_mb():
    status = _MemoryStatus()
    status.dwLength = ctypes.sizeof(_MemoryStatus)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status))
    return int(status.ullAvailPhys // (1024 * 1024))


def _ensure_gdignore():
    path = os.path.join(REPO, "build", ".gdignore")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").close()
_ANSI = re.compile(r"\x1b\[[0-9;]*m")


def godot_processes(with_titles=False):
    """[(pid, image, window title)] for every running process whose image name starts with Godot.
    Detection uses the FILTERED plain listing (0.3 s); `tasklist /V` measured 45 s a call even when
    filtered (2026-10-27), so window titles are fetched only when asked for -- when refusing."""
    out = subprocess.run(["tasklist", "/FO", "CSV", "/NH", "/FI", "IMAGENAME eq Godot*"], capture_output=True, text=True, errors="replace").stdout
    found = []
    for row in csv.reader(out.splitlines()):
        if len(row) >= 2 and row[0].lower().startswith("godot"):
            found.append((int(row[1]), row[0], ""))
    if with_titles and found:
        titled = []
        for pid, image, _ in found:
            title = subprocess.run(["powershell", "-NoProfile", "-Command", "(Get-Process -Id %d -ErrorAction SilentlyContinue).MainWindowTitle" % pid],
                                   capture_output=True, text=True, errors="replace").stdout.strip()
            titled.append((pid, image, title))
        found = titled
    return found


def _kill_tree(pid):
    subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)


def gut_counts(text):
    text = _ANSI.sub("", text)
    counts = {}
    for key, name in (("tests", "Tests"), ("passing", "Passing Tests"), ("failing", "Failing Tests"), ("risky", "Risky")):
        m = re.search(r"^%s\s+(\d+)" % re.escape(name), text, re.M)
        if m:
            counts[key] = int(m.group(1))
    return counts


def _record(label, wall, code, outcome, counts, args):
    os.makedirs(os.path.dirname(TIMING_CSV), exist_ok=True)
    new = not os.path.exists(TIMING_CSV)
    with open(TIMING_CSV, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["started", "label", "wall_s", "exit", "outcome", "tests", "passing", "failing", "risky", "args"])
        w.writerow([time.strftime("%Y-%m-%d %H:%M:%S"), label, "%.1f" % wall, code, outcome,
                    counts.get("tests", ""), counts.get("passing", ""), counts.get("failing", ""), counts.get("risky", ""), " ".join(args)])


def run(args, label, timeout=600, log_path=None):
    """Runs Godot with `args`. Returns {outcome, exit, wall, output, counts}."""
    running = godot_processes(with_titles=True)
    if running:
        names = "; ".join("%s pid %d '%s'" % (image, pid, title) for pid, image, title in running)
        _record(label, 0.0, EXIT_REFUSED, "refused", {}, args)
        return {"outcome": "refused", "exit": EXIT_REFUSED, "wall": 0.0, "output": "REFUSED: Godot already running: " + names, "counts": {}}
    free = free_memory_mb()
    if free < MIN_FREE_MB:
        _record(label, 0.0, EXIT_REFUSED_MEMORY, "refused_memory", {}, args)
        return {"outcome": "refused_memory", "exit": EXIT_REFUSED_MEMORY, "wall": 0.0,
                "output": "REFUSED: host has %d MB physical memory free, below %d MB" % (free, MIN_FREE_MB), "counts": {}}
    _ensure_gdignore()
    started = time.time()
    proc = subprocess.Popen([GODOT] + list(args), cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace")
    outcome = "ok"
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        _kill_tree(proc.pid)
        output, _ = proc.communicate()
        outcome = "timeout"
    wall = time.time() - started
    code = EXIT_TIMEOUT if outcome == "timeout" else proc.returncode
    if outcome == "ok" and code != 0:
        outcome = "failed"
    # Anything still alive now was launched by this run (none existed before it): clean it up.
    for pid, image, title in godot_processes():
        _kill_tree(pid)
        output += "\n[godot_run] killed leftover %s pid %d" % (image, pid)
    counts = gut_counts(output)
    if log_path:
        with open(log_path, "w", encoding="utf-8") as f:
            f.write(output)
    _record(label, wall, code, outcome, counts, args)
    return {"outcome": outcome, "exit": code, "wall": wall, "output": output, "counts": counts}


def main(argv):
    label, timeout, log_path = "godot", 600, None
    if "--" not in argv:
        print(__doc__)
        return 2
    split = argv.index("--")
    opts, godot_args = argv[:split], argv[split + 1:]
    i = 0
    while i < len(opts):
        if opts[i] == "--label":
            label = opts[i + 1]; i += 2
        elif opts[i] == "--timeout":
            timeout = int(opts[i + 1]); i += 2
        elif opts[i] == "--log":
            log_path = opts[i + 1]; i += 2
        else:
            print("unknown option", opts[i]); return 2
    result = run(godot_args, label, timeout, log_path)
    if result["outcome"] in ("refused", "refused_memory"):
        print(result["output"])
    else:
        tail = _ANSI.sub("", result["output"]).strip().splitlines()[-12:]
        print("\n".join(tail))
    counts = result["counts"]
    print("[godot_run] %s: %s, exit %s, %.1f s%s" % (label, result["outcome"], result["exit"], result["wall"],
          ", tests %s passing %s failing %s" % (counts.get("tests", "-"), counts.get("passing", "-"), counts.get("failing", "-")) if counts else ""))
    return 0 if result["outcome"] == "ok" else (result["exit"] or 1)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
