"""실행: python3 -m unittest discover -s charts/helm/prod/app-metrics-exporter/tests"""

import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "files"))
import exporter  # noqa: E402

PUB = "pub-8516861197467665"
LINE = f"google.com, {PUB}, DIRECT, f08c47fec0942fa0\n"


class VersionTest(unittest.TestCase):
    def test_orders_by_number_not_text(self):
        self.assertLess(exporter.version_number("2.9.0"), exporter.version_number("2.10.0"))

    def test_short_and_invalid(self):
        self.assertEqual(exporter.version_number("1.0"), exporter.version_number("1.0.0"))
        self.assertIsNone(exporter.version_number("(not set)"))
        self.assertIsNone(exporter.version_number(""))


class AdsCostKrwTest(unittest.TestCase):
    def samples(self, rows, today):
        out = exporter.ads_cost_samples("리뷰맵", rows, today)
        windows = {(l["window"], l["campaign"]): v for n, l, v in out if n == "app_ads_cost_krw"}
        daily = {l["date"]: v for n, l, v in out if n == "app_daily"}
        return windows, daily

    def test_sums_by_period_and_own_campaigns(self):
        rows = [
            (["20261128", "리뷰맵-안드로이드"], [1000.0]),
            (["20261128", "돌려받엔-iOS"], [500.0]),
            (["20261127", "리뷰맵-iOS"], [70.0]),
            (["20261127", "(not set)"], [3.0]),
            (["20261101", "리뷰맵-iOS"], [20.0]),
            (["20261031", "리뷰맵-안드로이드"], [5.0]),
        ]
        windows, daily = self.samples(rows, date(2026, 11, 28))
        self.assertEqual(windows[("today", "전체")], 1000)  # 다른 앱 캠페인은 합계에서 제외
        self.assertEqual(windows[("today", "돌려받엔-iOS")], 500)  # 캠페인별 값은 남김
        self.assertEqual(windows[("yesterday", "전체")], 70)
        self.assertNotIn(("yesterday", "(not set)"), windows)
        self.assertEqual(windows[("mtd", "전체")], 1090)
        self.assertEqual(windows[("mtd", "리뷰맵-iOS")], 90)
        self.assertEqual(windows[("last_month", "전체")], 5)
        self.assertEqual(len(daily), 28)
        self.assertEqual(daily["2026-11-28"], 1000)
        self.assertEqual(daily["2026-11-26"], 0)

    def test_no_rows_is_zero(self):
        windows, daily = self.samples([], date(2027, 1, 1))
        self.assertEqual(set(windows.values()), {0})
        self.assertEqual({w for w, _ in windows}, {"today", "yesterday", "mtd", "last_month"})
        self.assertEqual(sum(daily.values()), 0)

    def test_periods_cross_year(self):
        p = exporter.ads_cost_periods(date(2027, 1, 1))
        self.assertEqual(p["last_month"], (date(2026, 12, 1), date(2026, 12, 31)))
        self.assertEqual(p["yesterday"][0], date(2026, 12, 31))


class AdsMoneySafetyTest(unittest.TestCase):
    REPORT = {"metadata": {"currencyCode": "KRW"}, "rowCount": 1,
              "rows": [{"dimensionValues": [{"value": "20260101"}, {"value": "a"}], "metricValues": [{"value": "10"}]}]}

    def test_accepts_requested_currency(self):
        self.assertEqual(exporter.report_rows(self.REPORT, "KRW", 10), [(["20260101", "a"], [10.0])])

    def test_wrong_currency_or_truncation_fails(self):
        with self.assertRaises(ValueError):
            exporter.report_rows(dict(self.REPORT, metadata={"currencyCode": "USD"}), "KRW", 10)
        with self.assertRaises(ValueError):
            exporter.report_rows(dict(self.REPORT, rowCount=11), "KRW", 10)

    def test_budget_values(self):
        out = exporter.budget_samples('{"앱-iOS": 100, "앱-안드로이드": 200}')
        self.assertEqual({l["campaign"]: v for _, l, v in out}, {"앱-iOS": 100, "앱-안드로이드": 200})
        for bad in ("{}", "[]", '{"a": 0}', '{"a": "100"}', '{"a": true}', "not json"):
            with self.assertRaises(ValueError, msg=bad):
                exporter.budget_samples(bad)

    def test_missing_budget_file_gives_no_metrics(self):
        self.assertEqual(exporter.collect_ads_budget({"adsBudget": "/nonexistent/budgets.json"}), [])


class AdsTxtTest(unittest.TestCase):
    def test_valid(self):
        self.assertTrue(exporter.ads_txt_ok(200, "text/plain; charset=utf-8", LINE, PUB))

    def test_duplicated_content_type_is_rejected(self):
        self.assertFalse(exporter.ads_txt_ok(200, "text/plain,text/plain", LINE, PUB))

    def test_commented_or_other_publisher_is_rejected(self):
        self.assertFalse(exporter.ads_txt_ok(200, "text/plain", "# " + LINE, PUB))
        self.assertFalse(exporter.ads_txt_ok(200, "text/plain", LINE.replace("8516", "0000"), PUB))


