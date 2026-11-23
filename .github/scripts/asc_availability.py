#!/usr/bin/env python3
"""Take countries out of (or put them back into) an app's App Store availability.

  asc_availability.py <bundle_id> <dry-run|apply> [--eu] [--china] [--restore]

--eu     the 27 EU member states (the Digital Services Act trader question: a developer who declared
         itself a non-trader keeps that declaration by not distributing there)
--china  China mainland (needs a security assessment and an AI-content declaration)
Without --restore the listed countries are switched OFF; with it they are switched back ON.
dry-run only reads and prints. Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID (as ios_signing.py).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import json  # noqa: E402
import urllib.error  # noqa: E402
import urllib.request  # noqa: E402
from ios_signing import token  # noqa: E402

BASE = "https://api.appstoreconnect.apple.com"

EU = ["AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL",
      "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"]
CHINA = ["CHN"]


def call(method, url, body=None):
    """(status, json) for a full URL or a /v1|/v2 path (availability lives under /v2)."""
    req = urllib.request.Request(url if url.startswith("http") else BASE + url, method=method,
                                 data=json.dumps(body).encode() if body else None)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw.decode()[:800]}


def get(url):
    status, res = call("GET", url)
    if status >= 300:
        sys.exit(f"::error::GET {url} -> {status}: {res}")
    return res


def territory_rows(app_id):
    avail = get(f"/v1/apps/{app_id}/appAvailabilityV2")["data"]
    rows, url = [], f"/v2/appAvailabilities/{avail['id']}/territoryAvailabilities?limit=200&include=territory"
    while url:
        res = get(url)
        for r in res["data"]:
            rows.append({"id": r["id"], "territory": r["relationships"]["territory"]["data"]["id"],
                         "available": r["attributes"].get("available")})
        url = res.get("links", {}).get("next")
    return rows


def main():
    args = sys.argv[1:]
    if len(args) < 2 or args[1] not in ("dry-run", "apply"):
        sys.exit(__doc__)
    bundle, mode, flags = args[0], args[1], set(args[2:])
    want = ([] if "--eu" not in flags else EU) + ([] if "--china" not in flags else CHINA)
    if not want:
        sys.exit("::error::choose --eu and/or --china")
    app = get(f"/v1/apps?filter[bundleId]={bundle}")["data"]
    if not app:
        sys.exit(f"::error::No app {bundle}")
    app_id = app[0]["id"]
    rows = territory_rows(app_id)
    on = [r["territory"] for r in rows if r["available"]]
    print(f"{bundle}: {len(on)} of {len(rows)} territories available")
    target = "--restore" in flags  # switch OFF by default; --restore switches ON
    todo = [r for r in rows if r["territory"] in want and r["available"] != target]
    print(f"to switch {'ON' if target else 'OFF'}: {len(todo)} of {len(want)} -> {', '.join(r['territory'] for r in todo) or '-'}")
    if mode == "dry-run":
        return
    for r in todo:
        status, res = call("PATCH", f"/v1/territoryAvailabilities/{r['id']}",
                              {"data": {"type": "territoryAvailabilities", "id": r["id"],
                                        "attributes": {"available": target}}})
        print(f"  {r['territory']}: {'ok' if status < 300 else f'FAILED {status} {res}'}")
        if status >= 300:
            sys.exit(1)
    print("done")


if __name__ == "__main__":
    main()
