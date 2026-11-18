#!/usr/bin/env python3
"""Summarize an xctrace time-profile XML export (1 ms sampled CPU weights).

Export with: xcrun xctrace export --input recording.trace --xpath
'/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' --output cpu.xml
"""
import argparse
from collections import Counter
import json
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("xml")
parser.add_argument("--json")
args = parser.parse_args()
root = ET.parse(args.xml).getroot()
ids = {node.get("id"): node for node in root.iter() if node.get("id")}


def resolve(node):
    return ids[node.get("ref")] if node.get("ref") else node


threads, own, inclusive = Counter(), Counter(), Counter()
for row in root.iter("row"):
    thread, weight, stack = row.find("thread"), row.find("weight"), row.find("tagged-backtrace")
    if thread is None or weight is None or stack is None:
        continue
    name = resolve(thread).get("fmt", "?")
    milliseconds = int(resolve(weight).text) / 1e6
    frames = [resolve(frame).get("name", "?") for frame in resolve(stack)]
    threads[name] += milliseconds
    if not frames or "Main Thread" not in name:
        continue
    own[frames[0]] += milliseconds
    for frame in set(frames):
        inclusive[frame] += milliseconds
total = sum(value for name, value in threads.items() if "Main Thread" in name)
summary = {"main_thread_sampled_ms": total, "threads_ms": dict(threads.most_common()),
           "self_ms": dict(own.most_common(40)), "inclusive_ms": dict(inclusive.most_common(100))}
if args.json:
    with open(args.json, "w") as file:
        json.dump(summary, file, indent=2)
print(f"Main thread: {total:.0f} ms sampled CPU time; inclusive rows overlap.")
for name, milliseconds in own.most_common(12):
    print(f"{milliseconds / max(total, 1):6.1%} {milliseconds:8.0f} ms  {name}")
