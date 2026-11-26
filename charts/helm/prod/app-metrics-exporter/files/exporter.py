"""앱 지표 수집기: GA4, Firebase Remote Config, 스토어, app-ads.txt → Prometheus.

표준 라이브러리만 사용한다(이미지 빌드 없이 ConfigMap으로 마운트).
인증은 GKE Workload Identity 메타데이터 토큰이며 키 파일을 쓰지 않는다.
설명 문서: claudedocs/app-metrics-monitoring.md
"""

import json
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN_URL = (
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
    "?scopes=https://www.googleapis.com/auth/analytics.readonly,"
    "https://www.googleapis.com/auth/cloud-platform"
)
# GA4 기간: 이름 → (시작, 끝). 오늘은 집계 중이라 항상 어제까지만 본다.
WINDOWS = {
    "1d": ("yesterday", "yesterday"),
    "7d": ("7daysAgo", "yesterday"),
    "prev7d": ("14daysAgo", "8daysAgo"),
    "28d": ("28daysAgo", "yesterday"),
}
EVENTS = [
    "first_open", "app_remove", "app_exception", "ad_impression", "ad_click",
    "app_open_ad_loaded", "app_open_ad_shown", "app_open_ad_load_failed", "app_open_ad_show_failed",
    "native_ad_loaded", "native_ad_load_failed", "banner_ad_load_failed",
]
USER_AGENT = "Mozilla/5.0 (compatible; app-metrics-exporter)"

HELP = {
    "app_active_users": "GA4 활성 사용자 수",
    "app_new_users": "GA4 신규 사용자 수",
    "app_sessions": "GA4 세션 수",
    "app_session_seconds": "GA4 평균 세션 시간(초)",
    "app_crash_free_users_ratio": "GA4 비정상 종료를 겪지 않은 사용자 비율",
    "app_crash_affected_users": "GA4 비정상 종료를 겪은 사용자 수",
    "app_version_users": "GA4 앱 버전별 활성 사용자 수 (최근 7일)",
    "app_events": "GA4 이벤트 수",
    "app_ad_impressions": "AdMob 광고 노출 수 (GA4 연동)",
    "app_ad_clicks": "AdMob 광고 클릭 수 (GA4 연동)",
    "app_ad_revenue_usd": "AdMob 예상 광고 수입 (USD, GA4 연동)",
    "app_ads_cost": "Google Ads 비용 (USD, GA4 연동)",
    "app_ads_clicks": "Google Ads 클릭 수 (GA4 연동)",
    "app_ads_impressions": "Google Ads 노출 수 (GA4 연동)",
    "app_ads_new_users": "첫 유입이 유료 광고(Paid/Google Ads)인 신규 사용자 수",
    "app_remote_config_version": "Remote Config 템플릿 버전 번호",
    "app_remote_config_updated_timestamp_seconds": "Remote Config 마지막 변경 시각",
    "app_remote_config_value": "Remote Config 값 (참/거짓은 1/0, 숫자는 그대로)",
    "app_remote_config_info": "Remote Config 문자열 값 (값은 항상 1)",
    "app_version_number": "버전을 숫자로 바꾼 값 (x*1000000+y*1000+z)",
    "app_version_info": "버전 문자열 (값은 항상 1)",
    "app_store_listed": "스토어에 앱이 공개되어 있으면 1",
    "app_store_expected": "스토어에 공개되어 있어야 하는 앱이면 1",
    "app_store_rating": "App Store 평점",
    "app_store_rating_count": "App Store 평점 수",
    "app_ads_txt_ok": "app-ads.txt가 200, text/plain, 게시자 줄 포함이면 1",
    "app_daily": "일별 값 (최근 28일, date 라벨 YYYY-MM-DD, metric 라벨로 구분)",
    "app_store_stage": "스토어 단계 (3 공개, 2 심사 중, 1 테스트 중, 0 미출시, -1 공개여야 하는데 안 보임)",
    "app_outdated_users_ratio": "최근 7일 사용자 중 최신 버전(스토어 또는 Remote Config latest)보다 낮은 버전 비율",
    "app_known_issue": "이미 원인을 아는 알림 (값은 항상 1, note 라벨에 설명)",
    "app_admob_approval": "AdMob 앱 승인 상태 (3 준비됨, 2 검토 중, 1 조치 필요, 0 알 수 없음)",
    "app_admob_requests": "AdMob 광고 요청 수",
    "app_admob_matched": "AdMob 매칭된 요청 수",
    "app_admob_impressions": "AdMob 노출 수",
    "app_admob_clicks": "AdMob 클릭 수",
    "app_admob_earnings_usd": "AdMob 예상 수입 (USD)",
    "app_metrics_collect_ok": "마지막 수집 성공 여부",
    "app_metrics_last_success_timestamp_seconds": "마지막 수집 성공 시각",
}


