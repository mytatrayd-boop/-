#!/usr/bin/env python3
"""Check and release an approved App Store version (release type MANUAL = "Pending Developer Release").

  asc_release.py <bundle_id> check     read only: versions waiting for release + every subscription's state
  asc_release.py <bundle_id> submit-subs   send every READY_TO_SUBMIT subscription to App Review
  asc_release.py <bundle_id> submit-with-subs   submit the editable version together with every READY_TO_SUBMIT subscription
                                                (Apple: the first subscription must go in with an app version)
  asc_release.py <bundle_id> cancel-review   withdraw the submission that waits for review (the version becomes editable again)
  asc_release.py <bundle_id> release-force   release even if subscriptions are not approved (owner's explicit order)
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
    if len(sys.argv) != 3 or sys.argv[2] not in ("check", "release", "release-force", "submit-subs", "cancel-review", "submit-with-subs"):
        sys.exit(__doc__)
    bundle, mode = sys.argv[1], sys.argv[2]
    app = get(f"/apps?filter[bundleId]={bundle}")["data"]
    if not app:
        sys.exit(f"::error::no app {bundle}")
    app_id = app[0]["id"]
    if mode == "submit-with-subs":
        vers = [v for v in get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
                if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED")]
        if len(vers) != 1:
            sys.exit(f"::error::expected exactly one editable version, found {len(vers)}")
        vid = vers[0]["id"]
        subs = []
        for g in get(f"/apps/{app_id}/subscriptionGroups?limit=50")["data"]:
            subs += [x for x in get(f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]
                     if x["attributes"].get("state") == "READY_TO_SUBMIT"]
        print(f"version {vers[0]['attributes']['versionString']} + {len(subs)} subscriptions")
        status, res = request("POST", "/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        if status >= 300:
            sys.exit(f"::error::reviewSubmissions -> {status}: {json.dumps(res)[:800]}")
        sub_id = res["data"]["id"]
        status, res = request("POST", "/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        if status >= 300:
            request("PATCH", f"/reviewSubmissions/{sub_id}", {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"canceled": True}}})
            sys.exit(f"::error::reviewSubmissionItems -> {status}: {json.dumps(res)[:800]}")
        failed = 0
        for x in subs:
            st, r = request("POST", "/subscriptionSubmissions", {"data": {
                "type": "subscriptionSubmissions",
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": x["id"]}}}}})
            print(f"  subscription {x['attributes']['productId']}: {st}")
            if st >= 300:
                failed += 1
                print("    raw:", json.dumps(r, ensure_ascii=False)[:1500])
        if failed:
            request("PATCH", f"/reviewSubmissions/{sub_id}", {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"canceled": True}}})
            sys.exit(f"::error::{failed} subscription(s) refused; the version submission was withdrawn (nothing was sent)")
        st, r = request("PATCH", f"/reviewSubmissions/{sub_id}", {"data": {
            "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
        if st >= 300:
            sys.exit(f"::error::submit -> {st}: {json.dumps(r)[:800]}")
        print("Submitted the version with its subscriptions for App Review.")
        return
    if mode == "cancel-review":
        subs = get(f"/apps/{app_id}/reviewSubmissions?filter[platform]=IOS&limit=10")["data"]
        waiting = [x for x in subs if x["attributes"].get("state") in ("WAITING_FOR_REVIEW", "READY_FOR_REVIEW")]
        if not waiting:
            sys.exit("::error::no submission waiting for review")
        for x in waiting:
            status, res = request("PATCH", f"/reviewSubmissions/{x['id']}", {"data": {
                "type": "reviewSubmissions", "id": x["id"], "attributes": {"canceled": True}}})
            detail = "; ".join(e.get("detail") or e.get("title", "") for e in (res or {}).get("errors", []))
            print(f"cancel {x['id']} ({x['attributes'].get('state')}): {status} {detail}")
        return
    versions = get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    waiting = [v for v in versions if v["attributes"]["appStoreState"] == "PENDING_DEVELOPER_RELEASE"]
    for v in versions[:5]:
        a = v["attributes"]
        print(f"Version {a['versionString']}: {a['appStoreState']} (release {a.get('releaseType')})")

    bad = []
    ready = []
    for g in get(f"/apps/{app_id}/subscriptionGroups?limit=50")["data"]:
        print(f"group {g['attributes'].get('referenceName')}:")
        glocs = get(f"/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations?limit=20")["data"]
        if not glocs:
            print("  GROUP LOCALIZATION: none (the group needs a display name per language)")
        for gl in glocs:
            ga = gl["attributes"]
            print(f"  group localization {ga.get('locale')}: {ga.get('state')}; name '{ga.get('name')}'; custom app name '{ga.get('customAppName')}'")
        for s in get(f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]:
            st = s["attributes"].get("state")
            a = s["attributes"]
            print(f"  subscription {a['productId']}: {st}; period {a.get('subscriptionPeriod')}; "
                  f"group level {a.get('groupLevel')}; review note {'yes' if a.get('reviewNote') else 'no'}")
            sid = s["id"]
            shot_status, shot = request("GET", f"/subscriptions/{sid}/appStoreReviewScreenshot")
            sd = (shot or {}).get("data")
            print("    review screenshot:", (sd or {}).get("attributes", {}).get("assetDeliveryState", {}).get("state")
                  if sd else f"none ({shot_status})")
            for loc in get(f"/subscriptions/{sid}/subscriptionLocalizations?limit=20")["data"]:
                la = loc["attributes"]
                print(f"    localization {la.get('locale')}: {la.get('state')}; name '{la.get('name')}'")
            print("    prices:", len(get(f"/subscriptions/{sid}/prices?limit=200")["data"]))
            st_av, av = request("GET", f"/subscriptions/{sid}/subscriptionAvailability")
            print("    availability:", st_av)
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
            if status >= 300:
                print("    raw:", json.dumps(res, ensure_ascii=False)[:3000])
        print("submitted:", len(ready), "(states update after Apple processes them; run check again)")
        return
    if mode == "check":
        print("waiting for release:", [v["attributes"]["versionString"] for v in waiting] or "none")
        return
    if len(waiting) != 1:
        sys.exit(f"::error::expected exactly one version waiting for release, found {len(waiting)}")
    if bad and mode == "release-force":
        print("OWNER OVERRIDE: releasing although subscriptions are not approved: " + ", ".join(bad))
    elif bad:
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
