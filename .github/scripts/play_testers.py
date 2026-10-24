#!/usr/bin/env python3
"""Add a Google Group as testers of a Google Play testing track.

Reads the track's current Google Groups and adds the given one, so groups already there
stay. Email lists made in Play Console are separate and are not touched. --dry-run shows
the change and discards the edit.

  play_testers.py <package_name> <track> <group@googlegroups.com> [--dry-run]

Env: PLAY_SERVICE_ACCOUNT_JSON (as play_listing.py).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from play_listing import API, Play  # noqa: E402


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 3 or flags - {"--dry-run"} or "@" not in args[2]:
        sys.exit(__doc__)
    package, track, group = args
    play = Play(package)
    play.edit_id = play.call("POST", f"{API}/{package}/edits", {})["id"]
    try:
        current = play.call("GET", play.edit(f"/testers/{track}")) or {}
    except SystemExit:  # a track with no testers yet
        print("::notice::No testers on this track yet")
        current = {}
    groups = current.get("googleGroups", [])
    print(f"{package} {track}: groups now {groups or 'none'}")
    if group in groups:
        print("Already a tester group; nothing to change.")
        play.call("DELETE", play.edit())
        return
    play.call("PUT", play.edit(f"/testers/{track}"), {"googleGroups": groups + [group]})
    if "--dry-run" in flags:
        play.call("POST", play.edit(":validate"))
        play.call("DELETE", play.edit())
        print(f"Dry run: would add {group}; nothing changed.")
    else:
        play.call("POST", play.edit(":commit"))
        print(f"Added {group} as testers of {track}.")


if __name__ == "__main__":
    main()
