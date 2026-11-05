#!/usr/bin/env python3
"""Create / complete App Store subscriptions through the App Store Connect API.

Idempotent: a product that already exists is reused and only the missing parts
(availability, prices, free trial, Arabic text) are added.

  asc_subscriptions.py inspect   read only: app, groups, products, SAR price points
  asc_subscriptions.py apply     create what is missing
  asc_subscriptions.py delete-stray   delete only the product ids listed in strayProductIds

Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID (same as ios_signing.py), SPEC_FILE.
Needs the API key role Admin or App Manager.
"""
import base64
import json
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from ios_signing import api, request  # noqa: E402

TERRITORY = "SAU"


def pages(path: str):
    """All items of a paginated GET (follows links.next)."""
    out, url = [], path
    while url:
        res = api("GET", url)
        out += res.get("data", [])
        nxt = (res.get("links") or {}).get("next")
        url = nxt.split("/v1", 1)[1] if nxt else None
    return out


def post(path: str, body: dict, what: str):
    status, res = request("POST", path, body)
    if status >= 300:
        sys.exit(f"::error::{what} -> {status}: {json.dumps(res, ensure_ascii=False)[:900]}")
    return res["data"]


def territory_of(point: dict) -> str:
    rel = ((point.get("relationships") or {}).get("territory") or {}).get("data")
    if rel:
        return rel["id"]
    pad = point["id"] + "=" * (-len(point["id"]) % 4)
    return json.loads(base64.urlsafe_b64decode(pad))["t"]


def find_app(bundle_id: str) -> dict:
    apps = api("GET", f"/apps?filter[bundleId]={bundle_id}")["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle id {bundle_id}")
    return apps[0]


def find_group(app_id: str, name: str, display: str, mode: str) -> dict:
    groups = api("GET", f"/apps/{app_id}/subscriptionGroups?limit=200")["data"]
    for g in groups:
        if g["attributes"]["referenceName"] == name:
            return g
    have = [g["attributes"]["referenceName"] for g in groups]
    if mode != "apply" or not display:
        sys.exit(f"::error::Subscription group '{name}' not found; have: {have}")
    g = post("/subscriptionGroups", {"data": {
        "type": "subscriptionGroups", "attributes": {"referenceName": name},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}, f"create group {name}")
    post("/subscriptionGroupLocalizations", {"data": {
        "type": "subscriptionGroupLocalizations",
        "attributes": {"locale": "ar-SA", "name": display},
        "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": g["id"]}}}}},
        f"group text {name}")
    print(f"group '{name}' created with Arabic name '{display}' (was: {have})")
    return g


def sau_points(sub_id: str) -> dict:
    pts = pages(f"/subscriptions/{sub_id}/pricePoints?filter[territory]={TERRITORY}&limit=200")
    return {p["attributes"]["customerPrice"]: p for p in pts}


def nearest(prices, target: float, n=5):
    return sorted(prices, key=lambda x: abs(float(x) - target))[:n]


