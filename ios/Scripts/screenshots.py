#!/usr/bin/env python3
"""Capture DEBUG states in both appearances. Install the current Debug app first."""
import argparse
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("device", help="Simulator UDID; explicitly targets one of multiple booted devices")
parser.add_argument("--appearance", choices=["light", "dark", "both"], default="both")
parser.add_argument("--state", help="Capture just one DebugUIState while keeping its sequence number")
parser.add_argument("--friend-name", default="たかし", help="Recipient name for the referSheet capture; pass an empty string to check the person icon")
args = parser.parse_args()
destination = Path(__file__).resolve().parents[2] / "shots-v3-ios"
destination.mkdir(exist_ok=True)
states = [
    ("role", "role"), ("referEmpty", "refer_empty"), ("referList", "refer_list"),
    ("referSheet", "refer_sheet"), ("historySent", "history_sent"),
    ("historyConsulting", "history_consulting"), ("historyHired", "history_hired"),
    ("historyElsewhere", "history_elsewhere"), ("historyDeclined", "history_declined"),
    ("celebration", "celebration"), ("supportCard", "support"), ("cardEdit", "edit"),
    ("distributeSheet", "distribute"), ("consultBy", "consult_by"),
    ("consult", "consult"), ("addConfirm", "add_confirm"), ("brokenLink", "broken_link"),
    ("supportEmpty", "support_empty"),
]

# xcrunが返すAppleのラッパーがこの環境では毎回約17秒待つため、
# 同じラッパーがexecするCoreSimulator本体をキャッシュして呼ぶ。
# 処理はsimctl io screenshotそのもの（画像の加工はしない）。
simctl_path = subprocess.check_output(["xcrun", "--find", "simctl"], text=True).strip()
core_simctl = Path("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl")
if core_simctl.exists():
    simctl_path = str(core_simctl)

def sim(*arguments):
    subprocess.run([simctl_path, *arguments], check=True)

container = Path(subprocess.check_output([simctl_path, "get_app_container", args.device,
    "com.ryoseiworld.tsunagu", "data"], text=True).strip())

appearances = ["light", "dark"] if args.appearance == "both" else [args.appearance]
for appearance in appearances:
    sim("ui", args.device, "appearance", appearance)
    sim("status_bar", args.device, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100")
    for index, (state, name) in enumerate(states, 1):
        if args.state and state != args.state:
            continue
        launched_at = time.time()
        sim("launch", "--terminate-running-process", args.device, "com.ryoseiworld.tsunagu",
            "-uiState", state, "-friendName", args.friend_name,
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP")
        if state == "celebration":
            # 起動速度に依存せず、DEBUGの状態変更直後（紙吹雪の途中）を撮る。
            preview = container / "tmp" / "tsunagu-preview.json"
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                try:
                    data = json.loads(preview.read_text())
                    if preview.stat().st_mtime >= launched_at and data["referrals"][0]["status"] == "決まった！":
                        break
                except (OSError, ValueError, KeyError, IndexError):
                    pass
                time.sleep(0.05)
            else:
                raise RuntimeError("Celebration state did not become ready")
            time.sleep(0.3)
        else:
            time.sleep(5 if state in ("referSheet", "distributeSheet") else 3.0)
        output = destination / f"{'L' if appearance == 'light' else 'D'}{index:02d}_{name}.png"
        sim("io", args.device, "screenshot", str(output))
        print(f"Captured {output.name}", flush=True)
sim("status_bar", args.device, "clear")