class RemoteConfigTest(unittest.TestCase):
    def numbers(self, values):
        template = {"parameters": {k: {"defaultValue": {"value": v}} for k, v in values.items()}}
        samples = exporter.remote_config_samples("a", template, ["ios"])
        return {s[1]["kind"]: s[2] for s in samples if s[0] == "app_version_number"}

    def test_min_version_ignored_when_force_update_off(self):
        values = {"ios_min_version": "9.0.0", "ios_latest_version": "2.2.0", "ios_force_update": "false"}
        self.assertEqual(self.numbers(values)["rc_min"], 0)

    def test_min_version_used_without_force_flag(self):
        self.assertEqual(self.numbers({"ios_min_version": "1.1.0"})["rc_min"], 1_001_000)

    def test_groups_and_types(self):
        template = {"parameterGroups": {"ads": {"parameters": {
            "show": {"defaultValue": {"value": "true"}}, "gap": {"defaultValue": {"value": "3"}},
        }}}}
        values = {s[1]["key"]: s[2] for s in exporter.remote_config_samples("a", template, [])
                  if s[0] == "app_remote_config_value"}
        self.assertEqual(values, {"show": 1, "gap": 3.0})


class AdmobTest(unittest.TestCase):
    def test_dates_end_yesterday_and_do_not_overlap(self):
        today = exporter.datetime(2026, 12, 3).date()
        self.assertEqual(exporter.admob_dates("7d", today), {
            "startDate": {"year": 2026, "month": 11, "day": 26}, "endDate": {"year": 2026, "month": 12, "day": 2}})
        self.assertEqual(exporter.admob_dates("prev7d", today)["endDate"], {"year": 2026, "month": 11, "day": 25})

    def test_rows_to_samples(self):
        rows = [{
            "dimensionValues": {"APP": {"value": "a~1"}, "AD_UNIT": {"value": "a/1", "displayLabel": "배너"}},
            "metricValues": {"AD_REQUESTS": {"integerValue": "12"}, "ESTIMATED_EARNINGS": {"microsValue": "80000"}},
        }, {"dimensionValues": {"APP": {"value": "unknown"}}, "metricValues": {}}]
        samples = {s[0]: s for s in exporter.admob_samples(rows, {"a~1": ("리뷰맵", "ios")}, "7d")}
        self.assertEqual(samples["app_admob_requests"][1]["ad_unit"], "배너")
        self.assertEqual(samples["app_admob_requests"][2], 12)
        self.assertAlmostEqual(samples["app_admob_earnings_usd"][2], 0.08)
        self.assertEqual(samples["app_admob_impressions"][2], 0)


class Phase1Test(unittest.TestCase):
    def test_outdated_ratio(self):
        rows = [("2.2.0", 6), ("2.1.1", 2), ("2.3.0", 2)]
        self.assertAlmostEqual(exporter.outdated_ratio(rows, 2_002_000), 0.2)
        self.assertIsNone(exporter.outdated_ratio(rows, None))
        self.assertIsNone(exporter.outdated_ratio([], 2_002_000))

    def test_unknown_version_counts_as_old(self):
        self.assertEqual(exporter.outdated_ratio([("(not set)", 1)], 1), 1)

    def test_store_stage(self):
        app = {"released": ["ios"], "stage": {"android": "testing"}}
        self.assertEqual(exporter.store_stage(app, "ios", True), 3)
        self.assertEqual(exporter.store_stage(app, "ios", False), -1)
        self.assertEqual(exporter.store_stage(app, "android", False), 1)
        self.assertEqual(exporter.store_stage({}, "android", False), 0)

    def test_remember_reference(self):
        exporter.REFERENCE.clear()
        exporter.remember([("app_version_number", {"app": "a", "platform": "ios", "kind": "store"}, 5),
                           ("app_version_number", {"app": "a", "platform": "ios", "kind": "seen"}, 9)])
        self.assertEqual(exporter.REFERENCE, {("a", "ios"): {"store": 5}})

    def test_admob_daily(self):
        rows = [{"dimensionValues": {"DATE": {"value": "20261125"}, "APP": {"value": "x"}},
                 "metricValues": {"IMPRESSIONS": {"integerValue": "3"}, "ESTIMATED_EARNINGS": {"microsValue": "20000"}}}]
        s = exporter.admob_daily_samples(rows, {"x": ("리뷰맵", "ios")})
        self.assertEqual(s[0][1]["date"], "2026-11-25")
        self.assertEqual(s[0][2], 3)
        self.assertAlmostEqual(s[1][2], 0.02)


class RetentionTest(unittest.TestCase):
    def test_groups_by_source_and_day(self):
        rows = [
            (["d8", "0000", "Android", "google / cpc"], [4, 4]),
            (["d8", "0001", "Android", "google / cpc"], [2, 4]),
            (["d9", "0000", "Android", "google-play / organic"], [10, 10]),
            (["d9", "0007", "Android", "google-play / organic"], [1, 10]),
            (["d9", "0000", "web", "(direct) / (none)"], [5, 5]),
        ]
        s = {(m, l["source"], l.get("day")): v for m, l, v in exporter.retention_samples("a", ["android"], rows)}
        self.assertEqual(s[("app_retention_cohort_users", "ads", None)], 4)
        self.assertEqual(s[("app_retention_ratio", "ads", "1")], 0.5)
        self.assertEqual(s[("app_retention_ratio", "ads", "7")], 0)
        self.assertEqual(s[("app_retention_ratio", "other", "7")], 0.1)
        self.assertNotIn(("app_retention_cohort_users", "web", None), s)


class RenderTest(unittest.TestCase):
    def test_escapes_labels(self):
        self.assertIn('v="a\\"b\\\\c\\n"', exporter.render([("m", {"v": 'a"b\\c\n'}, 1)]))


class CollectorTest(unittest.TestCase):
    def test_failure_keeps_previous_values(self):
        collector, app = exporter.Collector(), {"name": "a"}
        collector.run("s", app, lambda _: [("m", {}, 7)])

        def fail(_):
            raise RuntimeError("boom")

        collector.run("s", app, fail)
        text = collector.text()
        self.assertIn("m{} 7", text)
        self.assertIn('app_metrics_collect_ok{app="a",source="s"} 0', text)


if __name__ == "__main__":
    unittest.main()