def ensure(sub: dict, spec: dict, mode: str):
    sid, pid = sub["id"], spec["productId"]

    # Availability
    has_av = request("GET", f"/subscriptions/{sid}/subscriptionAvailability")[0] == 200
    print(f"[{pid}] availability: {'ok' if has_av else 'missing'}")
    if not has_av and mode == "apply":
        terrs = [t["id"] for t in pages("/territories?limit=200")]
        post("/subscriptionAvailabilities", {"data": {
            "type": "subscriptionAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}},
            f"availability of {pid}")
        print(f"[{pid}] availability set for {len(terrs)} territories")

    # Prices (the chosen SAR price, equalised to every other territory like the web UI does)
    existing = pages(f"/subscriptions/{sid}/prices?limit=200")
    points = sau_points(sid)
    want = spec["price"]
    print(f"[{pid}] prices set: {len(existing)}; SAR {want} available: {want in points}")
    if not existing:
        if want not in points:
            # The owner's rule: when the exact price does not exist, take the nearest price above it.
            above = sorted((p for p in points if float(p) > float(want)), key=float)
            print(f"[{pid}] SAR {want} is not a price point. Nearest: {nearest(points, float(want))}")
            if not above:
                print(f"::error::[{pid}] no price point above SAR {want}")
                return False
            want = above[0]
            print(f"[{pid}] using the nearest price above: SAR {want}")
        if mode == "apply":
            base = points[want]
            eq = pages(f"/subscriptionPricePoints/{base['id']}/equalizations?limit=200&include=territory")
            chosen = {territory_of(p): p for p in eq}
            chosen[TERRITORY] = base
            for terr, p in chosen.items():
                post("/subscriptionPrices", {"data": {
                    "type": "subscriptionPrices",
                    "attributes": {"preserveCurrentPrice": False},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": p["id"]}}}}},
                    f"price {pid}/{terr}")
            print(f"[{pid}] prices set in {len(chosen)} territories")

    # 7-day free trial
    offers = pages(f"/subscriptions/{sid}/introductoryOffers?limit=200")
    print(f"[{pid}] intro offers: {len(offers)}")
    if mode == "apply" and len(offers) < 170:
        # Apple wants one offer per territory (a product that already has ~all of them is left alone).
        done ={((o.get("relationships") or {}).get("territory") or {}).get("data", {}).get("id") for o in offers}
        made = 0
        for t in pages("/territories?limit=200"):
            if t["id"] in done:
                continue
            post("/subscriptionIntroductoryOffers", {"data": {
                "type": "subscriptionIntroductoryOffers",
                "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": sid}},
                    "territory": {"data": {"type": "territories", "id": t["id"]}}}}},
                f"intro offer {pid}/{t['id']}")
            made += 1
        print(f"[{pid}] free trial created in {made} territories")

    # Arabic text
    locs = pages(f"/subscriptions/{sid}/subscriptionLocalizations?limit=200")
    have_ar = any(l["attributes"]["locale"].startswith("ar") for l in locs)
    print(f"[{pid}] arabic text: {'ok' if have_ar else 'missing'}")
    if not have_ar and mode == "apply":
        post("/subscriptionLocalizations", {"data": {
            "type": "subscriptionLocalizations",
            "attributes": {"locale": "ar-SA", "name": spec["name"], "description": spec["description"]},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}},
            f"arabic text {pid}")
        print(f"[{pid}] arabic text created")
    return True


def delete_stray(spec: dict, group: dict):
    """Delete only products named in spec["strayProductIds"] that are NOT among the wanted products."""
    wanted = {p["productId"] for p in spec["products"]}
    for pid in spec.get("strayProductIds", []):
        if pid in wanted:
            sys.exit(f"::error::refusing to delete {pid}: it is a wanted product")
        subs = [s for s in pages(f"/subscriptionGroups/{group['id']}/subscriptions?limit=200")
                if s["attributes"]["productId"] == pid]
        if not subs:
            print(f"[{pid}] not found, nothing to delete")
            continue
        sub = subs[0]
        if sub["attributes"]["productId"] != pid:
            sys.exit(f"::error::unexpected product id {sub['attributes']['productId']}")
        status, res = request("DELETE", f"/subscriptions/{sub['id']}")
        if status >= 300:
            sys.exit(f"::error::delete {pid} -> {status}: {json.dumps(res, ensure_ascii=False)[:600]}")
        print(f"[{pid}] deleted (id {sub['id']}, name {sub['attributes'].get('name')})")


def main(mode: str):
    spec = json.loads(pathlib.Path(os.environ["SPEC_FILE"]).read_text())
    app = find_app(spec["bundleId"])
    group = find_group(app["id"], spec["group"], spec.get("groupDisplayName", ""), mode)
    if mode == "delete-stray":
        delete_stray(spec, group)
        return
    print(f"app {app['id']} ({app['attributes'].get('name')}), group {group['id']}")
    subs = {s["attributes"]["productId"]: s
            for s in pages(f"/subscriptionGroups/{group['id']}/subscriptions?limit=200")}
    print("existing products:", sorted(subs))
    ok = True
    for item in spec["products"]:
        pid = item["productId"]
        sub = subs.get(pid)
        if not sub:
            print(f"[{pid}] missing")
            if mode != "apply":
                continue
            sub = post("/subscriptions", {"data": {
                "type": "subscriptions",
                "attributes": {"name": item["referenceName"], "productId": pid,
                               "subscriptionPeriod": item["period"], "groupLevel": item["level"]},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group["id"]}}}}},
                f"create {pid}")
            print(f"[{pid}] created")
        ok = ensure(sub, item, mode) and ok
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    if sys.argv[1:] in (["inspect"], ["apply"], ["delete-stray"]):
        main(sys.argv[1])
    else:
        sys.exit(__doc__)
