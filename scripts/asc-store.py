#!/usr/bin/env python3
"""App Store Connect 새 버전 초안 만들기·이미지 교체·빌드 연결·심사 제출.

필요: `.secrets/asc.json` (key_id, issuer_id, key_path)
실행: uv run --with 'pyjwt[crypto]' python scripts/asc-store.py <명령> ...

  show                       현재 버전·문구·이미지·빌드 상태 (읽기 전용)
  draft <버전> <listing.md>   새 버전을 만들고 문구·이름·부제 입력
  screenshots <버전> <store/ios 폴더> <01_map,02_feed,...>
                             초안의 이미지를 iPhone 6.9인치·iPad 13인치 두 세트로 교체
  attach-build <버전>         처리가 끝난 최신 빌드를 초안에 연결
  submit <버전>               심사 제출 (공개로 이어지므로 개발자 확인 후에만)

submit을 빼면 어느 명령도 사용자에게 보이는 스토어를 바꾸지 않는다.
listing.md는 앱 저장소의 `mobile/store/listing.md` 표·절 이름을 읽는다.
"""

import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

ROOT = Path(__file__).resolve().parent.parent
APP_ID = "6751343880"  # 리뷰맵
EDITABLE = "PREPARE_FOR_SUBMISSION"
SCREENSHOT_SETS = [("APP_IPHONE_67", "iphone_69"), ("APP_IPAD_PRO_3GEN_129", "ipad_13")]


def token() -> str:
    cfg = json.loads((ROOT / ".secrets" / "asc.json").read_text())
    key = Path(cfg["key_path"]).expanduser()
    if not key.is_absolute():
        key = ROOT / key
    now = int(time.time())
    return jwt.encode(
        {"iss": cfg["issuer_id"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key.read_text(), algorithm="ES256", headers={"kid": cfg["key_id"]},
    )


def call(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> {e.code} {e.read().decode()[:1500]}") from None


def rel(kind: str, ident: str) -> dict:
    return {"data": {"type": kind, "id": ident}}


def versions() -> list[dict]:
    return call("GET", f"/v1/apps/{APP_ID}/appStoreVersions?limit=5")["data"]


def find_version(name: str) -> dict | None:
    return next((v for v in versions() if v["attributes"]["versionString"] == name), None)


def draft_version(name: str) -> dict:
    v = find_version(name)
    if v is None or v["attributes"]["appStoreState"] != EDITABLE:
        raise SystemExit(f"{name}: 편집 가능한 초안이 없음 (상태 {v and v['attributes']['appStoreState']})")
    return v


def korean_localization(version_id: str) -> dict:
    locs = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    return next(x for x in locs if x["attributes"]["locale"] == "ko")


def show() -> None:
    for info in call("GET", f"/v1/apps/{APP_ID}/appInfos")["data"]:
        for loc in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            a = loc["attributes"]
            print(f"appInfo {info['attributes'].get('appStoreState')} {a['locale']}: {a.get('name')} | {a.get('subtitle')}")
    vs = versions()
    for v in vs[:3]:
        print("버전", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
    latest = vs[0]
    loc = korean_localization(latest["id"])
    for key in ("promotionalText", "keywords", "whatsNew"):
        print(f"--{key}: {loc['attributes'].get(key)}")
    for s in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
        shots = call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]
        print("이미지", s["attributes"]["screenshotDisplayType"], [x["attributes"]["fileName"] for x in shots])
    build = call("GET", f"/v1/appStoreVersions/{latest['id']}/build").get("data")
    print("연결된 빌드:", build and build["attributes"]["version"])
    for b in call("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=3")["data"]:
        print("업로드된 빌드", b["attributes"]["version"], b["attributes"]["processingState"], b["attributes"]["uploadedDate"])


def draft(name: str, listing: Path) -> None:
    md = listing.read_text()
    store = md.split("## App Store")[1].split("## Google Play")[0]

    def row(label: str) -> str:
        return re.search(r"\| " + re.escape(label) + r" \| (.*?) \|", store).group(1)

    def section(title: str) -> str:
        return md.split(f"## {title}\n")[1].split("\n## ")[0].strip()

    v = find_version(name) or call("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": name, "releaseType": "AFTER_APPROVAL"},
        "relationships": {"app": rel("apps", APP_ID)},
    }})["data"]
    loc = korean_localization(v["id"])
    call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
        "type": "appStoreVersionLocalizations", "id": loc["id"],
        "attributes": {
            "description": section("설명 (App Store 설명 · Play 자세한 설명 공통)"),
            "keywords": row("키워드 (100)"),
            "promotionalText": row("프로모션 텍스트 (170)"),
            "whatsNew": section(f"새로운 기능 ({name})"),
            "supportUrl": row("지원 URL"),
            "marketingUrl": row("마케팅 URL"),
        },
    }})
    infos = call("GET", f"/v1/apps/{APP_ID}/appInfos")["data"]
    info = next(i for i in infos if i["attributes"].get("appStoreState") == EDITABLE)
    il = next(x for x in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
              if x["attributes"]["locale"] == "ko")
    call("PATCH", f"/v1/appInfoLocalizations/{il['id']}", {"data": {
        "type": "appInfoLocalizations", "id": il["id"],
        "attributes": {"name": row("앱 이름 (30)"), "subtitle": row("부제 (30)")},
    }})
    print(f"{name} 초안 문구 반영 (제출 안 함)")


