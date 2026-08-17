#!/usr/bin/env python3
"""Complete Recall Audio App Store submission prep via App Store Connect API."""

from __future__ import annotations

import json
import mimetypes
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

KEY_ID = "D8WLYCSLX9"
ISSUER_ID = "777189c3-31c7-4d39-9135-fa3d520d3162"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys/AuthKey_D8WLYCSLX9.p8"
APP_ID = "6802156643"
VERSION_ID = "abdc9e2e-7626-4a25-8b5a-6d980f033be6"
BUILD_ID = "711a95b5-16b0-418f-aa0a-ea938bd27a2c"
AGE_RATING_ID = "bb163ffd-268c-4159-ba4f-b8d0eceeb65c"
PRIVACY_URL = (
    "https://github.com/pinkpurplered/extra_ram_for_my_brain/blob/main/docs/PRIVACY_POLICY.md"
)
SCREENSHOT = Path(__file__).resolve().parents[1] / (
    "fastlane/metadata/en-US/screenshots/iPhone 6.7 Display/01_main.png"
)


def token() -> str:
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


def api(method: str, path: str, body: dict | None = None) -> tuple[int, object]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com{path}", data=data, method=method
    )
    req.add_header("Authorization", f"Bearer {token()}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode()


def upload_screenshot(loc_id: str) -> None:
    if not SCREENSHOT.exists():
        print(f"Missing screenshot: {SCREENSHOT}")
        return

    status, sets = api(
        "GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets"
    )
    set_id = None
    if status == 200:
        for item in sets.get("data", []):
            if item["attributes"].get("screenshotDisplayType") == "APP_IPHONE_67":
                set_id = item["id"]
                break

    if not set_id:
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": loc_id,
                        }
                    }
                },
            }
        }
        status, result = api("POST", "/v1/appScreenshotSets", body)
        print("Create screenshot set:", status)
        if status not in (200, 201):
            print(result)
            return
        set_id = result["data"]["id"]

    image = SCREENSHOT.read_bytes()
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": SCREENSHOT.name,
                "fileSize": len(image),
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            },
        }
    }
    status, result = api("POST", "/v1/appScreenshots", body)
    print("Create screenshot upload slot:", status)
    if status not in (200, 201):
        print(result)
        return

    screenshot_id = result["data"]["id"]
    ops = result["data"]["attributes"].get("uploadOperations", [])
    if not ops:
        print("No upload operations returned")
        return

    op = ops[0]
    upload_req = urllib.request.Request(op["url"], data=image, method=op["method"])
    for header in op.get("requestHeaders", []):
        upload_req.add_header(header["name"], header["value"])
    mime = mimetypes.guess_type(SCREENSHOT.name)[0] or "image/png"
    upload_req.add_header("Content-Type", mime)
    with urllib.request.urlopen(upload_req) as resp:
        print("Uploaded screenshot bytes:", resp.status)

    commit = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {"uploaded": True},
        }
    }
    status, result = api("PATCH", f"/v1/appScreenshots/{screenshot_id}", commit)
    print("Commit screenshot:", status, result if isinstance(result, str) else "")


def main() -> int:
    print("=== Link build ===")
    body = {
        "data": {
            "type": "appStoreVersions",
            "id": VERSION_ID,
            "relationships": {
                "build": {"data": {"type": "builds", "id": BUILD_ID}}
            },
        }
    }
    print(api("PATCH", f"/v1/appStoreVersions/{VERSION_ID}", body))

    print("\n=== Privacy policy URL ===")
    _, infos = api("GET", f"/v1/apps/{APP_ID}/appInfos")
    info_id = infos["data"][0]["id"]
    _, info_locs = api("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    info_loc_id = info_locs["data"][0]["id"]
    body = {
        "data": {
            "type": "appInfoLocalizations",
            "id": info_loc_id,
            "attributes": {"privacyPolicyUrl": PRIVACY_URL},
        }
    }
    print(api("PATCH", f"/v1/appInfoLocalizations/{info_loc_id}", body))

    print("\n=== Age rating ===")
    body = {
        "data": {
            "type": "ageRatingDeclarations",
            "id": AGE_RATING_ID,
            "attributes": {
                "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                "contests": "NONE",
                "gambling": False,
                "gamblingSimulated": "NONE",
                "gunsOrOtherWeapons": "NONE",
                "medicalOrTreatmentInformation": "NONE",
                "profanityOrCrudeHumor": "NONE",
                "sexualContentGraphicAndNudity": "NONE",
                "sexualContentOrNudity": "NONE",
                "horrorOrFearThemes": "NONE",
                "matureOrSuggestiveThemes": "NONE",
                "violenceCartoonOrFantasy": "NONE",
                "violenceRealistic": "NONE",
                "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                "unrestrictedWebAccess": False,
                "kidsAgeBand": None,
            },
        }
    }
    print(api("PATCH", f"/v1/ageRatingDeclarations/{AGE_RATING_ID}", body))

    print("\n=== Review contact ===")
    body = {
        "data": {
            "type": "appStoreReviewDetails",
            "attributes": {
                "contactFirstName": "pinkred",
                "contactLastName": "purple",
                "contactPhone": "+85200000000",
                "contactEmail": "tsy0110@icloud.com",
                "notes": (
                    "Recall Audio records audio in the background into a rolling 1-hour "
                    "buffer. Save 1-60 minute clips locally. Requires microphone on a "
                    "physical iPhone. No login or network required for core features."
                ),
            },
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": VERSION_ID}
                }
            },
        }
    }
    print(api("POST", "/v1/appStoreReviewDetails", body))

    print("\n=== Screenshots ===")
    _, locs = api("GET", f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations")
    loc_id = locs["data"][0]["id"]
    upload_screenshot(loc_id)

    print("\n=== Build status ===")
    _, builds = api("GET", f"/v1/builds/{BUILD_ID}")
    print("processingState:", builds["data"]["attributes"]["processingState"])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
