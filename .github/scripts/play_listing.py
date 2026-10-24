#!/usr/bin/env python3
"""Upload an app's Google Play store listing (texts and images) from the repo.

Reads <store_dir>/metadata/play/<lang>/{title,short_description,full_description}.txt
for every language folder, and the images in <store_dir>/play/:
  icon-512.png -> icon, feature-graphic.png -> featureGraphic,
  every other *.png (sorted by name) -> phoneScreenshots.
Images are uploaded to the default language only (the first folder, or PLAY_IMAGES_LANG).

One Play "edit": update the listings, replace the images, then commit. With --dry-run
the edit is validated and deleted instead of committed (nothing changes in Play).
With --check nothing is sent: the files are only validated (lengths, sizes).

Stdlib + openssl only.

  play_listing.py <package_name> <store_dir> [--dry-run | --check]

Env: PLAY_SERVICE_ACCOUNT_JSON (the service account key JSON, from GitHub Secrets).
"""
import base64
import json
import os
import pathlib
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Play limits: characters per field, and image sizes.
LIMITS = {"title": 30, "short_description": 80, "full_description": 4000}
FIELDS = {"title": "title", "short_description": "shortDescription", "full_description": "fullDescription"}


def png_size(path: pathlib.Path) -> tuple:
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"::error::{path} is not a PNG")
    return struct.unpack(">II", head[16:24])


def read_listing(store: pathlib.Path) -> dict:
    """{lang: {field: text}} with the limits checked."""
    root = store / "metadata" / "play"
    langs = sorted(p for p in root.iterdir() if p.is_dir()) if root.is_dir() else []
    if not langs:
        sys.exit(f"::error::No language folders in {root}")
    out = {}
    for d in langs:
        texts = {}
        for name, limit in LIMITS.items():
            f = d / f"{name}.txt"
            if not f.exists():
                sys.exit(f"::error::Missing {f}")
            text = f.read_text(encoding="utf-8").strip()
            if not text or len(text) > limit:
                sys.exit(f"::error::{f}: {len(text)} characters (1..{limit})")
            texts[name] = text
        out[d.name] = texts
    return out


def read_images(store: pathlib.Path) -> dict:
    """{imageType: [paths]} with Play's size rules checked."""
    d = store / "play"
    pngs = sorted(d.glob("*.png")) if d.is_dir() else []
    images = {"icon": [], "featureGraphic": [], "phoneScreenshots": []}
    for p in pngs:
        kind = {"icon-512.png": "icon", "feature-graphic.png": "featureGraphic"}.get(p.name, "phoneScreenshots")
        images[kind].append(p)
    for p in images["icon"]:
        if png_size(p) != (512, 512):
            sys.exit(f"::error::{p}: icon must be 512x512, got {png_size(p)}")
    for p in images["featureGraphic"]:
        if png_size(p) != (1024, 500):
            sys.exit(f"::error::{p}: feature graphic must be 1024x500, got {png_size(p)}")
    shots = images["phoneScreenshots"]
    if not 2 <= len(shots) <= 8:
        sys.exit(f"::error::{d}: {len(shots)} phone screenshots (2..8)")
    for p in shots:
        w, h = png_size(p)
        if not (320 <= min(w, h) and max(w, h) <= 3840 and max(w, h) <= 2 * min(w, h)):
            sys.exit(f"::error::{p}: screenshot size {w}x{h} outside Play's rules")
    return images


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token() -> str:
    key = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {"iss": key["client_email"], "scope": SCOPE, "aud": key["token_uri"],
              "iat": now, "exp": now + 3000}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(claims).encode())}"
    with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as f:
        f.write(key["private_key"])
        pem = f.name
    try:
        sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", pem],
                             input=signing_input.encode(), capture_output=True, check=True).stdout
    finally:
        os.unlink(pem)
    body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                   "assertion": f"{signing_input}.{b64url(sig)}"}).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as r:
        return json.loads(r.read())["access_token"]


class Play:
    def __init__(self, package: str):
        self.package = package
        self.token = access_token()

    def call(self, method: str, url: str, body=None, data: bytes = None, content_type="application/json"):
        if body is not None:
            data = json.dumps(body).encode()
        req = urllib.request.Request(url, method=method, data=data)
        req.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            req.add_header("Content-Type", content_type)
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            # Plain words only: GitHub masks every line of the secret JSON (even «{» and «}»),
            # which hid the whole raw error body.
            try:
                err = json.loads(raw).get("error", {})
                msg = " | ".join(filter(None, [err.get("status"), err.get("message")]))
                msg = msg.replace("{", "(").replace("}", ")").replace('"', "'")
            except (ValueError, AttributeError):
                msg = raw[:800]
            hint = " (give the service account access to this app in Play Console › Users and permissions)" \
                if e.code == 403 else ""
            sys.exit(f"::error::Play API {method} {url.split('/applications/')[-1]} -> {e.code}{hint}: {msg}")

    def edit(self, path: str = "") -> str:
        return f"{API}/{self.package}/edits/{self.edit_id}{path}"

    def finish(self, action: str):
        """Validate or commit. Apps under managed review (e.g. after a policy rejection) refuse
        automatic sending; then the edit is kept with changesNotSentForReview=true and the owner
        sends it from Publishing overview."""
        try:
            self.call("POST", self.edit(action))
        except SystemExit as e:
            if "changesNotSentForReview" not in str(e):
                raise
            self.call("POST", self.edit(action) + "?changesNotSentForReview=true")
            print("::notice::Changes are not sent for review automatically: "
                  "send them from Play Console › Publishing overview.")

    def run(self, listing: dict, images: dict, image_lang: str, dry_run: bool):
        self.edit_id = self.call("POST", f"{API}/{self.package}/edits", {})["id"]
        for lang, texts in listing.items():
            body = {"language": lang, **{FIELDS[k]: v for k, v in texts.items()}}
            self.call("PUT", self.edit(f"/listings/{lang}"), body)
            print(f"listing {lang}: title, short and full description")
        for kind, paths in images.items():
            if not paths:
                continue
            self.call("DELETE", self.edit(f"/listings/{image_lang}/{kind}"))
            for p in paths:
                url = f"{UPLOAD}/{self.package}/edits/{self.edit_id}/listings/{image_lang}/{kind}?uploadType=media"
                self.call("POST", url, data=p.read_bytes(), content_type="image/png")
            print(f"images {image_lang} {kind}: {', '.join(p.name for p in paths)}")
        if dry_run:
            self.finish(":validate")
            self.call("DELETE", self.edit())
            print("Dry run: the edit is valid and was discarded; nothing changed in Play.")
        else:
            self.finish(":commit")
            print("Committed: the store listing is updated in Play.")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 2 or flags - {"--dry-run", "--check"}:
        sys.exit(__doc__)
    package, store = args[0], pathlib.Path(args[1])
    listing = read_listing(store)
    images = read_images(store)
    image_lang = os.environ.get("PLAY_IMAGES_LANG") or next(iter(listing))
    print(f"{package}: languages {', '.join(listing)}; images to {image_lang}: "
          + ", ".join(f"{k} {len(v)}" for k, v in images.items()))
    if "--check" in flags:
        print("Check only: files are valid; nothing was sent.")
        return
    Play(package).run(listing, images, image_lang, "--dry-run" in flags)


if __name__ == "__main__":
    main()