def version_number(text):
    """'2.10.1' → 2010001. 숫자 세 자리 형식이 아니면 None."""
    match = re.fullmatch(r"(\d+)(?:\.(\d+))?(?:\.(\d+))?", (text or "").strip())
    if not match:
        return None
    major, minor, patch = (int(part or 0) for part in match.groups())
    return major * 1_000_000 + minor * 1_000 + patch


def escape(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def render(samples):
    """[(이름, 라벨 dict, 값)] → Prometheus 텍스트."""
    lines, seen = [], set()
    for name, labels, value in sorted(samples, key=lambda s: (s[0], sorted(s[1].items()))):
        if name not in seen:
            seen.add(name)
            lines.append(f"# HELP {name} {HELP.get(name, name)}")
            lines.append(f"# TYPE {name} gauge")
        text = ",".join(f'{key}="{escape(val)}"' for key, val in sorted(labels.items()))
        lines.append(f"{name}{{{text}}} {value}")
    return "\n".join(lines) + "\n"


def fetch(url, body=None, headers=None, timeout=30):
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"User-Agent": USER_AGENT, **(headers or {})},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.status, response.headers, response.read()


# 수집원끼리 공유하는 최신 버전 기준값 {(앱, 플랫폼): {"store": n, "rc_latest": n}}
REFERENCE = {}
STAGES = {"released": 3, "review": 2, "testing": 1, "none": 0}


def remember(samples):
    """버전 표본을 REFERENCE에 기록한다 (구버전 비율 계산용)."""
    for name, labels, value in samples:
        if name == "app_version_number" and labels.get("kind") in ("store", "rc_latest"):
            REFERENCE.setdefault((labels["app"], labels["platform"]), {})[labels["kind"]] = value
    return samples


def outdated_ratio(rows, reference):
    """[(버전 문자열, 사용자 수)] 중 기준보다 낮은 버전 사용자 비율. 계산할 수 없으면 None."""
    total = sum(users for _, users in rows)
    if not reference or total <= 0:
        return None
    old = sum(users for version, users in rows if (version_number(version) or 0) < reference)
    return old / total


def daily_label(text):
    """GA4 date(YYYYMMDD) → YYYY-MM-DD"""
    return f"{text[:4]}-{text[4:6]}-{text[6:8]}"


class Token:
    def __init__(self):
        self.value, self.expires = "", 0.0

    def header(self):
        if time.time() > self.expires - 120:
            _, _, raw = fetch(TOKEN_URL, headers={"Metadata-Flavor": "Google"})
            data = json.loads(raw)
            self.value = data["access_token"]
            self.expires = time.time() + data["expires_in"]
        return {"Authorization": "Bearer " + self.value, "Content-Type": "application/json"}


TOKEN = Token()


def ga4_report(prop, dims, metrics, window, event_filter=None):
    start, end = WINDOWS[window]
    body = {
        "dateRanges": [{"startDate": start, "endDate": end}],
        "dimensions": [{"name": d} for d in dims],
        "metrics": [{"name": m} for m in metrics],
        "limit": 250,
    }
    if event_filter:
        body["dimensionFilter"] = {
            "filter": {"fieldName": "eventName", "inListFilter": {"values": event_filter}}
        }
    _, _, raw = fetch(
        f"https://analyticsdata.googleapis.com/v1beta/properties/{prop}:runReport", body, TOKEN.header()
    )
    return [
        (
            [d["value"] for d in row.get("dimensionValues", [])],
            [float(m["value"]) for m in row["metricValues"]],
        )
        for row in json.loads(raw).get("rows", [])
    ]


PAID_SOURCES = ("google / cpc", "google / paid")


