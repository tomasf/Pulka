#!/usr/bin/env python3
"""Turn the device profiler's console output into JSON and a compact table."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path)
parser.add_argument("--json", type=Path)
args = parser.parse_args()
info, results = {}, []
raw = args.log.read_text(errors="replace")
try:
    payload = json.loads(raw)
    info, results = payload["device"], payload["results"]
except (json.JSONDecodeError, KeyError, TypeError):
    pass
for line in raw.splitlines():
    if "DEVICE_PROFILE_INFO " in line:
        info = json.loads(line.split("DEVICE_PROFILE_INFO ", 1)[1])
    if "DEVICE_PROFILE_RESULT " in line:
        results.append(json.loads(line.split("DEVICE_PROFILE_RESULT ", 1)[1]))
if args.json:
    args.json.write_text(json.dumps({"device": info, "results": results}, indent=2))
print(json.dumps(info, ensure_ascii=False))
print("| Case | Players | Frame median / p99 / max ms | >34 ms | Logic p99 | World max | GPU p99 | Mixed indoor frames |")
print("| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |")
for row in results:
    frame = row["frame"]
    gpu = f'{row["gpu"]["p99"]:.2f}' if row["gpu"]["max"] > 0 else "n/a"
    print(f'| {row["case"]} | {row["players"]} | {frame["median"]:.2f} / {frame["p99"]:.2f} / {frame["max"]:.2f} | {frame["over34"]} | {row["logic"]["p99"]:.2f} | {row["world"]["max"]:.2f} | {gpu} | {row["mixed_indoor_frames"]} |')
    target = {"cave": "ICE_CAVE", "roofs": "ROOFS", "slope": "SLOPE"}.get(row["case"].split("/")[0], row["case"].split("/")[0].upper())
    if target not in row["regions"]:
        print(f'  COVERAGE WARNING: did not reach {target}; visited {row["regions"]}')
