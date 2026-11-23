#!/usr/bin/env python3
"""Check and release an approved App Store version (release type MANUAL = "Pending Developer Release").

  asc_release.py <bundle_id> check     read only: versions waiting for release + every subscription's state
  asc_release.py <bundle_id> submit-subs   send every READY_TO_SUBMIT subscription to App Review
  asc_release.py <bundle_id> release   release the version that waits (owner's explicit order only)

release refuses while any subscription is still MISSING_METADATA / READY_TO_SUBMIT / REJECTED /
DEVELOPER_ACTION_NEEDED (not attached to the reviewed version): releasing then would show a paywall
with no purchasable products. Stdlib only.

Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import request  # noqa: E402

OK_STATES = {"APPROVED", "PENDING_BINARY_APPROVAL"}


def get(path: str):
    status, res = request("GET", path)
    if status >= 300:
        sys.exit(f"::error::GET {path} -> {status}: {json.dumps(res)[:500]}")
    return res


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ("check", "release", "submit-subs"):
        sys.exit(__doc__)
    bundle, mode = sys.argv[1], sys.argv[2]
    app = get(f"/apps?filter[bundleId]={bundle}")["data"]
    if not app:
        sys.exit(f"::error::no app {bundle}")
    app_id = app[0]["id"]
    versions = get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    waiting = [v for v in versions if v["attributes"]["appStoreState"] == "PENDING_DEVELOPER_RELEASE"]
    for v in versions[:5]:
        a = v["attributes"]
        print(f"Version {a['versionString']}: {a['appStoreState']} (release {a.get('releaseType')})")

    bad = []
    ready = []
    for g in get(f"/apps/{app_id}/subscriptionGroups?limit=50")["data"]:
        for s in get(f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]:
            st = s["attributes"].get("state")
            print(f"  subscription {s['attributes']['productId']}: {st}")
            if st == "READY_TO_SUBMIT":
                ready.append(s)
            if st not in OK_STATES:
                bad.append(f"{s['attributes']['productId']}={st}")

    if mode == "submit-subs":
        for s in ready:
            status, res = request("POST", "/subscriptionSubmissions", {"data": {
                "type": "subscriptionSubmissions",
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": s["id"]}}}}})
            detail = "; ".join(e.get("detail") or e.get("title", "") for e in (res or {}).get("errors", []))
            print(f"  submit {s['attributes']['productId']}: {status} {detail}")
        print("submitted:", len(ready), "(states update after Apple processes them; run check again)")
        return
    if mode == "check":
        print("waiting for release:", [v["attributes"]["versionString"] for v in waiting] or "none")
        return
    if len(waiting) != 1:
        sys.exit(f"::error::expected exactly one version waiting for release, found {len(waiting)}")
    if bad:
        sys.exit("::error::refused: subscriptions not attached/approved: " + ", ".join(bad)
                 + ". Add them to the version in App Store Connect first.")
    vid = waiting[0]["id"]
    status, res = request("POST", "/appStoreVersionReleaseRequests", {"data": {
        "type": "appStoreVersionReleaseRequests",
        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    if status >= 300:
        sys.exit(f"::error::release -> {status}: {json.dumps(res)[:600]}")
    print(f"Released version {waiting[0]['attributes']['versionString']} to the App Store.")


if __name__ == "__main__":
    main()