def retention_samples(name, platforms, rows):
    """GA4 코호트 행 → 유입(광고/그 외)·플랫폼별 1일·7일 잔존율.

    rows: ([cohort, nthDay, platform, source], [activeUsers, totalUsers]).
    코호트 크기는 0일째 사용자 수, 잔존은 n일째 다시 쓴 사용자 수. 0일째가 없으면 내보내지 않는다.
    """
    base, kept = {}, {}
    for (cohort, nth, platform, source), (active, _total) in rows:
        platform = platform.lower()
        if platform not in platforms:
            continue
        group = "ads" if source.lower() in PAID_SOURCES else "other"
        day = int(nth)
        if day == 0:
            base[(platform, group)] = base.get((platform, group), 0) + active
        elif day in (1, 7):
            kept[(platform, group, day)] = kept.get((platform, group, day), 0) + active
    out = []
    for (platform, group), users in base.items():
        labels = {"app": name, "platform": platform, "source": group}
        out.append(("app_retention_cohort_users", labels, users))
        for day in (1, 7):
            ratio = kept.get((platform, group, day), 0) / users if users else 0
            out.append(("app_retention_ratio", dict(labels, day=str(day)), ratio))
    return out


def ga4_cohort_rows(prop, today):
    """8~28일 전에 처음 들어온 사용자의 일별 코호트(0~7일째)."""
    cohorts = [
        {"name": f"d{k}", "dimension": "firstSessionDate",
         "dateRange": {"startDate": str(today - timedelta(days=k)), "endDate": str(today - timedelta(days=k))}}
        for k in range(8, 29)
    ]
    body = {
        "dimensions": [{"name": d} for d in ("cohort", "cohortNthDay", "platform", "firstUserSourceMedium")],
        "metrics": [{"name": "cohortActiveUsers"}, {"name": "cohortTotalUsers"}],
        "cohortSpec": {"cohorts": cohorts, "cohortsRange": {"granularity": "DAILY", "startOffset": 0, "endOffset": 7}},
        "limit": 10000,
    }
    _, _, raw = fetch(
        f"https://analyticsdata.googleapis.com/v1beta/properties/{prop}:runReport", body, TOKEN.header()
    )
    return [
        ([d["value"] for d in row["dimensionValues"]], [float(m["value"]) for m in row["metricValues"]])
        for row in json.loads(raw).get("rows", [])
    ]


