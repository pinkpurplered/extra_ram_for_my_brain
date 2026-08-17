#!/usr/bin/env python3
"""Upload LoopRecorder to App Store Connect using API key auth."""

from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY_ID = "D8WLYCSLX9"
ISSUER_ID = "777189c3-31c7-4d39-9135-fa3d520d3162"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys/AuthKey_D8WLYCSLX9.p8"
BUNDLE_ID = "com.extraram.LoopRecorder"
DEFAULT_IPA = Path("/tmp/LoopRecorder-final-export/LoopRecorder.ipa")


def make_token() -> str:
    import jwt

    private_key = KEY_PATH.read_text()
    now = int(time.time())
    headers = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api_get(path: str) -> dict:
    token = make_token()
    req = urllib.request.Request(f"https://api.appstoreconnect.apple.com{path}")
    req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def app_exists() -> bool:
    try:
        data = api_get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    except urllib.error.HTTPError as err:
        print(f"API error checking app: {err.read().decode()}", file=sys.stderr)
        return False
    return bool(data.get("data"))


def upload_ipa(ipa_path: Path) -> int:
    cmd = [
        "xcrun",
        "altool",
        "--upload-app",
        "-f",
        str(ipa_path),
        "-t",
        "ios",
        "--apiKey",
        KEY_ID,
        "--apiIssuer",
        ISSUER_ID,
    ]
    print("Uploading", ipa_path)
    return subprocess.call(cmd)


def main() -> int:
    ipa = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_IPA
    if not KEY_PATH.exists():
        print(f"Missing API key: {KEY_PATH}", file=sys.stderr)
        return 1
    if not ipa.exists():
        print(f"Missing IPA: {ipa}", file=sys.stderr)
        return 1

    if not app_exists():
        print(
            "\nApp Store Connect app record not found for "
            f"{BUNDLE_ID}.\n\n"
            "Create it once in App Store Connect:\n"
            "  1. https://appstoreconnect.apple.com/apps\n"
            "  2. Click + → New App\n"
            "  3. Platform: iOS\n"
            "  4. Name: Recall Audio\n"
            "  5. Bundle ID: com.extraram.LoopRecorder\n"
            "  6. SKU: recall-audio-ios-2026\n"
            "  7. User Access: Full Access\n\n"
            "Then re-run this script.\n"
        )
        return 2

    return upload_ipa(ipa)


if __name__ == "__main__":
    raise SystemExit(main())
