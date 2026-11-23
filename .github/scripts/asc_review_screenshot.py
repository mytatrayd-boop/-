#!/usr/bin/env python3
"""Upload the App Review screenshot of every subscription of an app (App Store Connect keeps one per product; a
product stays «Missing Metadata» without it and cannot be added to a version).

  asc_review_screenshot.py <bundle_id> <png> [--dry-run]

Apple accepts the iPhone sizes 640x920, 640x1136, 750x1334, 1080x1920, 1242x2208 and larger, PNG or JPEG.
Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID (as ios_signing.py).
"""
import hashlib
import pathlib
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import request  # noqa: E402


def get(path):
    status, res = request("GET", path)
    if status >= 300:
        sys.exit(f"::error::GET {path} -> {status}: {str(res)[:500]}")
    return res


def write(method, path, body=None, fatal=True):
    status, res = request(method, path, body)
    if status >= 300:
        msg = f"{method} {path} -> {status}: {'; '.join(e.get('detail') or e.get('title', '') for e in (res or {}).get('errors', [])) or str(res)[:500]}"
        if fatal:
            sys.exit(f"::error::{msg}")
        print(f"::warning::{msg}")
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    bundle, image = args[0], pathlib.Path(args[1])
    data = image.read_bytes()
    md5 = hashlib.md5(data).hexdigest()
    app = get(f"/apps?filter[bundleId]={bundle}")["data"]
    if not app:
        sys.exit(f"::error::No app {bundle}")
    subs = []
    for g in get(f"/apps/{app[0]['id']}/subscriptionGroups?limit=50")["data"]:
        subs += get(f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]
    print(f"{bundle}: {len(subs)} subscriptions")
    for sub in subs:
        name, state = sub["attributes"]["productId"], sub["attributes"].get("state")
        status, cur = request("GET", f"/subscriptions/{sub['id']}/appStoreReviewScreenshot")
        existing = cur.get("data") if status < 300 and cur else None
        if existing and existing["attributes"].get("sourceFileChecksum") == md5:
            print(f"  {name} ({state}): screenshot unchanged")
            continue
        if dry:
            print(f"  {name} ({state}): would upload {image.name} ({len(data)} bytes)")
            continue
        if existing:
            write("DELETE", f"/subscriptionAppStoreReviewScreenshots/{existing['id']}")
        res = write("POST", "/subscriptionAppStoreReviewScreenshots",
                    {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                              "attributes": {"fileName": image.name, "fileSize": len(data)},
                              "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}}}}})
        shot = res["data"]
        for op in shot["attributes"]["uploadOperations"]:
            req = urllib.request.Request(op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]])
            for h in op.get("requestHeaders", []):
                req.add_header(h["name"], h["value"])
            urllib.request.urlopen(req).read()
        write("PATCH", f"/subscriptionAppStoreReviewScreenshots/{shot['id']}",
              {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": shot["id"],
                        "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
        print(f"  {name} ({state}): screenshot uploaded")


if __name__ == "__main__":
    main()