def collect_ga4(app):
    prop, name, out = app["ga4Property"], app["name"], []
    platforms = app["platforms"]

    for window in ("1d", "7d", "prev7d", "28d"):
        rows = ga4_report(
            prop, ["platform"],
            ["activeUsers", "newUsers", "sessions", "averageSessionDuration", "crashAffectedUsers", "crashFreeUsersRate"],
            window,
        )
        found = {dims[0].lower(): vals for dims, vals in rows}
        for platform in platforms:
            users, new, sessions, seconds, crashed, free = found.get(platform, [0, 0, 0, 0, 0, 0])
            labels = {"app": name, "platform": platform, "window": window}
            out += [
                ("app_active_users", labels, users),
                ("app_new_users", labels, new),
                ("app_sessions", labels, sessions),
                ("app_session_seconds", labels, seconds),
            ]
            # Crashlytics가 없는 앱은 GA4가 항상 100%로 보여 오해를 주고,
            # 사용자가 없으면 비율이 0%로 보여 오탐이 되므로 내보내지 않는다
            if app.get("crashlytics") and users > 0:
                out += [
                    ("app_crash_affected_users", labels, crashed),
                    ("app_crash_free_users_ratio", labels, free),
                ]

        # 광고 수입: 광고 단위별. 노출이 없는 (not set) 행은 제외
        ads = ga4_report(
            prop, ["platform", "adUnitName"],
            ["publisherAdImpressions", "publisherAdClicks", "totalAdRevenue"], window,
        )
        totals = {platform: [0.0, 0.0, 0.0] for platform in platforms}
        for (platform, unit), vals in ads:
            platform = platform.lower()
            if platform not in totals:
                continue
            totals[platform] = [a + b for a, b in zip(totals[platform], vals)]
            if unit != "(not set)":
                labels = {"app": name, "platform": platform, "window": window, "ad_unit": unit}
                out += [
                    ("app_ad_impressions", labels, vals[0]),
                    ("app_ad_clicks", labels, vals[1]),
                    ("app_ad_revenue_usd", labels, vals[2]),
                ]
        for platform, vals in totals.items():
            labels = {"app": name, "platform": platform, "window": window, "ad_unit": "전체"}
            out += [
                ("app_ad_impressions", labels, vals[0]),
                ("app_ad_clicks", labels, vals[1]),
                ("app_ad_revenue_usd", labels, vals[2]),
            ]

        events = ga4_report(prop, ["platform", "eventName"], ["eventCount"], window, EVENTS)
        counted = {(p.lower(), e): vals[0] for (p, e), vals in events}
        for platform in platforms:
            for event in EVENTS:
                labels = {"app": name, "platform": platform, "window": window, "event": event}
                out.append(("app_events", labels, counted.get((platform, event), 0)))

        if app.get("googleAds"):
            # 비용·클릭·노출이 하나도 없으면 GA4는 행을 돌려주지 않는다 → 0으로 채운다
            spend = ga4_report(
                prop, ["sessionGoogleAdsCampaignName"],
                ["advertiserAdCost", "advertiserAdClicks", "advertiserAdImpressions"], window,
            )
            total = [0.0, 0.0, 0.0]
            for (campaign,), vals in spend:
                total = [a + b for a, b in zip(total, vals)]
                if campaign != "(not set)":
                    labels = {"app": name, "window": window, "campaign": campaign}
                    out += [
                        ("app_ads_cost", labels, vals[0]),
                        ("app_ads_clicks", labels, vals[1]),
                        ("app_ads_impressions", labels, vals[2]),
                    ]
            labels = {"app": name, "window": window, "campaign": "전체"}
            out += [
                ("app_ads_cost", labels, total[0]),
                ("app_ads_clicks", labels, total[1]),
                ("app_ads_impressions", labels, total[2]),
            ]
            paid = ga4_report(prop, ["firstUserSourceMedium"], ["newUsers"], window)
            count = sum(vals[0] for (source,), vals in paid if source.lower() in PAID_SOURCES)
            out.append(("app_ads_new_users", {"app": name, "window": window}, count))

    out += retention_samples(name, platforms, ga4_cohort_rows(prop, datetime.now(KST).date()))

    daily_metrics = ["activeUsers", "newUsers"] + (["crashFreeUsersRate"] if app.get("crashlytics") else [])
    names = {"activeUsers": "active_users", "newUsers": "new_users", "crashFreeUsersRate": "crash_free_users_ratio"}
    for (day, platform), vals in ga4_report(prop, ["date", "platform"], daily_metrics, "28d"):
        platform = platform.lower()
        if platform not in platforms:
            continue
        for metric, value in zip(daily_metrics, vals):
            labels = {"app": name, "platform": platform, "date": daily_label(day),
                      "metric": names[metric], "series": f"{name} {platform}"}
            out.append(("app_daily", labels, value))

    newest, by_platform = {}, {}
    for (platform, version), vals in ga4_report(prop, ["platform", "appVersion"], ["activeUsers"], "7d"):
        platform = platform.lower()
        if platform not in platforms:
            continue
        out.append(("app_version_users", {"app": name, "platform": platform, "version": version}, vals[0]))
        by_platform.setdefault(platform, []).append((version, vals[0]))
        number = version_number(version)
        if number is not None:
            newest[platform] = max(newest.get(platform, 0), number)
    for platform, number in newest.items():
        out.append(("app_version_number", {"app": name, "platform": platform, "kind": "seen"}, number))
    for platform, rows in by_platform.items():
        ref = REFERENCE.get((name, platform), {})
        ratio = outdated_ratio(rows, ref.get("store") or ref.get("rc_latest"))
        if ratio is not None:
            out.append(("app_outdated_users_ratio", {"app": name, "platform": platform}, ratio))
    return out


def collect_remote_config(app):
    name, project = app["name"], app["firebaseProject"]
    _, _, raw = fetch(
        f"https://firebaseremoteconfig.googleapis.com/v1/projects/{project}/remoteConfig", headers=TOKEN.header()
    )
    return remember(remote_config_samples(name, json.loads(raw), app["platforms"]))


