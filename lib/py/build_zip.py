#!/usr/bin/env python3
"""Build the Odoo Database Manager zip: dump.sql, manifest.json and filestore/.

usage: build_zip.py OUTPUT_ZIP BUILD_DIR

Prints a progress bar on stderr. Standard library only.
"""
import os, sys, time, zipfile, shutil
out, build = sys.argv[1], sys.argv[2]
tty = sys.stderr.isatty()
utf = "UTF" in (os.environ.get("LC_ALL") or os.environ.get("LANG") or "").upper()
full, empty = ("█", "░") if utf else ("#", ".")
files = [("dump.sql", os.path.join(build, "dump.sql")), ("manifest.json", os.path.join(build, "manifest.json"))]
fs = os.path.join(build, "filestore")
if os.path.isdir(fs):
    for root, _d, names in os.walk(fs):
        for n in sorted(names):
            p = os.path.join(root, n)
            files.append((os.path.relpath(p, build), p))
total = sum(os.path.getsize(p) for _a, p in files); done = 0; t0 = time.time(); last = 0
def human(n):
    for u in ("B","KB","MB","GB","TB"):
        if n < 1024 or u == "TB": return ("%d %s" % (n,u)) if u=="B" else ("%.1f %s" % (n,u))
        n /= 1024.0
def draw(final=False):
    frac = (done / total) if total else 1.0
    w = max(10, min(30, shutil.get_terminal_size((100,20)).columns - 70)); f = int(frac*w)
    line = "  %-12s %s %3d%%  %s/%s  %d files" % ("zip", full*f + empty*(w-f), int(frac*100), human(done), human(total), len(files))
    sys.stderr.write(("\r\033[K"+line+("\n" if final else "")) if tty else line+"\n"); sys.stderr.flush()
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as z:
    for arc, p in files:
        z.write(p, arc); done += os.path.getsize(p)
        if time.time() - last > (0.2 if tty else 5): draw(); last = time.time()
draw(True)
