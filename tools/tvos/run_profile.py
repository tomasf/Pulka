#!/usr/bin/env python3
"""Run a silent physical-device profile, save complete data and stop the app."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--device", default="Apple TV Köket")
parser.add_argument("--config", default="{}", help="PULKA_PROFILE_ARGS JSON")
parser.add_argument("--label", default="profile")
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--timeout", type=float, default=2400)
args = parser.parse_args()
config = json.loads(args.config)
bundle = "se.tomasf.pulka"
label = args.label + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
env = {"PULKA_DEVICE_PROFILE": "1", "PULKA_PROFILE_ARGS": json.dumps(config),
       "PULKA_PROFILE_BUILD": label, "MTL_DEBUG_LAYER": "0", "METAL_DEVICE_WRAPPER_TYPE": "0"}


def device(*command):
    return subprocess.run(["xcrun", "devicectl", "device", *command, "--device", args.device],
                          check=True, capture_output=True, text=True, timeout=45)


args.output.parent.mkdir(parents=True, exist_ok=True)
pid = None
try:
    with tempfile.TemporaryDirectory(prefix="pulka-profile-") as directory:
        launch = Path(directory) / "launch.json"
        # The bundle must follow device options for launch's trailing arguments.
        subprocess.run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.device,
                        "--terminate-existing", "--environment-variables", json.dumps(env),
                        "--json-output", str(launch), bundle], check=True, capture_output=True, text=True, timeout=45)
        pid = json.loads(launch.read_text())["result"]["process"]["processIdentifier"]
        print(f"{args.label}: started on {args.device}, muted", flush=True)
        until, previous = time.monotonic() + args.timeout, 0
        snapshot = Path(directory) / "result.json"
        while time.monotonic() < until:
            time.sleep(12)
            snapshot.unlink(missing_ok=True)
            device("copy", "from", "--domain-type", "appDataContainer", "--domain-identifier", bundle,
                   "--source", "Library/Caches/pulka_device_profile.json", "--destination", str(snapshot))
            try:
                result = json.loads(snapshot.read_text())
            except json.JSONDecodeError:
                continue
            # A prior run's file can still exist while the new app starts.
            if result["device"].get("build") != label:
                continue
            assert result["device"]["muted"], "Device profiling must stay silent"
            result["run_config"] = config
            args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
            for row in result["results"][previous:]:
                seconds = float(config.get("seconds", 20))
                fps = min(result["device"]["refresh_hz"], row["frame"]["n"] / seconds)
                print(f'{row["case"]} / {row["players"]}P: {fps:.1f} FPS, '
                      f'p99 {row["frame"]["p99"]:.2f}, max {row["frame"]["max"]:.2f} ms, '
                      f'>34 ms: {row["frame"]["over34"]}', flush=True)
            previous = len(result["results"])
            if result["complete"]:
                print(f"Complete: {previous} cases -> {args.output}", flush=True)
                break
        else:
            raise TimeoutError("Device profile did not finish before the timeout")
finally:
    if pid is not None:
        device("process", "terminate", "--pid", str(pid))
        print("Stopped Pulka on the device", flush=True)
