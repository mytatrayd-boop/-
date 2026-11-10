#!/usr/bin/env python3
"""Add the newest processed build(s) of an app to its internal TestFlight group.

  asc_testflight.py <bundle_id> [<group name>] [--auto] [--tester EMAIL]

Prints the latest builds and their processing state, then adds the builds that are VALID
(processed) and not yet in the internal group. With --auto the group also gets every future build
automatically (hasAccessToAllBuilds). With --tester the email is added to the group (Apple emails the
invitation); the internal group «داخلي» is created first if the app has none. Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import api, request  # noqa: E402


def add_tester(group: dict, email: str):
    found = api("GET", f"/betaTesters?filter[email]={email}&limit=5")["data"]
    if found:
        status, res = request("POST", f"/betaGroups/{group['id']}/relationships/betaTesters",
                              {"data": [{"type": "betaTesters", "id": found[0]["id"]}]})
    else:
        status, res = request("POST", "/betaTesters", {"data": {
            "type": "betaTesters", "attributes": {"email": email},
            "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group["id"]}]}}}})
    if status >= 300:
        sys.exit(f"::error::add tester -> {status}: {str(res)[:800]}")
    print(f"tester added to group '{group['attributes']['name']}' (invitation sent by Apple)")


def main(bundle_id: str, group_name: str | None, auto: bool = False, tester: str | None = None):
    apps = api("GET", f"/apps?filter[bundleId]={bundle_id}")["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle id {bundle_id}")
    app = apps[0]
    groups = api("GET", f"/apps/{app['id']}/betaGroups?limit=200")["data"]
    print("groups:", [(g["attributes"]["name"], g["attributes"].get("isInternalGroup")) for g in groups])
    internal = [g for g in groups if g["attributes"].get("isInternalGroup") and (not group_name or g["attributes"]["name"] == group_name)]
    if not internal and tester:
        status, res = request("POST", "/betaGroups", {"data": {
            "type": "betaGroups", "attributes": {"name": group_name or "داخلي", "isInternalGroup": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})
        if status >= 300:
            sys.exit(f"::error::create internal group -> {status}: {str(res)[:800]}")
        internal = [res["data"]]
        print(f"created internal group '{res['data']['attributes']['name']}'")
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
    # مجموعة بتوزيع تلقائي (hasAccessToAllBuilds) تأخذ كل نسخة وحدها، ولا تقبل إضافة يدوية.
    todo = [] if group["attributes"].get("hasAccessToAllBuilds") else [
        b for b in builds["data"] if b["attributes"].get("processingState") == "VALID"
        and not b["attributes"].get("expired") and b["id"] not in in_group][:3]
    if group["attributes"].get("hasAccessToAllBuilds"):
        print(f"group '{group['attributes']['name']}' has automatic distribution: every build is in it")
    for b in todo:
        status, res = request("POST", f"/betaGroups/{group['id']}/relationships/builds", {"data": [{"type": "builds", "id": b["id"]}]})
        if status >= 300:
            print(f"::warning::add build {b['attributes']['version']} -> {status}: {str(res)[:500]}")
            continue
        print(f"added build {b['attributes']['version']} to group '{group['attributes']['name']}'")
    if not todo:
        print("nothing to add")
    if tester:
        add_tester(group, tester)
    if auto:
        status, res = request("PATCH", f"/betaGroups/{group['id']}", {"data": {
            "type": "betaGroups", "id": group["id"], "attributes": {"hasAccessToAllBuilds": True}}})
        if status >= 300:
            sys.exit(f"::error::enable automatic distribution -> {status}: {str(res)[:500]}")
        print(f"automatic distribution is ON for group '{group['attributes']['name']}'")


if __name__ == "__main__":
    argv = sys.argv[1:]
    tester = None
    if "--tester" in argv:
        i = argv.index("--tester")
        tester = argv[i + 1] if i + 1 < len(argv) and argv[i + 1] else None
        del argv[i:i + 2]
    args = [a for a in argv if a != "--auto"]
    if not 1 <= len(args) <= 2:
        sys.exit(__doc__)
    main(args[0], args[1] if len(args) > 1 else None, "--auto" in argv, tester)
