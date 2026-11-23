#!/usr/bin/env python3
"""Promote the release on one Play track to another (default alpha -> production) without rebuilding.

The same versionCode that was tested is put on the target track with its Arabic release notes.
Before anything changes the target track's country availability is read: the promotion is refused
if the production track would be offered to the EU or to the rest of the world (owner's decision:
no EU). Default is a dry run; pass --apply to commit.

  play_promote.py <package_name> [--from=alpha] [--to=production] [--apply]

Env: PLAY_SERVICE_ACCOUNT_JSON (the key JSON itself) or PLAY_KEY_FILE.
"""
import os
import pathlib
import sys

if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON") and os.environ.get("PLAY_KEY_FILE"):
    os.environ["PLAY_SERVICE_ACCOUNT_JSON"] = pathlib.Path(os.environ["PLAY_KEY_FILE"]).expanduser().read_text()
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from play_listing import API, Play  # noqa: E402

EU = set("AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split())


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = dict(a[2:].partition("=")[::2] for a in sys.argv[1:] if a.startswith("--"))
    if len(args) != 1 or set(flags) - {"from", "to", "apply"}:
        sys.exit(__doc__)
    package, src, dst = args[0], flags.get("from") or "alpha", flags.get("to") or "production"
    if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        sys.exit("Set PLAY_KEY_FILE (path to the key) or PLAY_SERVICE_ACCOUNT_JSON.")

    play = Play(package)
    play.edit_id = play.call("POST", f"{API}/{package}/edits", {})["id"]
    committed = False
    try:
        rel = [r for r in play.call("GET", play.edit(f"/tracks/{src}")).get("releases", [])
               if r.get("status") == "completed" and r.get("versionCodes")]
        if not rel:
            sys.exit(f"::error::{src} has no completed release to promote")
        rel = rel[0]
        print(f"{package}: {src} -> {dst}: {rel.get('name', '-')} versionCode {','.join(rel['versionCodes'])}")

        # Country availability of the target track: must not include the EU or the rest of the world.
        try:
            av = play.call("GET", play.edit(f"/countryAvailability/{dst}")) or {}
        except SystemExit as e:
            sys.exit(f"::error::cannot read {dst} countries ({e}); set them in Play Console first")
        if not av:
            sys.exit(f"::error::refused: Play returned no country settings for {dst} yet. Open Production > "
                     "Countries/regions in Play Console and choose the countries (Saudi Arabia, India; no EU), "
                     "then rerun.")
        codes = {c["countryCode"] for c in av.get("countries", [])}
        print(f"{dst} countries: {', '.join(sorted(codes)) or '-'}; rest of world: {av.get('restOfWorld')}; "
              f"sync with Play: {av.get('syncWithPlay')}")
        if av.get("restOfWorld") or av.get("syncWithPlay") or codes & EU or not codes:
            sys.exit(f"::error::refused: {dst} is not limited to the intended countries "
                     f"(EU in set: {sorted(codes & EU)}). Fix Production > Countries/regions in Play Console, then rerun.")

        body = {"track": dst, "releases": [{
            "versionCodes": rel["versionCodes"], "status": "completed",
            "releaseNotes": rel.get("releaseNotes", [])}]}
        play.call("PUT", play.edit(f"/tracks/{dst}"), body)
        if "apply" in flags:
            play.finish(":commit")
            committed = True
            print("Committed: the release is now on", dst)
        else:
            play.finish(":validate")
            print("Dry run: valid; nothing changed (pass --apply to commit).")
    finally:
        if not committed:
            play.call("DELETE", play.edit())


if __name__ == "__main__":
    main()
