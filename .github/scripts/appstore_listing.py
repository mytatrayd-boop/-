#!/usr/bin/env python3
"""Fill an app's App Store page (texts, screenshots, age rating, review notes) from the repo.

Reads from <store_dir>:
  metadata/appstore/<locale>/{name,subtitle,description,keywords,promotional_text,
                              support_url,privacy_url[,marketing_url]}.txt   (e.g. locale ar-SA)
  metadata/appstore/review_notes.txt     notes for App Review (sign-in not required)
  metadata/appstore/age_rating.json      ageRatingDeclaration attributes
  appstore/*.png                         iPhone screenshots, in name order, for every locale

Works on the version that is still editable (Prepare for Submission or rejected). --build N
attaches build N to that version. Only with --submit is the version then sent to App Review
(the owner's explicit «ارفع» for this app and version; see store-manager.md). Review contact details
come only from the optional env ASC_REVIEW_FIRST_NAME, ASC_REVIEW_LAST_NAME,
ASC_REVIEW_EMAIL, ASC_REVIEW_PHONE (GitHub Secrets), never from the repo.
--dry-run reads App Store Connect and prints what would change; --check sends nothing.

  appstore_listing.py <bundle_id> <store_dir> [--dry-run | --check] [--build N] [--submit]

Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID (as ios_signing.py).
"""
import hashlib
import json
import os
import pathlib
import struct
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import request  # noqa: E402  (App Store Connect API key auth)

LIMITS = {"name": 30, "subtitle": 30, "description": 4000, "keywords": 100, "promotional_text": 170,
          "support_url": 255, "privacy_url": 255, "marketing_url": 255}
REQUIRED = ["name", "description", "keywords", "support_url", "privacy_url"]
VERSION_FIELDS = {"description": "description", "keywords": "keywords",
                  "promotional_text": "promotionalText", "support_url": "supportUrl",
                  "marketing_url": "marketingUrl"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacy_url": "privacyPolicyUrl"}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "INVALID_BINARY"}
# iPhone screenshot sizes -> display type (6.9"/6.7" and 6.5").
DISPLAY = {(1290, 2796): "APP_IPHONE_67", (1320, 2868): "APP_IPHONE_67", (1284, 2778): "APP_IPHONE_65",
           (1242, 2688): "APP_IPHONE_65"}


def png_size(path: pathlib.Path) -> tuple:
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"::error::{path} is not a PNG")
    w, h = struct.unpack(">II", head[16:24])
    return (min(w, h), max(w, h))


def read_store(store: pathlib.Path) -> tuple:
    root = store / "metadata" / "appstore"
    locales = {}
    for d in sorted(p for p in root.iterdir() if p.is_dir()) if root.is_dir() else []:
        texts = {}
        for name, limit in LIMITS.items():
            f = d / f"{name}.txt"
            if not f.exists():
                if name in REQUIRED:
                    sys.exit(f"::error::Missing {f}")
                continue
            text = f.read_text(encoding="utf-8").strip()
            if len(text) > limit or (name in REQUIRED and not text):
                sys.exit(f"::error::{f}: {len(text)} characters (max {limit})")
            texts[name] = text
        locales[d.name] = texts
    if not locales:
        sys.exit(f"::error::No locale folders in {root}")
    notes = root / "review_notes.txt"
    age = root / "age_rating.json"
    shots = sorted((store / "appstore").glob("*.png")) if (store / "appstore").is_dir() else []
    types = {DISPLAY.get(png_size(p)) for p in shots}
    if shots and (None in types or len(types) != 1):
        sys.exit(f"::error::Screenshots must all be one supported iPhone size: "
                 + ", ".join(f"{p.name} {png_size(p)}" for p in shots))
    if len(shots) > 10:
        sys.exit("::error::At most 10 screenshots")
    return (locales, notes.read_text(encoding="utf-8").strip() if notes.exists() else None,
            json.loads(age.read_text()) if age.exists() else None, shots, types.pop() if shots else None)


class Store:
    def __init__(self, dry_run: bool):
        self.dry = dry_run

    def get(self, path: str):
        status, res = request("GET", path)
        if status >= 300:
            sys.exit(f"::error::GET {path} -> {status}: {json.dumps(res)[:600]}")
        return res

    def write(self, method: str, path: str, body=None, what: str = "", fatal: bool = True):
        if self.dry:
            print(f"  would {method} {path}: {what}")
            return None
        status, res = request(method, path, body)
        if status >= 300:
            msg = f"{method} {path} -> {status}: {json.dumps(res)[:600]}"
            if fatal:
                sys.exit(f"::error::{msg}")
            print(f"::warning::{msg}")
            return None
        print(f"  {what or method + ' ' + path}")
        return res

    def changed(self, current: dict, wanted: dict) -> dict:
        return {k: v for k, v in wanted.items() if (current.get(k) or "").strip() != v}


