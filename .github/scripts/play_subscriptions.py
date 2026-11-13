#!/usr/bin/env python3
"""Create the Asraty subscriptions in Google Play (Android Publisher API, monetization).

  play_subscriptions.py inspect   read only: checks the service account's permission, lists products
  play_subscriptions.py apply     creates the missing products (base plan + 7-day free trial), activated

Products come from .github/scripts/asraty_subscriptions.json (same ids and SAR prices as the App Store).
Prices in other regions are converted by Google (pricing:convertRegionPrices), as the Play Console does.
Env: PLAY_SA_JSON (the service account key), SPEC_FILE.
"""
import base64
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal

PKG = "sa.asraty.app"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
REGIONS_VERSION = "2022/02"
PERIOD = {"ONE_MONTH": ("P1M", "monthly"), "ONE_YEAR": ("P1Y", "yearly")}


def b64u(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def access_token() -> str:
    sa = json.loads(os.environ["PLAY_SA_JSON"])
    now = int(time.time())
    inp = b64u(json.dumps({"alg": "RS256", "typ": "JWT"}).encode()) + "." + b64u(json.dumps({
        "iss": sa["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": sa.get("token_uri", "https://oauth2.googleapis.com/token"), "iat": now, "exp": now + 3000}).encode())
    with tempfile.NamedTemporaryFile("w", suffix=".pem") as f:
        os.chmod(f.name, 0o600)
        f.write(sa["private_key"])
        f.flush()
        sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", f.name], input=inp.encode(), capture_output=True, check=True).stdout
    body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": inp + "." + b64u(sig)}).encode()
    with urllib.request.urlopen(urllib.request.Request(sa.get("token_uri", "https://oauth2.googleapis.com/token"), data=body)) as r:
        return json.load(r)["access_token"]


TOKEN = None


def call(method: str, path: str, body=None, query=None):
    global TOKEN
    TOKEN = TOKEN or access_token()
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    req = urllib.request.Request(url, method=method, data=json.dumps(body if body is not None else {}).encode() if method != "GET" else None)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:600]}


def must(status, res, what):
    if status >= 300:
        sys.exit(f"::error::{what} -> {status}: {json.dumps(res, ensure_ascii=False)[:900]}")
    return res


def money(price: str, currency="SAR") -> dict:
    d = Decimal(price)
    units = int(d)
    return {"currencyCode": currency, "units": str(units), "nanos": int((d - units) * 1_000_000_000)}


def existing() -> dict:
    status, res = call("GET", "/subscriptions")
    must(status, res, "list subscriptions (does the service account have 'Manage orders and subscriptions' and is the API enabled?)")
    return {s["productId"]: s for s in res.get("subscriptions", [])}


def create(item: dict):
    pid = item["productId"]
    period, plan = PERIOD[item["period"]]
    conv = must(*call("POST", "/pricing:convertRegionPrices", {"price": money(item["price"])}), f"convert prices {pid}")
    # Use the regions version Google converted with (the prices must match the version they are created under).
    rv = (conv.get("regionVersion") or {}).get("version") or REGIONS_VERSION
    regional = {rc: v["price"] for rc, v in conv.get("convertedRegionPrices", {}).items()}
    regional["SA"] = money(item["price"])
    other = conv["convertedOtherRegionsPrice"]
    body = {
        "packageName": PKG, "productId": pid,
        "listings": [{"languageCode": "ar", "title": item["name"], "description": item["description"]}],
        "basePlans": [{
            "basePlanId": plan,
            "autoRenewingBasePlanType": {
                "billingPeriodDuration": period, "gracePeriodDuration": "P7D",
                "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE",
                "prorationMode": "SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE", "legacyCompatible": False},
            "regionalConfigs": [{"regionCode": rc, "newSubscriberAvailability": True, "price": p} for rc, p in regional.items()],
            "otherRegionsConfig": {"usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"], "newSubscriberAvailability": True},
        }],
    }
    must(*call("POST", "/subscriptions", body, {"productId": pid, "regionsVersion.version": rv}), f"create {pid}")
    print(f"[{pid}] created with SAR {item['price']} in {len(regional)} regions")
    must(*call("POST", f"/subscriptions/{pid}/basePlans/{plan}:activate"), f"activate base plan {pid}")
    print(f"[{pid}] base plan '{plan}' activated")
    offer = {
        "packageName": PKG, "productId": pid, "basePlanId": plan, "offerId": "trial",
        "phases": [{"duration": "P1W", "recurrenceCount": 1,
                    "regionalConfigs": [{"regionCode": rc, "free": {}} for rc in regional],
                    "otherRegionsConfig": {"free": {}}}],
        "targeting": {"acquisitionRule": {"scope": {"specificSubscriptionInApp": pid}}},
        "regionalConfigs": [{"regionCode": rc, "newSubscriberAvailability": True} for rc in regional],
        "otherRegionsConfig": {"otherRegionsNewSubscriberAvailability": True},
    }
    must(*call("POST", f"/subscriptions/{pid}/basePlans/{plan}/offers", offer, {"offerId": "trial", "regionsVersion.version": rv}), f"create trial {pid}")
    must(*call("POST", f"/subscriptions/{pid}/basePlans/{plan}/offers/trial:activate"), f"activate trial {pid}")
    print(f"[{pid}] 7-day free trial created and activated")


def main(mode: str):
    spec = json.loads(pathlib.Path(os.environ["SPEC_FILE"]).read_text())
    have = existing()
    print("permission OK; existing products:", sorted(have))
    for s in have.values():
        print(" -", s["productId"], [(b.get("basePlanId"), b.get("state")) for b in s.get("basePlans", [])])
    for item in spec["products"]:
        if item["productId"] in have:
            print(f"[{item['productId']}] already exists, skipped")
        elif mode == "apply":
            create(item)
        else:
            print(f"[{item['productId']}] missing")


if __name__ == "__main__":
    if sys.argv[1:] not in (["inspect"], ["apply"]):
        sys.exit(__doc__)
    main(sys.argv[1])
