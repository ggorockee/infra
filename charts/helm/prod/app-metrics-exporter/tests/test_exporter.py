"""실행: python3 -m unittest discover -s charts/helm/prod/app-metrics-exporter/tests"""

import sys
import unittest
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
