#!/usr/bin/env python3
"""세 앱(리뷰맵·돌려받엔·라익찍스) 출시·광고·모니터링 상태를 한 번에 확인한다.

사용: infra 저장소 루트에서 `python3 scripts/app-status.py`
필요: kubectl(prod 컨텍스트), PyJWT(`pip install pyjwt cryptography`), `.secrets/asc.json`
      ({"key_id", "issuer_id", "key_path"}: App Store Connect API 키, 위치는 .secrets/README.md)

읽기만 한다. 아무것도 바꾸지 않는다.
"""

import json
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APPS = [
    # 이름, App Store ID, Play 패키지
    ("리뷰맵", "6751343880", "com.reviewmaps.mobile"),
    ("돌려받엔", "6835096650", "com.woohalabs.yenback"),
    ("라익찍스", "6836852971", "com.woohalabs.likezzix"),
]
PROM_PORT = 19090
ADMOB_SNIPPET = """
import json, urllib.request
src = open('/app/exporter.py').read().replace('if __name__ == "__main__":', 'if False:')
ns = {}
exec(compile(src, '/app/exporter.py', 'exec'), ns)
h = ns['USER_TOKEN'].header()
d = json.load(urllib.request.urlopen(urllib.request.Request(
    'https://admob.googleapis.com/v1beta/accounts/pub-8516861197467665/apps', headers=h)))
for a in d.get('apps', []):
    li = a.get('linkedAppInfo') or {}
    mi = a.get('manualAppInfo') or {}
    name = li.get('displayName') or mi.get('displayName')
    print(f"  {a.get('platform'):8} {name[:24]:24} 스토어={li.get('appStoreId') or '-':24} 승인={a.get('appApprovalState')}")
"""


def section(title):
    print(f"\n## {title}")


def get_json(url, headers=None, timeout=20):
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers or {}), timeout=timeout) as r:
        return json.load(r)


def app_store_connect():
    section("App Store Connect 버전 상태")
    cfg_path = ROOT / ".secrets" / "asc.json"
    try:
        import jwt  # noqa: PLC0415
    except ImportError:
        print("  PyJWT 없음: pip install pyjwt cryptography")
        return
    if not cfg_path.exists():
        print(f"  {cfg_path} 없음 (.secrets/README.md 참고)")
        return
    cfg = json.loads(cfg_path.read_text())
    key = (ROOT / cfg["key_path"]).read_text()
    now = int(time.time())
    token = jwt.encode(
        {"iss": cfg["issuer_id"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": cfg["key_id"]},
    )
    for name, app_id, _ in APPS:
        url = (f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/appStoreVersions"
               "?limit=2&fields[appStoreVersions]=versionString,appStoreState,releaseType")
        try:
            data = get_json(url, {"Authorization": f"Bearer {token}"})
            states = ", ".join(
                f"{v['attributes']['versionString']} {v['attributes']['appStoreState']}" for v in data["data"]
            )
            print(f"  {name}: {states}")
        except urllib.error.HTTPError as e:
            print(f"  {name}: HTTP {e.code}")


def stores():
    section("스토어 검색 (App Store 한국·미국 / Play 공개 페이지)")
    for name, app_id, package in APPS:
        found = []
        for country in ("kr", "us"):
            d = get_json(f"https://itunes.apple.com/lookup?id={app_id}&country={country}")
            found.append(f"{country}={d['results'][0]['version'] if d['resultCount'] else '없음'}")
        try:
            req = urllib.request.Request(
                f"https://play.google.com/store/apps/details?id={package}&hl=ko&gl=KR",
                headers={"User-Agent": "Mozilla/5.0"})
            play = urllib.request.urlopen(req, timeout=20).status
        except urllib.error.HTTPError as e:
            play = e.code
        print(f"  {name}: App Store {' '.join(found)} | Play {'공개' if play == 200 else f'비공개({play})'}")


def admob():
    section("AdMob 앱 (스토어 연결·승인) - 수집기 Pod의 AdMob 토큰 사용")
    pod = subprocess.run(
        ["kubectl", "-n", "monitoring", "get", "pod", "-l", "app.kubernetes.io/name=app-metrics-exporter",
         "-o", "jsonpath={.items[0].metadata.name}"], capture_output=True, text=True).stdout
    if not pod:
        print("  수집기 Pod를 찾지 못함")
        return
    out = subprocess.run(["kubectl", "-n", "monitoring", "exec", "-i", pod, "--", "python3", "-"],
                         input=ADMOB_SNIPPET, capture_output=True, text=True)
    print(out.stdout.rstrip() or f"  실패: {out.stderr.strip()[:200]}")


def prometheus():
    section("Prometheus (발생 중 알림, 광고 수입, 잔존율, 수집기)")
    proc = None
    with socket.socket() as s:
        busy = s.connect_ex(("127.0.0.1", PROM_PORT)) == 0
    if not busy:
        proc = subprocess.Popen(
            ["kubectl", "-n", "monitoring", "port-forward", "svc/kube-prometheus-stack-prometheus",
             f"{PROM_PORT}:9090"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(4)
    queries = {
        "발생 중 알림": 'ALERTS{alertstate="firing", severity!~"none|info"}',
        "광고 수입 USD (7일/이전 7일/28일)": 'sum by (app, window)(app_ad_revenue_usd{ad_unit="전체", window=~"7d|prev7d|28d"})',
        "활성 사용자 (7일)": 'app_active_users{window="7d"}',
        "신규 사용자 잔존율": "app_retention_ratio",
        "잔존율 분모(신규 사용자)": "app_retention_cohort_users",
        "Google Ads 비용·신규 (7일)": 'app_ads_cost{window="7d", campaign="전체"} or app_ads_new_users{window="7d"}',
        "AdMob 승인 (3=준비됨, 2=검토 중, 1=조치 필요)": "app_admob_approval",
        "수집 실패": "app_metrics_collect_ok == 0",
    }
    try:
        for title, q in queries.items():
            d = get_json(f"http://127.0.0.1:{PROM_PORT}/api/v1/query?query={urllib.parse.quote(q)}")
            rows = d["data"]["result"]
            print(f"  [{title}]" + ("" if rows else " 없음"))
            for r in rows:
                labels = {k: v for k, v in r["metric"].items()
                          if k not in ("__name__", "job", "namespace", "service", "prometheus", "alertstate")}
                print(f"    {labels} {round(float(r['value'][1]), 4)}")
    except OSError as e:
        print(f"  Prometheus 연결 실패: {e}")
    finally:
        if proc:
            proc.terminate()


def argocd():
    section("ArgoCD (Synced/Healthy 아닌 앱)")
    out = subprocess.run(
        ["kubectl", "-n", "argocd", "get", "applications", "--no-headers", "-o",
         "custom-columns=N:.metadata.name,S:.status.sync.status,H:.status.health.status"],
        capture_output=True, text=True).stdout
    bad = [line for line in out.splitlines() if not ("Synced" in line and "Healthy" in line)]
    print("\n".join(f"  {line}" for line in bad) if bad else "  모두 Synced/Healthy")


if __name__ == "__main__":
    for step in (app_store_connect, stores, admob, prometheus, argocd):
        try:
            step()
        except Exception as e:  # noqa: BLE001 - 한 항목 실패가 나머지 확인을 막지 않게
            print(f"  {step.__name__} 실패: {e}")
    sys.exit(0)