def remote_config_samples(name, template, platforms):
    values = dict(template.get("parameters", {}))
    for group in template.get("parameterGroups", {}).values():
        values.update(group.get("parameters", {}))
    values = {key: p.get("defaultValue", {}).get("value", "") for key, p in values.items()}

    out, labels = [], {"app": name}
    version = template.get("version", {})
    out.append(("app_remote_config_version", labels, int(version.get("versionNumber", 0))))
    if version.get("updateTime"):
        stamp = datetime.fromisoformat(version["updateTime"].replace("Z", "+00:00")).timestamp()
        out.append(("app_remote_config_updated_timestamp_seconds", labels, stamp))
    for key, value in values.items():
        if value in ("true", "false"):
            out.append(("app_remote_config_value", {**labels, "key": key}, int(value == "true")))
        elif re.fullmatch(r"-?\d+(\.\d+)?", value):
            out.append(("app_remote_config_value", {**labels, "key": key}, float(value)))
        out.append(("app_remote_config_info", {**labels, "key": key, "value": value}, 1))

    for platform in platforms:
        for kind, key in (("rc_latest", "latest_version"), ("rc_min", "min_version")):
            text = values.get(f"{platform}_{key}", "")
            # 리뷰맵은 force_update가 꺼져 있으면 min_version이 적용되지 않는다
            if kind == "rc_min" and values.get(f"{platform}_force_update") == "false":
                text = "0.0.0"
            number = version_number(text)
            if number is not None:
                out.append(("app_version_number", {**labels, "platform": platform, "kind": kind}, number))
                out.append(("app_version_info", {**labels, "platform": platform, "kind": kind, "version": text}, 1))
    return out


def collect_stores(app):
    name, out = app["name"], []
    ios, android = app.get("appStoreId"), app.get("playPackage")
    if ios:
        _, _, raw = fetch(f"https://itunes.apple.com/lookup?id={ios}&country=kr")
        results = json.loads(raw).get("results", [])
        labels = {"app": name, "platform": "ios"}
        out.append(("app_store_listed", labels, int(bool(results))))
        out.append(("app_store_expected", labels, int("ios" in app.get("released", []))))
        out.append(("app_store_stage", labels, store_stage(app, "ios", bool(results))))
        if results:
            info = results[0]
            out.append(("app_store_rating", labels, info.get("averageUserRating", 0)))
            out.append(("app_store_rating_count", labels, info.get("userRatingCount", 0)))
            number = version_number(info.get("version"))
            if number is not None:
                out.append(("app_version_number", {**labels, "kind": "store"}, number))
                out.append(("app_version_info", {**labels, "kind": "store", "version": info["version"]}, 1))
    if android:
        try:
            status, _, _ = fetch(f"https://play.google.com/store/apps/details?id={android}&hl=ko&gl=KR")
        except urllib.error.HTTPError as error:
            # 404는 "공개 안 됨". 그 밖의 오류는 수집 실패로 처리해 잘못된 0을 남기지 않는다
            if error.code != 404:
                raise
            status = 404
        labels = {"app": name, "platform": "android"}
        out.append(("app_store_listed", labels, int(status == 200)))
        out.append(("app_store_expected", labels, int("android" in app.get("released", []))))
        out.append(("app_store_stage", labels, store_stage(app, "android", status == 200)))
    for issue in app.get("knownIssues", []):
        labels = {"app": name, "alertname": issue["alertname"], "note": issue["note"]}
        out.append(("app_known_issue", labels, 1))
    return remember(out)


def store_stage(app, platform, listed):
    """공개 여부와 설정(released, stage)으로 스토어 단계를 정한다."""
    if listed:
        return STAGES["released"]
    if platform in app.get("released", []):
        return -1
    return STAGES.get(app.get("stage", {}).get(platform, "none"), 0)


def ads_txt_ok(status, content_type, body, publisher):
    """게시자 줄이 있고, 본문 형식이 text/plain 하나로만 선언됐는지 확인한다."""
    kind = [part.strip().split(";")[0].strip().lower() for part in (content_type or "").split(",")]
    fields = [[f.strip().lower() for f in line.split("#")[0].split(",")] for line in body.splitlines()]
    return (
        status == 200
        and kind == ["text/plain"]
        and any(f[:3] == ["google.com", publisher, "direct"] for f in fields)
    )


