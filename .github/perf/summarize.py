"""Summarise an `xctrace export` of a Time Profiler table.

Usage: summarize.py time-profile.xml [window_start_s window_end_s]

Prints CPU time per process, per thread of the Decode app, the main
thread's busiest functions (self and inclusive), and the main thread's
busy milliseconds per 100 ms across the window.
"""
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

path = sys.argv[1]
w0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
w1 = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9

cache = {}  # id -> parsed value


def resolve(el):
    """Parsed value for an element that is either a definition or a ref."""
    ref = el.get("ref")
    if ref is not None:
        return cache.get(ref)
    tag = el.tag
    if tag == "backtrace":
        frames = []
        for f in el:
            if f.tag == "frame":
                frames.append(resolve(f))
        val = frames
    elif tag == "frame":
        val = el.get("name") or el.get("addr") or "?"
    elif tag == "thread":
        proc = None
        for c in el:
            if c.tag == "process":
                proc = resolve(c)
        val = (el.get("fmt") or "?", proc or "?")
    elif tag == "process":
        val = el.get("fmt") or "?"
    elif tag in ("weight", "sample-time"):
        try:
            val = int(el.text or 0)
        except ValueError:
            val = 0
    else:
        val = el.get("fmt") or (el.text or "")
    i = el.get("id")
    if i is not None:
        cache[i] = val
    return val


per_process = Counter()
per_thread = Counter()
main_self = Counter()
main_incl = Counter()
main_buckets = defaultdict(int)
app_buckets = defaultdict(int)
render_buckets = defaultdict(int)
render_self = Counter()
n = 0

for event, el in ET.iterparse(path, events=("end",)):
    if el.tag != "row":
        continue
    t = weight = 0
    thread = ("?", "?")
    bt = []
    state = ""
    for c in el:
        if c.tag == "sample-time":
            t = resolve(c)
        elif c.tag == "weight":
            weight = resolve(c)
        elif c.tag == "thread":
            thread = resolve(c) or thread
        elif c.tag == "backtrace":
            bt = resolve(c) or []
        elif c.tag == "thread-state":
            state = resolve(c)
        else:
            resolve(c)
    el.clear()
    ts = (t or 0) / 1e9
    if ts < w0 or ts > w1:
        continue
    n += 1
    ms = (weight or 1_000_000) / 1e6
    tname, pname = thread
    per_process[pname] += ms
    bucket = int((ts - w0) * 10)
    if "Decode" in pname:
        per_thread[tname] += ms
        app_buckets[bucket] += ms
        if "Main Thread" in tname or "main" in tname.lower():
            main_buckets[bucket] += ms
            if bt:
                main_self[bt[0]] += ms
                for fn in set(bt):
                    main_incl[fn] += ms
    if "backboardd" in pname:
        render_buckets[bucket] += ms
        if bt:
            render_self[bt[0]] += ms

span = min(w1, max(1.0, w1)) - w0
print(f"samples in window: {n}")
print("\n== CPU ms per process (top 12)")
for p, v in per_process.most_common(12):
    print(f"{v:9.0f}  {p}")
print("\n== Decode threads (top 10)")
for p, v in per_thread.most_common(10):
    print(f"{v:9.0f}  {p}")
print("\n== Decode main thread: self time (top 40)")
for p, v in main_self.most_common(40):
    print(f"{v:9.1f}  {p[:160]}")
print("\n== Decode main thread: inclusive (top 60)")
for p, v in main_incl.most_common(60):
    print(f"{v:9.1f}  {p[:160]}")
print("\n== backboardd self time (top 25)")
for p, v in render_self.most_common(25):
    print(f"{v:9.1f}  {p[:160]}")
print("\n== busy ms per 100 ms: main thread | whole app | backboardd")
last = max(list(main_buckets) + list(app_buckets) + list(render_buckets) + [0])
for b in range(last + 1):
    print(f"{w0 + b / 10:6.1f}s  {main_buckets.get(b, 0):5.0f} {app_buckets.get(b, 0):6.0f} {render_buckets.get(b, 0):6.0f}")
