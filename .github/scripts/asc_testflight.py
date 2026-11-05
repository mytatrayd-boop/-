#!/usr/bin/env python3
"""Add the newest processed build(s) of an app to its internal TestFlight group.

  asc_testflight.py <bundle_id> [<group name>]

Prints the latest builds and their processing state, then adds the builds that are VALID
(processed) and not yet in the internal group. Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import api, request  # noqa: E402


def main(bundle_id: str, group_name: str | None):
    apps = api("GET", f"/apps?filter[bundleId]={bundle_id}")["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle id {bundle_id}")
    app = apps[0]
    groups = api("GET", f"/apps/{app['id']}/betaGroups?limit=200")["data"]
    print("groups:", [(g["attributes"]["name"], g["attributes"].get("isInternalGroup")) for g in groups])
    internal = [g for g in groups if g["attributes"].get("isInternalGroup") and (not group_name or g["attributes"]["name"] == group_name)]
    if not internal:
        sys.exit("::error::No matching internal group")
    group = internal[0]
    in_group = {b["id"] for b in api("GET", f"/betaGroups/{group['id']}/builds?limit=200")["data"]}
    builds = api("GET", f"/builds?filter[app]={app['id']}&sort=-uploadedDate&limit=8&include=preReleaseVersion")
    versions = {i["id"]: i["attributes"]["version"] for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
    for b in builds["data"]:
        a = b["attributes"]
        ver = versions.get(((b["relationships"].get("preReleaseVersion") or {}).get("data") or {}).get("id"), "?")
        state = a.get("processingState")
        mark = "in group" if b["id"] in in_group else "NOT in group"
        print(f"build {a['version']} (v{ver}) uploaded {a.get('uploadedDate')} state={state} expired={a.get('expired')} {mark}")
    todo = [b for b in builds["data"] if b["attributes"].get("processingState") == "VALID" and not b["attributes"].get("expired") and b["id"] not in in_group][:3]
    for b in todo:
        status, res = request("POST", f"/betaGroups/{group['id']}/relationships/builds", {"data": [{"type": "builds", "id": b["id"]}]})
        if status >= 300:
            sys.exit(f"::error::add build {b['attributes']['version']} -> {status}: {str(res)[:500]}")
        print(f"added build {b['attributes']['version']} to group '{group['attributes']['name']}'")
    if not todo:
        print("nothing to add")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
