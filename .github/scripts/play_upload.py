#!/usr/bin/env python3
"""Upload an .aab to a Google Play track (default: alpha = closed testing) with Arabic release notes.

One Play "edit": upload the bundle, set the track release, then commit. Apps under managed
review (e.g. after a policy rejection) refuse automatic sending; then the edit is kept and
the owner sends it from Play Console › Publishing overview.
With --dry-run the edit is validated and deleted instead (nothing changes in Play).

Stdlib + openssl only.

  play_upload.py <package_name> <file.aab> <notes_ar.txt> [--track=alpha] [--draft] [--dry-run]

Env: PLAY_SERVICE_ACCOUNT_JSON (the key JSON itself, as in GitHub Secrets)
  or PLAY_KEY_FILE (path to the key file, kept OUTSIDE the repo, e.g. ~/.secrets/play-key.json).
"""
import os
import pathlib
import sys

if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON") and os.environ.get("PLAY_KEY_FILE"):
    os.environ["PLAY_SERVICE_ACCOUNT_JSON"] = pathlib.Path(os.environ["PLAY_KEY_FILE"]).expanduser().read_text()
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from play_listing import API, UPLOAD, Play  # noqa: E402

NOTES_LIMIT = 500  # Play's limit per language


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = dict(a[2:].partition("=")[::2] for a in sys.argv[1:] if a.startswith("--"))
    if len(args) != 3 or set(flags) - {"track", "draft", "dry-run"}:
        sys.exit(__doc__)
    package, aab, notes_file = args[0], pathlib.Path(args[1]), pathlib.Path(args[2])
    track = flags.get("track") or "alpha"
    notes = notes_file.read_text("utf-8").strip()
    if aab.suffix != ".aab" or not aab.is_file():
        sys.exit(f"Not an .aab file: {aab}")
    if not notes or len(notes) > NOTES_LIMIT:
        sys.exit(f"{notes_file}: {len(notes)} characters (1..{NOTES_LIMIT})")
    if not os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        sys.exit("Set PLAY_KEY_FILE (path to the key) or PLAY_SERVICE_ACCOUNT_JSON.")

    play = Play(package)
    play.edit_id = play.call("POST", f"{API}/{package}/edits", {})["id"]
    print(f"{package}: uploading {aab.name} ({aab.stat().st_size // 1024} KB)…")
    bundle = play.call("POST", f"{UPLOAD}/{package}/edits/{play.edit_id}/bundles?uploadType=media",
                       data=aab.read_bytes(), content_type="application/octet-stream")
    code = str(bundle["versionCode"])
    status = "draft" if "draft" in flags else "completed"
    play.call("PUT", play.edit(f"/tracks/{track}"), {"track": track, "releases": [{
        "versionCodes": [code], "status": status,
        "releaseNotes": [{"language": "ar", "text": notes}]}]})
    print(f"track {track}: versionCode {code}, status {status}, Arabic notes {len(notes)} characters")
    if "dry-run" in flags:
        play.finish(":validate")
        play.call("DELETE", play.edit())
        print("Dry run: valid; the edit was deleted (nothing changed in Play).")
    else:
        play.finish(":commit")
        print("Committed.")


if __name__ == "__main__":
    main()
