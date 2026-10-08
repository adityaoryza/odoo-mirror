#!/usr/bin/env python3
"""Progress filter: copies stdin to stdout and draws a progress bar on stderr.

usage: progress.py LABEL TOTAL_BYTES      (TOTAL_BYTES = 0 when unknown)

Replaces `pv` so that the tool has no dependency beyond the standard library.
"""
import os, sys, time, shutil
label, total = sys.argv[1], int(sys.argv[2])
tty = sys.stderr.isatty()
utf = "UTF" in (os.environ.get("LC_ALL") or os.environ.get("LANG") or "").upper()
full, empty = ("█", "░") if utf else ("#", ".")
def human(n):
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or u == "TB":
            return ("%d %s" % (n, u)) if u == "B" else ("%.1f %s" % (n, u))
        n /= 1024.0
def dur(s):
    s = int(s)
    return "%02d:%02d" % (s // 60, s % 60) if s < 3600 else "%d:%02d:%02d" % (s // 3600, s % 3600 // 60, s % 60)
t0 = time.time(); last = 0.0; done = 0
def draw(final=False):
    el = max(time.time() - t0, 1e-6); rate = done / el
    if total > 0:
        frac = min(done / total, 1.0)
        width = max(10, min(30, shutil.get_terminal_size((100, 20)).columns - 78))
        filled = int(frac * width)
        bar = full * filled + empty * (width - filled)
        eta = dur((total - done) / rate) if rate > 0 and done < total else "--:--"
        line = "  %-12s %s %3d%%  %s/%s  %s/s  ETA %s" % (label, bar, int(frac * 100), human(done), human(total), human(rate), eta)
    else:
        line = "  %-12s %s  %s/s  %s" % (label, human(done), human(rate), dur(el))
    if tty:
        sys.stderr.write("\r\033[K" + line + ("\n" if final else ""))
    else:
        sys.stderr.write(line + "\n")
    sys.stderr.flush()
try:
    while True:
        chunk = os.read(0, 1 << 20)
        if not chunk:
            break
        mv = memoryview(chunk)
        while mv:
            n = os.write(1, mv); mv = mv[n:]
        done += len(chunk)
        now = time.time()
        if now - last >= (0.2 if tty else 5.0):
            draw(); last = now
    draw(True)
except BrokenPipeError:
    sys.exit(0)