def main():
    argv = sys.argv[1:]
    build = None
    if "--build" in argv:
        i = argv.index("--build")
        build = argv[i + 1]
        del argv[i:i + 2]
    args = [a for a in argv if not a.startswith("--")]
    flags = {a for a in argv if a.startswith("--")}
    if len(args) != 2 or flags - {"--dry-run", "--check", "--submit"}:
        sys.exit(__doc__)
    bundle_id, store_dir = args[0], pathlib.Path(args[1])
    locales, notes, age, shots, display = read_store(store_dir)
    print(f"{bundle_id}: locales {', '.join(locales)}; {len(shots)} screenshots ({display}); "
          f"review notes {'yes' if notes else 'no'}; age rating {'yes' if age else 'no'}")
    if "--check" in flags:
        print("Check only: files are valid; nothing was sent.")
        return
    s = Store("--dry-run" in flags)

    apps = s.get(f"/apps?filter[bundleId]={bundle_id}")["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle id {bundle_id} in App Store Connect")
    app = apps[0]["id"]
    versions = s.get(f"/apps/{app}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    editable = [v for v in versions if v["attributes"].get("appStoreState") in EDITABLE]
    if not editable:
        sys.exit("::error::No editable App Store version. Create the next version in App Store Connect first.")
    version = editable[0]
    vid = version["id"]
    print(f"Version {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")
    infos = s.get(f"/apps/{app}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") in EDITABLE
                 or i["attributes"].get("state") in {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"}),
                infos[0])
    iid = info["id"]

    vlocs = {l["attributes"]["locale"]: l for l in
             s.get(f"/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50")["data"]}
    ilocs = {l["attributes"]["locale"]: l for l in
             s.get(f"/appInfos/{iid}/appInfoLocalizations?limit=50")["data"]}
    for locale, texts in locales.items():
        print(f"[{locale}]")
        wanted = {VERSION_FIELDS[k]: v for k, v in texts.items() if k in VERSION_FIELDS}
        if locale in vlocs:
            diff = s.changed(vlocs[locale]["attributes"], wanted)
            if diff:
                s.write("PATCH", f"/appStoreVersionLocalizations/{vlocs[locale]['id']}",
                        {"data": {"type": "appStoreVersionLocalizations", "id": vlocs[locale]["id"],
                                  "attributes": diff}}, "version texts: " + ", ".join(diff))
            loc_id = vlocs[locale]["id"]
        else:
            res = s.write("POST", "/appStoreVersionLocalizations",
                          {"data": {"type": "appStoreVersionLocalizations",
                                    "attributes": {"locale": locale, **wanted},
                                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}},
                          "new version localization")
            loc_id = res["data"]["id"] if res else None
        wanted = {INFO_FIELDS[k]: v for k, v in texts.items() if k in INFO_FIELDS}
        if locale in ilocs:
            diff = s.changed(ilocs[locale]["attributes"], wanted)
            if diff:
                s.write("PATCH", f"/appInfoLocalizations/{ilocs[locale]['id']}",
                        {"data": {"type": "appInfoLocalizations", "id": ilocs[locale]["id"], "attributes": diff}},
                        "app info: " + ", ".join(diff))
        else:
            s.write("POST", "/appInfoLocalizations",
                    {"data": {"type": "appInfoLocalizations", "attributes": {"locale": locale, **wanted},
                              "relationships": {"appInfo": {"data": {"type": "appInfos", "id": iid}}}}},
                    "new app info localization")
        if shots and loc_id:
            upload_screenshots(s, loc_id, display, shots)
        elif shots:
            print(f"  would upload {len(shots)} screenshots")

    if notes is not None:
        status, res = request("GET", f"/appStoreVersions/{vid}/appStoreReviewDetail")
        attrs = {"notes": notes, "demoAccountRequired": False}
        for env, key in [("ASC_REVIEW_FIRST_NAME", "contactFirstName"), ("ASC_REVIEW_LAST_NAME", "contactLastName"),
                         ("ASC_REVIEW_EMAIL", "contactEmail"), ("ASC_REVIEW_PHONE", "contactPhone")]:
            if os.environ.get(env):
                attrs[key] = os.environ[env]
        if status < 300 and res and res.get("data"):
            rid = res["data"]["id"]
            s.write("PATCH", f"/appStoreReviewDetails/{rid}",
                    {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": attrs}},
                    "review details: " + ", ".join(attrs))
        else:
            s.write("POST", "/appStoreReviewDetails",
                    {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
                              "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}},
                    "review details: " + ", ".join(attrs))

    if age:
        status, res = request("GET", f"/appInfos/{iid}/ageRatingDeclaration")
        if status < 300 and res and res.get("data"):
            rid = res["data"]["id"]
            # Non-fatal: Apple adds questions over time; the rest of the page is still filled.
            s.write("PATCH", f"/ageRatingDeclarations/{rid}",
                    {"data": {"type": "ageRatingDeclarations", "id": rid, "attributes": age}},
                    "age rating answers", fatal=False)
        else:
            print(f"::warning::No age rating declaration found ({status}); answer it in App Store Connect")

    if build:
        found = s.get(f"/builds?filter[app]={app}&filter[version]={build}&limit=5")["data"]
        if not found:
            sys.exit(f"::error::Build {build} not found (still processing?)")
        s.write("PATCH", f"/appStoreVersions/{vid}/relationships/build",
                {"data": {"type": "builds", "id": found[0]["id"]}}, f"attached build {build}")

    if "--submit" in flags:
        submit(s, app, vid)
    else:
        print("Dry run: nothing changed." if s.dry else "Done. Nothing was submitted for review.")


def submit(s: Store, app: str, vid: str):
    """Send the version to App Review: a review submission holding this version, then submitted."""
    if not s.dry:
        status, res = request("GET", f"/appStoreVersions/{vid}/build")
        if status >= 300 or not (res or {}).get("data"):
            sys.exit("::error::No build attached to the version; pass --build N")
    res = s.write("POST", "/reviewSubmissions",
                  {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                            "relationships": {"app": {"data": {"type": "apps", "id": app}}}}},
                  "new review submission")
    sub = res["data"]["id"] if res else "<new>"
    s.write("POST", "/reviewSubmissionItems",
            {"data": {"type": "reviewSubmissionItems",
                      "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
                                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}},
            "added the version to the submission")
    s.write("PATCH", f"/reviewSubmissions/{sub}",
            {"data": {"type": "reviewSubmissions", "id": sub, "attributes": {"submitted": True}}},
            "submitted for App Review")
    print("Dry run: nothing changed." if s.dry else "Submitted for App Review.")


def upload_screenshots(s: Store, loc_id: str, display: str, shots: list):
    sets = s.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=50")["data"]
    current = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == display), None)
    if current:
        existing = s.get(f"/appScreenshotSets/{current['id']}/appScreenshots?limit=50")["data"]
        names = [x["attributes"].get("fileName") for x in existing]
        if names == [p.name for p in shots] and all(
                x["attributes"].get("sourceFileChecksum") == hashlib.md5(p.read_bytes()).hexdigest()
                for x, p in zip(existing, shots)):
            print(f"  screenshots {display}: unchanged")
            return
        for x in existing:
            s.write("DELETE", f"/appScreenshots/{x['id']}", what=f"removed old screenshot {x['attributes'].get('fileName')}")
        set_id = current["id"]
    else:
        res = s.write("POST", "/appScreenshotSets",
                      {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
                                "relationships": {"appStoreVersionLocalization": {
                                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}},
                      f"new screenshot set {display}")
        set_id = res["data"]["id"] if res else None
    if s.dry:
        print(f"  would upload {len(shots)} screenshots: {', '.join(p.name for p in shots)}")
        return
    for p in shots:
        data = p.read_bytes()
        res = s.write("POST", "/appScreenshots",
                      {"data": {"type": "appScreenshots", "attributes": {"fileName": p.name, "fileSize": len(data)},
                                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}},
                      f"reserved {p.name}")
        shot = res["data"]
        for op in shot["attributes"]["uploadOperations"]:
            part = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], method=op["method"], data=part)
            for h in op.get("requestHeaders", []):
                req.add_header(h["name"], h["value"])
            urllib.request.urlopen(req).read()
        s.write("PATCH", f"/appScreenshots/{shot['id']}",
                {"data": {"type": "appScreenshots", "id": shot["id"],
                          "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}},
                f"uploaded {p.name}")


if __name__ == "__main__":
    main()
