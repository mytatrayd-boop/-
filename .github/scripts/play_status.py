#!/usr/bin/env python3
"""Show every app's Google Play tracks: releases, version codes, status and rollout.

Reads the apps from stores/apps.json (field "android"), or the package names given.
Read only: each app gets one Play "edit" that is deleted at the end (nothing changes).

Stdlib + openssl only.

  play_status.py [package ...]

Env: PLAY_SERVICE_ACCOUNT_JSON (the key JSON itself, as in GitHub Secrets)
  or PLAY_KEY_FILE (path to the key file, kept OUTSIDE the repo, e.g. ~/.secrets/play-key.json).
"""
import json
import os
import pathlib
import sys

if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON") and os.environ.get("PLAY_KEY_FILE"):
    os.environ["PLAY_SERVICE_ACCOUNT_JSON"] = pathlib.Path(os.environ["PLAY_KEY_FILE"]).expanduser().read_text()
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from play_listing import API, Play  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
STATUS_AR = {"draft": "مسودة", "inProgress": "قيد الطرح", "halted": "موقوف", "completed": "مكتمل"}


def apps() -> list:
    """[(name, package)] from the arguments, else stores/apps.json."""
    if sys.argv[1:]:
        return [(p, p) for p in sys.argv[1:]]
    return [(a["name"], a["android"]) for a in json.loads((ROOT / "stores/apps.json").read_text("utf-8"))]


def tracks(play: Play) -> list:
    play.edit_id = play.call("POST", f"{API}/{play.package}/edits", {})["id"]
    try:
        return play.call("GET", play.edit("/tracks")).get("tracks", [])
    finally:
        play.call("DELETE", play.edit())


def main():
    if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        sys.exit("Set PLAY_KEY_FILE (path to the key) or PLAY_SERVICE_ACCOUNT_JSON.")
    for name, package in apps():
        print(f"\n== {name} ({package})")
        for t in tracks(Play(package)):
            releases = t.get("releases", [])
            if not releases:
                print(f"  {t['track']}: لا إصدارات")
            for r in releases:
                fraction = r.get("userFraction")
                rollout = f"{fraction:.0%}" if fraction is not None else ("100%" if r["status"] == "completed" else "-")
                print(f"  {t['track']}: {r.get('name', '-')} | versionCode {','.join(r.get('versionCodes', [])) or '-'}"
                      f" | {r['status']} ({STATUS_AR.get(r['status'], '?')}) | الطرح {rollout}")


if __name__ == "__main__":
    main()
