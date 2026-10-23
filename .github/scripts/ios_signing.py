#!/usr/bin/env python3
"""App Store signing for CI without a Mac or a registered device.

Uses the App Store Connect API key to create a temporary Apple Distribution
certificate and an App Store provisioning profile, installs them in a
throwaway keychain, switches the Runner target to manual signing and writes
the export options. `cleanup` deletes the local keychain only: the certificate
must stay valid until Apple has processed and reviewed the build (revoking it
right after upload caused ITMS-90035 "Invalid Signature"). At the account's
certificate limit, the oldest distribution certificate is revoked.

Stdlib + /usr/bin/openssl only.

  ios_signing.py setup <bundle_id>[,<extension_bundle_id>...] <path/to/project.pbxproj> <export_options_out>
  ios_signing.py cleanup

Several bundle ids (app first, then app extensions such as a widget) get one App
Store profile each, all signed by the same temporary certificate. With
IOS_CAPABILITIES=APP_GROUPS, missing bundle ids are registered and the App Groups
capability is enabled on each; the group itself must still be created and ticked
for each id in developer.apple.com (the API cannot assign groups).

Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, APPLE_TEAM_ID, RUNNER_TEMP.
"""
import base64
import json
import os
import pathlib
import plistlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
OPENSSL = "/usr/bin/openssl"  # LibreSSL on macOS: its PKCS#12 output imports cleanly
WWDR_G3 = "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
KEYCHAIN = "ci-signing.keychain-db"
IDENTITY = "Apple Distribution"

TMP = pathlib.Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "ios-signing"
STATE = TMP / "state.json"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(sig: bytes) -> bytes:
    """ECDSA DER signature -> 64-byte r||s as JWS ES256 requires."""
    assert sig[0] == 0x30
    i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert sig[i] == 0x02
        n = sig[i + 1]
        out += sig[i + 2:i + 2 + n].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + n
    return out


def token() -> str:
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900,
              "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(claims).encode())}"
    der = subprocess.run([OPENSSL, "dgst", "-sha256", "-sign", os.environ["ASC_KEY_PATH"]],
                         input=signing_input.encode(), capture_output=True, check=True).stdout
    return f"{signing_input}.{b64url(der_to_raw(der))}"


def request(method: str, path: str, body=None):
    """Like api() but returns (status, json) instead of exiting on an HTTP error."""
    req = urllib.request.Request(API + path, method=method,
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


def api(method: str, path: str, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body else None)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        sys.exit(f"::error::App Store Connect API {method} {path} -> {e.code}: {e.read().decode()[:800]}")


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def create_certificate(csr_body: str) -> dict:
    """New distribution certificate. At the account limit the oldest distribution
    certificate is revoked to make room (the owner has no Mac, so they all come
    from earlier CI runs); the newest stay valid for builds still in review."""
    body = {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": csr_body}}}
    for _ in range(3):
        status, res = request("POST", "/certificates", body)
        if status < 300:
            return res["data"]
        if status != 409:
            sys.exit(f"::error::App Store Connect API POST /certificates -> {status}: {json.dumps(res)[:800]}")
        old = sorted(api("GET", "/certificates?filter[certificateType]=DISTRIBUTION&limit=200")["data"],
                     key=lambda c: c["attributes"].get("expirationDate") or "")
        if not old:
            break
        print(f"Certificate limit reached; revoking the oldest distribution certificate {old[0]['id']}")
        api("DELETE", f"/certificates/{old[0]['id']}")
    sys.exit("::error::Could not create a distribution certificate (account limit)")


def bundle_resource(bundle_id: str, capabilities: list) -> str:
    """The bundleIds resource id, registering the id and enabling [capabilities] if asked."""
    found = api("GET", f"/bundleIds?filter[identifier]={bundle_id}&limit=200")["data"]
    match = [b for b in found if b["attributes"]["identifier"] == bundle_id]
    if match:
        rid = match[0]["id"]
    elif capabilities:
        rid = api("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": bundle_id, "name": bundle_id.replace(".", " "), "platform": "IOS"}}})["data"]["id"]
        print(f"Registered bundle id {bundle_id}")
    else:
        sys.exit(f"::error::Bundle ID {bundle_id} not found in developer.apple.com Identifiers")
    if capabilities:
        have = {c["attributes"]["capabilityType"]
                for c in api("GET", f"/bundleIds/{rid}/bundleIdCapabilities")["data"]}
        for cap in capabilities:
            if cap not in have:
                api("POST", "/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
                    "attributes": {"capabilityType": cap},
                    "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": rid}}}}})
                print(f"Enabled {cap} on {bundle_id}")
    return rid