def collect_ads_txt(app):
    out = []
    for url in app.get("appAdsTxt", []):
        ok = False
        try:
            status, headers, raw = fetch(url, timeout=15)
            content_type = ",".join(headers.get_all("Content-Type") or [])
            ok = ads_txt_ok(status, content_type, raw.decode("utf-8", "replace"), app["publisher"])
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            print(f"app-ads.txt {url}: {error}", flush=True)
        out.append(("app_ads_txt_ok", {"app": app["name"], "url": url}, int(ok)))
    return out


APPROVAL = {"APPROVED": 3, "IN_REVIEW": 2, "ACTION_REQUIRED": 1}
KST = timezone(timedelta(hours=9))


class UserToken:
    """사람 계정(woohalabs)의 갱신 토큰으로 받은 접근 토큰. AdMob API는 서비스 계정을 지원하지 않는다."""

    def __init__(self, path):
        self.path, self.value, self.expires = path, "", 0.0

    def available(self):
        return bool(self.path) and os.path.isfile(self.path)

    def header(self):
        if time.time() > self.expires - 120:
            with open(self.path, encoding="utf-8") as file:
                secret = json.load(file)
            request = urllib.request.Request(
                "https://oauth2.googleapis.com/token",
                data=urllib.parse.urlencode({**secret, "grant_type": "refresh_token"}).encode(),
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.load(response)
            self.value = data["access_token"]
            self.expires = time.time() + data["expires_in"]
        return {"Authorization": "Bearer " + self.value, "Content-Type": "application/json"}


USER_TOKEN = UserToken(os.environ.get("ADMOB_OAUTH_PATH", ""))


def admob_dates(window, today):
    """AdMob 보고서 기간. 오늘은 집계 중이라 어제까지만 본다."""
    start, end = {"1d": (1, 1), "7d": (7, 1), "prev7d": (14, 8), "28d": (28, 1)}[window]

    def part(days):
        day = today - timedelta(days=days)
        return {"year": day.year, "month": day.month, "day": day.day}

    return {"startDate": part(start), "endDate": part(end)}


def admob_samples(rows, names, window):
    """networkReport 행 → 표본. names: AdMob 앱 ID → (앱 이름, 플랫폼)"""
    out = []
    for row in rows:
        dims = row.get("dimensionValues", {})
        app = names.get(dims.get("APP", {}).get("value"))
        if not app:
            continue
        unit = dims.get("AD_UNIT", {})
        labels = {
            "app": app[0], "platform": app[1], "window": window,
            "ad_unit": unit.get("displayLabel") or unit.get("value", "(없음)"),
        }
        metrics = row.get("metricValues", {})
        for name, key, field, scale in (
            ("app_admob_requests", "AD_REQUESTS", "integerValue", 1),
            ("app_admob_matched", "MATCHED_REQUESTS", "integerValue", 1),
            ("app_admob_impressions", "IMPRESSIONS", "integerValue", 1),
            ("app_admob_clicks", "CLICKS", "integerValue", 1),
            ("app_admob_earnings_usd", "ESTIMATED_EARNINGS", "microsValue", 1e-6),
        ):
            out.append((name, labels, float(metrics.get(key, {}).get(field, 0)) * scale))
    return out


def collect_admob(account):
    base = f"https://admob.googleapis.com/v1beta/accounts/{account['publisher']}"
    names = {value: (a["name"], p) for a in account["apps"] for p, value in a.get("admobAppIds", {}).items()}

    _, _, raw = fetch(base + "/apps?pageSize=1000", headers=USER_TOKEN.header())
    out = []
    for item in json.loads(raw).get("apps", []):
        app = names.get(item.get("appId"))
        if app:
            state = item.get("appApprovalState", "")
            out.append(("app_admob_approval", {"app": app[0], "platform": app[1]}, APPROVAL.get(state, 0)))

    today = datetime.now(KST).date()
    for window in WINDOWS:
        spec = {
            "dateRange": admob_dates(window, today),
            "dimensions": ["APP", "AD_UNIT"],
            "metrics": ["AD_REQUESTS", "MATCHED_REQUESTS", "IMPRESSIONS", "CLICKS", "ESTIMATED_EARNINGS"],
            "localizationSettings": {"currencyCode": "USD", "languageCode": "ko"},
        }
        _, _, raw = fetch(base + "/networkReport:generate", {"reportSpec": spec}, USER_TOKEN.header())
        out += admob_samples([line["row"] for line in json.loads(raw) if "row" in line], names, window)

    spec = {
        "dateRange": admob_dates("28d", today),
        "dimensions": ["DATE", "APP"],
        "metrics": ["IMPRESSIONS", "ESTIMATED_EARNINGS"],
        "localizationSettings": {"currencyCode": "USD", "languageCode": "ko"},
    }
    _, _, raw = fetch(base + "/networkReport:generate", {"reportSpec": spec}, USER_TOKEN.header())
    out += admob_daily_samples([line["row"] for line in json.loads(raw) if "row" in line], names)
    return out


def admob_daily_samples(rows, names):
    out = []
    for row in rows:
        dims, metrics = row.get("dimensionValues", {}), row.get("metricValues", {})
        app = names.get(dims.get("APP", {}).get("value"))
        if not app:
            continue
        base = {"app": app[0], "platform": app[1], "date": daily_label(dims["DATE"]["value"]),
                "series": f"{app[0]} {app[1]}"}
        out.append(("app_daily", {**base, "metric": "ad_impressions"},
                    float(metrics.get("IMPRESSIONS", {}).get("integerValue", 0))))
        out.append(("app_daily", {**base, "metric": "ad_revenue_usd"},
                    float(metrics.get("ESTIMATED_EARNINGS", {}).get("microsValue", 0)) * 1e-6))
    return out


class Collector:
    """수집원마다 마지막 성공 결과를 보관한다. 실패하면 이전 값을 유지하고 실패 사실만 노출한다."""

    def __init__(self):
        self.lock = threading.Lock()
        self.samples, self.ok, self.last = {}, {}, {}

    def run(self, source, app, func):
        key = (source, app["name"])
        try:
            samples = func(app)
        except urllib.error.HTTPError as error:
            print(f"{key}: HTTP {error.code} {error.read()[:300]!r}", flush=True)
            samples = None
        except Exception as error:  # 한 수집원의 실패가 다른 수집을 멈추지 않게 한다
            print(f"{key}: {type(error).__name__} {error}", flush=True)
            samples = None
        with self.lock:
            self.ok[key] = int(samples is not None)
            if samples is not None:
                self.samples[key] = samples
                self.last[key] = time.time()

    def text(self):
        with self.lock:
            out = [sample for group in self.samples.values() for sample in group]
            for (source, app), value in self.ok.items():
                out.append(("app_metrics_collect_ok", {"source": source, "app": app}, value))
            for (source, app), value in self.last.items():
                out.append(("app_metrics_last_success_timestamp_seconds", {"source": source, "app": app}, value))
        return render(out)


def loop(collector, apps, jobs, interval):
    while True:
        for app in apps:
            for source, needed, func in jobs:
                if app.get(needed):
                    collector.run(source, app, func)
        time.sleep(interval)


def serve(collector, port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/healthz":
                body, kind = b"ok", "text/plain"
            elif self.path == "/metrics":
                body, kind = collector.text().encode(), "text/plain; version=0.0.4; charset=utf-8"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    ThreadingHTTPServer(("", port), Handler).serve_forever()


def main():
    with open(os.environ["CONFIG_PATH"], encoding="utf-8") as file:
        config = json.load(file)
    collector = Collector()
    ga4 = [("ga4", "ga4Property", collect_ga4)]
    fast = [
        ("remote_config", "firebaseProject", collect_remote_config),
        ("store", "platforms", collect_stores),
        ("app_ads_txt", "appAdsTxt", collect_ads_txt),
    ]
    if USER_TOKEN.available():
        publisher = config["admobPublisher"]
        account = {"name": "AdMob", "publisher": publisher, "apps": config["apps"]}
        threading.Thread(
            target=loop, args=(collector, [account], [("admob", "publisher", collect_admob)], config["intervals"]["ga4"]),
            daemon=True,
        ).start()
    else:
        print("AdMob 토큰이 없어 AdMob API는 수집하지 않음", flush=True)
    for jobs, interval in ((ga4, config["intervals"]["ga4"]), (fast, config["intervals"]["fast"])):
        threading.Thread(target=loop, args=(collector, config["apps"], jobs, interval), daemon=True).start()
    serve(collector, config["port"])


if __name__ == "__main__":
    main()
