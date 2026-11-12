"""Safety boundaries for private iCalendar vdir subscriptions."""

import importlib.util
import os
import pathlib
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]


def module(name, filename):
    """Load an executable calendar helper into the isolated test process."""
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts/linux-desktop" / filename)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


sync = module("calendar_sync", "ical-sync.py")
query = module("calendar_query", "agenda-query.py")


class CalendarSyncTests(unittest.TestCase):
    """Protect private calendar source isolation and vdir compatibility."""

    def setUp(self):
        """Create isolated XDG and runtime directories for each test."""
        self.temporary = tempfile.TemporaryDirectory(prefix="calendar-sync-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.home = pathlib.Path(self.temporary.name)
        self.data = self.home / "data"
        self.state = self.home / "state"
        self.runtime = self.home / "runtime"
        self.runtime.mkdir()
        self.config = self.home / "config"
        (self.config / "khal").mkdir(parents=True)
        (self.config / "khal/config").write_text(
            "[calendars]\n[[personal]]\npath = /local\ntype = calendar\n[default]\ndefault_calendar = personal\n"
        )

    def test_sources_keep_identifiers_stable_and_require_private_files(self):
        """Reject unsafe private sources without changing stable source IDs."""
        folder = self.home / ".secrets/calendar-icals"
        folder.mkdir(parents=True, mode=0o700)
        source = folder / "Work.url"
        source.write_text("https://calendar.example.test/secret.ics")
        source.chmod(0o600)
        feeds = list(sync.private_sources(self.home))
        self.assertEqual(len(feeds), 1)
        self.assertEqual(feeds[0][0], query.hashlib.sha256(b"file:Work.url").hexdigest()[:24])
        source.chmod(0o644)
        with self.assertRaises(ValueError):
            sync.download(source)
        source.chmod(0o600)
        source.unlink()
        source.symlink_to(self.home / "other")
        with self.assertRaises(ValueError):
            sync.download(source)

    def test_download_rejects_insecure_urls_and_redirects(self):
        """Keep private calendar transport restricted to HTTPS."""
        source = self.home / "feed.url"
        source.write_text("http://calendar.example.test/feed.ics")
        source.chmod(0o600)
        with self.assertRaises(ValueError):
            sync.download(source)
        with self.assertRaises(ValueError):
            sync.HttpsRedirects().redirect_request(None, None, 302, "redirect", {}, "http://calendar.example.test/")

    def test_vdirsyncer_receives_only_local_private_file_and_config(self):
        """Keep URLs out of the vdirsyncer process and private config."""
        source = self.home / "feed.url"
        source.write_text("https://calendar.example.test/secret.ics")
        source.chmod(0o600)
        actions = []

        def fake_run(command, **kwargs):
            actions.append(command[-1])
            config = pathlib.Path(command[2])
            contents = config.read_text()
            self.assertNotIn("https://", contents)
            self.assertIn('type = "singlefile"', contents)
            self.assertIn("read_only = true", contents)
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)

        with (
            mock.patch.object(sync, "download", return_value=b"BEGIN:VCALENDAR\nEND:VCALENDAR\n"),
            mock.patch.object(sync.subprocess, "run", side_effect=fake_run),
        ):
            sync.sync_source("a" * 24, source, self.data, self.state, self.runtime)
        self.assertEqual(actions, ["discover", "sync"])
        self.assertTrue((self.data / "calendars/subscriptions" / ("a" * 24)).is_dir())

    def test_legacy_import_files_remain_available_for_rollback(self):
        """Retain preexisting cached calendar files when enabling vdirs."""
        original = self.data / "calendars/personal"
        original.mkdir(parents=True)
        filename = "google-ical-" + "a" * 24 + "--" + "b" * 64 + ".ics"
        (original / filename).write_text("private subscription event")
        (original / "local.ics").write_text("private local event")
        with (
            mock.patch.object(sync, "private_sources", return_value=[("a" * 24, original / filename)]),
            mock.patch.object(sync, "sync_source", return_value=None),
            mock.patch.object(sync.Path, "home", return_value=self.home),
            mock.patch.dict(
                os.environ,
                {
                    "XDG_DATA_HOME": str(self.data),
                    "XDG_STATE_HOME": str(self.state),
                    "XDG_RUNTIME_DIR": str(self.runtime),
                },
            ),
        ):
            self.assertEqual(sync.main(), 0)
        self.assertTrue((original / filename).exists())
        self.assertTrue((original / "local.ics").exists())
        self.assertTrue((self.state / "linux-desktop/ical-vdir-ready").exists())

    def test_sync_is_repeatable_and_keeps_legacy_cache(self):
        """Resynchronize unchanged feeds without disturbing legacy events."""
        folder = self.home / ".secrets/calendar-icals"
        folder.mkdir(mode=0o700, parents=True)
        source = folder / "Work.url"
        source.write_text("https://calendar.example.test/private.ics")
        source.chmod(0o600)
        original = self.data / "calendars/personal"
        original.mkdir(parents=True)
        old = original / ("google-ical-" + "a" * 24 + "--" + "b" * 64 + ".ics")
        old.write_text("legacy event")
        sample = (
            b"BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
            b"PRODID:-//Example//Calendar//EN\r\n"
            b"BEGIN:VEVENT\r\nUID:sample-1@example.test\r\n"
            b"DTSTAMP:20261113T000000Z\r\n"
            b"DTSTART:20261114T100000Z\r\n"
            b"DTEND:20261114T110000Z\r\n"
            b"SUMMARY:Example event\r\n"
            b"END:VEVENT\r\nEND:VCALENDAR\r\n"
        )
        identity = query.hashlib.sha256(b"file:Work.url").hexdigest()[:24]
        with mock.patch.object(sync, "download", return_value=sample):
            for _ in range(2):
                sync.sync_source(identity, source, self.data, self.state, self.runtime)
        self.assertEqual(
            len(list((self.data / "calendars/subscriptions" / identity).glob("*.ics"))),
            1,
        )
        self.assertEqual(old.read_text(), "legacy event")

    def test_legacy_duplicate_suppression_preserves_local_events(self):
        """Avoid duplicated subscriptions without hiding locally owned events."""
        identity = "b" * 24
        legacy_uid = "subscribed-event"
        local_uid = "local-event"
        original = self.data / "calendars/personal"
        original.mkdir(parents=True)
        (original / ("google-ical-" + identity + "--" + query.hashlib.sha256(legacy_uid.encode()).hexdigest() + ".ics")).touch()
        marker = self.state / "linux-desktop/ical-vdir-ready"
        marker.parent.mkdir(parents=True)
        marker.touch()
        (self.data / "calendars/subscriptions" / identity).mkdir(parents=True)
        base = {
            "start-date": "2026-11-14",
            "end-date": "2026-11-14",
            "start-time": "10:00",
            "end-time": "11:00",
            "location": "",
            "title": "Event",
        }
        events = [
            {**base, "uid": legacy_uid, "calendar": "personal"},
            {**base, "uid": legacy_uid, "calendar": "subscription-" + identity},
            {**base, "uid": local_uid, "calendar": "personal"},
        ]
        fake = mock.Mock(stdout=__import__("json").dumps(events))
        with (
            mock.patch.object(query, "CONFIG", self.config),
            mock.patch.object(query, "DATA", self.data),
            mock.patch.object(query, "STATE", self.state),
            mock.patch.object(query, "VDIR_READY", marker),
            mock.patch.object(query, "CACHE", original),
            mock.patch.object(query, "SUBSCRIPTIONS", self.data / "calendars/subscriptions"),
            mock.patch.object(query, "calendars", return_value=[{"id": identity, "name": "Work"}]),
            mock.patch.object(query, "disabled_ids", return_value=set()),
            mock.patch.object(query.subprocess, "run", return_value=fake),
            mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(self.runtime)}),
        ):
            agenda = query.agenda("2026-11-13")
        self.assertEqual(len(agenda["events"]), 2)
        self.assertEqual({event["calendar"] for event in agenda["events"]}, {"Work", "Local"})

    def test_missing_new_collection_uses_legacy_khal_view(self):
        """Keep the old data view available after an incomplete migration."""
        marker = self.state / "linux-desktop/ical-vdir-ready"
        marker.parent.mkdir(parents=True)
        marker.touch()
        identity = "c" * 24
        with (
            mock.patch.object(query, "VDIR_READY", marker),
            mock.patch.object(query, "SUBSCRIPTIONS", self.data / "calendars/subscriptions"),
            mock.patch.object(query, "CONFIG", self.config),
            query.khal_config([{"id": identity, "name": "Work"}]) as config,
        ):
            self.assertEqual(config, self.config / "khal/config")
            self.assertFalse(query.subscriptions_ready([{"id": identity}]))

    def test_khal_uses_native_calendar_collections_without_user_config_changes(self):
        """Expose new vdirs without rewriting user-owned khal preferences."""
        original = (self.config / "khal/config").read_text()
        identity = "b" * 24
        (self.data / "calendars/subscriptions" / identity).mkdir(parents=True)
        marker = self.state / "linux-desktop/ical-vdir-ready"
        marker.parent.mkdir(parents=True)
        marker.touch()
        with (
            mock.patch.object(query, "CONFIG", self.config),
            mock.patch.object(query, "STATE", self.state),
            mock.patch.object(query, "VDIR_READY", marker),
            mock.patch.object(query, "SUBSCRIPTIONS", self.data / "calendars/subscriptions"),
            mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(self.runtime)}),
            query.khal_config([{"id": identity, "name": "Work"}]) as path,
        ):
            text = path.read_text()
            self.assertIn("[[subscription-" + identity + "]]", text)
            self.assertIn("[[personal]]", text)
            self.assertIn("readonly = True", text)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(original, (self.config / "khal/config").read_text())


if __name__ == "__main__":
    unittest.main()