def screenshots(name: str, root: Path, slides: list[str]) -> None:
    files = [root / folder / f"{s}.png" for _, folder in SCREENSHOT_SETS for s in slides]
    missing = [str(f) for f in files if not f.is_file()]
    if missing:
        raise SystemExit("없는 파일: " + ", ".join(missing))
    loc = korean_localization(draft_version(name)["id"])
    for s in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
        call("DELETE", f"/v1/appScreenshotSets/{s['id']}")  # 초안의 이미지만. 공개 중인 버전은 그대로
    for display, folder in SCREENSHOT_SETS:
        ss = call("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
            "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", loc["id"])},
        }})["data"]
        for slide in slides:
            data = (root / folder / f"{slide}.png").read_bytes()
            shot = call("POST", "/v1/appScreenshots", {"data": {
                "type": "appScreenshots", "attributes": {"fileName": f"{slide}.png", "fileSize": len(data)},
                "relationships": {"appScreenshotSet": rel("appScreenshotSets", ss["id"])},
            }})["data"]
            for op in shot["attributes"]["uploadOperations"]:
                req = urllib.request.Request(
                    op["url"], method=op["method"], data=data[op["offset"]:op["offset"] + op["length"]],
                    headers={h["name"]: h["value"] for h in op["requestHeaders"]})
                urllib.request.urlopen(req, timeout=120).read()
            call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
                "type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
            }})
        time.sleep(20)
        got = call("GET", f"/v1/appScreenshotSets/{ss['id']}/appScreenshots")["data"]
        print(display, [(x["attributes"]["fileName"], x["attributes"]["assetDeliveryState"]["state"]) for x in got])


def attach_build(name: str) -> None:
    v = draft_version(name)
    builds = call("GET", f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]={name}"
                         "&sort=-uploadedDate&limit=1")["data"]
    if not builds:
        raise SystemExit(f"{name} 빌드가 아직 없음")
    b = builds[0]
    state = b["attributes"]["processingState"]
    if state != "VALID":
        raise SystemExit(f"빌드 {b['attributes']['version']} 처리 상태 {state} (VALID가 될 때까지 10~30분)")
    if b["attributes"].get("usesNonExemptEncryption") is None:
        call("PATCH", f"/v1/builds/{b['id']}", {"data": {
            "type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}})
    call("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", rel("builds", b["id"]))
    print(f"{name} 초안에 빌드 {b['attributes']['version']} 연결")


def submit(name: str) -> None:
    v = draft_version(name)
    if not call("GET", f"/v1/appStoreVersions/{v['id']}/build").get("data"):
        raise SystemExit("연결된 빌드가 없음 (attach-build 먼저)")
    pending = call("GET", f"/v1/reviewSubmissions?filter[app]={APP_ID}&filter[platform]=IOS"
                          "&filter[state]=READY_FOR_REVIEW")["data"]
    sub = pending[0] if pending else call("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": rel("apps", APP_ID)},
    }})["data"]
    if not call("GET", f"/v1/reviewSubmissions/{sub['id']}/items")["data"]:
        call("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": rel("reviewSubmissions", sub["id"]),
                "appStoreVersion": rel("appStoreVersions", v["id"]),
            }}})
    done = call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {
        "type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print(f"{name} 심사 제출: {done['data']['attributes']['state']}")


def main() -> None:
    commands = {
        "show": (0, lambda a: show()),
        "draft": (2, lambda a: draft(a[0], Path(a[1]))),
        "screenshots": (3, lambda a: screenshots(a[0], Path(a[1]), a[2].split(","))),
        "attach-build": (1, lambda a: attach_build(a[0])),
        "submit": (1, lambda a: submit(a[0])),
    }
    args = sys.argv[1:]
    if not args or args[0] not in commands or len(args) - 1 != commands[args[0]][0]:
        raise SystemExit(__doc__)
    commands[args[0]][1](args[1:])


if __name__ == "__main__":
    main()
