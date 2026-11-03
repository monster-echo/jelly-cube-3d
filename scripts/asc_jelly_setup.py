#!/usr/bin/env python3
"""一次性 ASC API 配置脚本：Jelly Cube 3D（app id 6829958415）。
由 GitHub Actions（workflow_dispatch）以 APPLE_API_* secrets 运行。幂等。
步骤: 截图上传(medium/iPad) → 内购 extra_types(非消耗, $2.99) → 定价/可用性。
"""
import base64, hashlib, json, os, sys, time, urllib.request, urllib.error
import jwt

KEY_ID = os.environ["APPLE_API_KEY_ID"]
ISSUER = os.environ["APPLE_API_ISSUER_ID"]
P8 = os.environ.get("APPLE_API_PRIVATE_KEY_PATH", "asc_key.p8")
APP = "6829958415"
VERSION = "1.0.0"
IAP_ID = "tech.zhongbei.jellycube3d.extra_types"
BASE = "https://api.appstoreconnect.apple.com/v1"
UPLOAD = "https://api.appstoreconnect.apple.com/v1"


def token():
    key = open(P8, "rb").read()
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 900}, key, algorithm="ES256",
                      headers={"kid": KEY_ID})


def call(method, path, body=None, raw=False, ctype="application/json", tries=4):
    for a in range(tries):
        data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
        req = urllib.request.Request(BASE + path if path.startswith("/") else path, data=data, method=method,
                                     headers={"Authorization": f"Bearer {token()}", "Content-Type": ctype})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                b = r.read()
                return r.status, (b if raw else (json.loads(b) if b else {}))
        except urllib.error.HTTPError as e:
            body_txt = e.read().decode(errors="replace")
            if e.code in (401, 403, 429, 500, 502, 503) and a < tries - 1:
                print(f"  transient {e.code}, retry..."); time.sleep(2); continue
            print(f"  HTTP {e.code} {method} {path}: {body_txt[:300]}")
            return e.code, {"error": body_txt[:500]}


def log(msg): print(msg, flush=True)


# ---------- 图片上传 ----------
def upload_image(image_path, relationships, kind="appScreenshots"):
    fn = os.path.basename(image_path)
    size = os.path.getsize(image_path)
    data = open(image_path, "rb").read()
    md5 = base64.b64encode(hashlib.md5(data).digest()).decode()
    s, b = call("POST", f"/{kind}", {"data": {"type": kind, "attributes": {"fileName": fn, "fileSize": size},
                 "relationships": relationships}})
    if s != 201:
        return s, b
    iid = b["data"]["id"]
    for op in b["data"]["attributes"]["uploadOperations"]:
        req = urllib.request.Request(op["url"], data=data, method="PUT",
                                     headers={k: v for k, v in op["requestHeaders"].items()})
        with urllib.request.urlopen(req, timeout=300) as r:
            pass
    s2, b2 = call("PATCH", f"/{kind}/{iid}",
                  {"data": {"type": kind, "id": iid, "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
    return s2, b2


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    shot = os.path.join(root, "store", "apple", "screenshots")

    # ---------- 1. 版本 ----------
    s, b = call("GET", f"/apps/{APP}/appStoreVersions?filter[versionString]={VERSION}&filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,WAITING_FOR_REVIEW,IN_REVIEW")
    vid = b["data"][0]["id"]; log(f"version {VERSION} id={vid}")

    # ---------- 2. 截图 ----------
    sets = {"APP_IPHONE_67": [os.path.join(shot, "6.9", f) for f in
             ["01-hero.png", "02-twist.png", "03-poke.png", "04-drop.png", "05-4x4.png", "06-extra-types.png"]],
            "APP_IPAD_PRO_3GEN_129": [os.path.join(shot, "ipad-13", "01-hero.png")]}
    s, b = call("GET", f"/appStoreVersions/{vid}/appScreenshotSets")
    existing = {x["attributes"]["screenshotDisplayType"]: x["id"] for x in b.get("data", [])}
    for stype, files in sets.items():
        sid = existing.get(stype)
        if not sid:
            s, b = call("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": stype},
                        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
            sid = b["data"]["id"] if s == 201 else None
            log(f"create set {stype}: {s} id={sid}")
        s, b = call("GET", f"/appScreenshotSets/{sid}/appScreenshots")
        have = len(b.get("data", []))
        if have >= len(files):
            log(f"{stype}: {have} shots already, skip"); continue
        for f in files[have:]:
            s, b = upload_image(f, {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}})
            log(f"upload {os.path.basename(f)} → {s}")
            if s not in (200, 201): print(json.dumps(b, ensure_ascii=False)[:400])

    # ---------- 3. 内购 extra_types（非消耗品, $2.99） ----------
    s, b = call("GET", f"/apps/{APP}/inAppPurchases?filter[inAppPurchaseType]=NON_CONSUMABLE")
    iap = next((x for x in b.get("data", []) if x["attributes"]["productId"] == IAP_ID), None)
    if not iap:
        s, b = call("POST", f"/apps/{APP}/inAppPurchases", {"data": {"type": "inAppPurchases",
                    "attributes": {"name": "Extra Cube Types", "productId": IAP_ID,
                                   "availableInAllCountries": True, "familySharable": False,
                                   "inAppPurchaseType": "NON_CONSUMABLE", "reviewNote": ""}}})
        log(f"create IAP: {s}")
        if s not in (200, 201): print(json.dumps(b, ensure_ascii=False)[:600]); sys.exit(2)
        iap = b["data"]
    iap_id = iap["id"]; log(f"IAP id={iap_id}")
    # 本地化
    s, b = call("GET", f"/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")
    locs = {x["attributes"]["locale"]: x["id"] for x in b.get("data", [])}
    if "en-US" not in locs:
        s, b = call("POST", f"/inAppPurchases/{iap_id}/inAppPurchaseLocalizations",
                    {"data": {"type": "inAppPurchaseLocalizations", "attributes": {
                        "locale": "en-US", "name": "Extra Cube Types",
                        "description": "Unlock 5×5 and 6×6 cubes, plus future extra cube types."}}})
        log(f"localization: {s}")
    # 价格: USA 定价点 Tier 3 ($2.99)
    s, b = call("GET", f"/inAppPurchases/{iap_id}/priceSchedules")
    if not b.get("data"):
        s, pp = call("GET", f"/apps/{APP}/inAppPurchasePricePoints?filter[territory]=USA&filter[priceTier]=3")
        pts = pp.get("data", [])
        if not pts:
            log("WARN: no price point found for USA tier 3"); print(json.dumps(pp)[:300])
        else:
            pp_id = pts[0]["id"]
            s, b = call("POST", f"/inAppPurchases/{iap_id}/priceSchedules",
                        {"data": {"type": "inAppPurchasePriceSchedules",
                                  "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                                                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                                                    "pricePoints": {"data": [{"type": "inAppPurchasePricePoints", "id": pp_id}]}}}})
            log(f"price schedule: {s}")
            if s not in (200, 201): print(json.dumps(b, ensure_ascii=False)[:600])
    # 审核截图
    s, b = call("GET", f"/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
    if not b.get("data"):
        s, b = upload_image(os.path.join(shot, "6.9", "06-extra-types.png"),
                            {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}}},
                            kind="appStoreReviewScreenshots")
        log(f"IAP review screenshot: {s}")
        if s not in (200, 201): print(json.dumps(b, ensure_ascii=False)[:400])

    log("DONE")


if __name__ == "__main__":
    main()