def setup(bundle_ids: str, pbxproj: str, export_options: str):
    TMP.mkdir(parents=True, exist_ok=True)
    team = os.environ["APPLE_TEAM_ID"]
    ids = [b for b in bundle_ids.split(",") if b]
    capabilities = [c for c in os.environ.get("IOS_CAPABILITIES", "").split(",") if c]

    # 1. Distribution certificate from a fresh key + CSR.
    key, csr = TMP / "dist.key", TMP / "dist.csr"
    run(OPENSSL, "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key),
        "-subj", "/CN=GitHub Actions/O=CI", "-out", str(csr), capture_output=True)
    csr_body = "".join(l for l in csr.read_text().splitlines() if "-----" not in l)
    cert = create_certificate(csr_body)
    state = {"certificate": cert["id"]}
    STATE.write_text(json.dumps(state))
    der = TMP / "dist.cer"
    der.write_bytes(base64.b64decode(cert["attributes"]["certificateContent"]))

    # 2. App Store profile for each bundle id.
    names = {}
    home = pathlib.Path.home()
    for bundle_id in ids:
        rid = bundle_resource(bundle_id, capabilities)
        name = f"{bundle_id} CI {os.environ.get('GITHUB_RUN_ID', int(time.time()))}"
        prof = api("POST", "/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": rid}},
                "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]}}}})["data"]
        state.setdefault("profiles", []).append(prof["id"])
        STATE.write_text(json.dumps(state))
        content = base64.b64decode(prof["attributes"]["profileContent"])
        uuid = prof["attributes"]["uuid"]
        for d in (home / "Library/MobileDevice/Provisioning Profiles",
                  home / "Library/Developer/Xcode/UserData/Provisioning Profiles"):
            d.mkdir(parents=True, exist_ok=True)
            (d / f"{uuid}.mobileprovision").write_bytes(content)
        names[bundle_id] = name

    # 3. Throwaway keychain with the identity and Apple's intermediate.
    pem, p12 = TMP / "dist.pem", TMP / "dist.p12"
    run(OPENSSL, "x509", "-inform", "DER", "-in", str(der), "-out", str(pem))
    pw = b64url(os.urandom(18))
    run(OPENSSL, "pkcs12", "-export", "-inkey", str(key), "-in", str(pem), "-out", str(p12),
        "-passout", f"pass:{pw}")
    wwdr = TMP / "wwdr.cer"
    wwdr.write_bytes(urllib.request.urlopen(WWDR_G3).read())
    run("security", "create-keychain", "-p", pw, KEYCHAIN)
    run("security", "set-keychain-settings", "-lut", "21600", KEYCHAIN)
    run("security", "unlock-keychain", "-p", pw, KEYCHAIN)
    run("security", "import", str(p12), "-k", KEYCHAIN, "-P", pw, "-T", "/usr/bin/codesign",
        "-T", "/usr/bin/security")
    subprocess.run(["security", "import", str(wwdr), "-k", KEYCHAIN])  # may already exist
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", pw, KEYCHAIN,
        capture_output=True)
    current = subprocess.run(["security", "list-keychains", "-d", "user"], capture_output=True,
                             text=True, check=True).stdout.split()
    run("security", "list-keychains", "-d", "user", "-s", KEYCHAIN, *[c.strip('"') for c in current])
    for f in (key, p12):
        f.unlink()

    # 4. Manual signing on the app and extension targets only (pods stay unsigned).
    src = pathlib.Path(pbxproj).read_text()
    indent = "\t\t\t\t"
    for bundle_id, name in names.items():
        anchor = f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};"
        if anchor not in src:
            sys.exit(f"::error::{anchor} not found in {pbxproj}")
        extra = "".join(f"\n{indent}{k} = {v};" for k, v in [
            ("CODE_SIGN_STYLE", "Manual"),
            ("DEVELOPMENT_TEAM", team),
            ('"CODE_SIGN_IDENTITY[sdk=iphoneos*]"', f'"{IDENTITY}"'),
            ("PROVISIONING_PROFILE_SPECIFIER", f'"{name}"'),
        ])
        src = src.replace(anchor, anchor + extra)
    pathlib.Path(pbxproj).write_text(src)

    # 5. Export options: sign with this profile and upload to App Store Connect.
    with open(export_options, "wb") as f:
        plistlib.dump({
            "method": "app-store-connect", "destination": "upload", "teamID": team,
            "signingStyle": "manual", "signingCertificate": IDENTITY,
            "provisioningProfiles": names,
            "uploadSymbols": True, "manageAppVersionAndBuildNumber": False,
        }, f)
    print(f"Signing ready: certificate {cert['id']}, profiles {list(names.values())}")


def cleanup():
    # Only the local keychain (with the private key) is removed. The certificate
    # and profile stay valid: revoking them right after upload made Apple reject
    # the build later with ITMS-90035 "Invalid Signature". Old certificates are
    # revoked by create_certificate() when the account limit is reached.
    subprocess.run(["security", "delete-keychain", KEYCHAIN])
    if STATE.exists():
        STATE.unlink()
    print("Local signing keychain deleted (certificate kept so the uploaded build stays valid)")


if __name__ == "__main__":
    if sys.argv[1:2] == ["setup"] and len(sys.argv) == 5:
        setup(*sys.argv[2:])
    elif sys.argv[1:] == ["cleanup"]:
        cleanup()
    else:
        sys.exit(__doc__)
