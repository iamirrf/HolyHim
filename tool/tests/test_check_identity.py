"""The identity gate: placeholders and HolyHer's identifiers never reach a shipping path.

On Nov 15 fifteen files were overwritten with placeholder copies and pushed.
These tests hold the gate that would have refused them.
"""
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
from check_identity import consistency, problems, scan, shipping_files


class IdentityGateTests(unittest.TestCase):
    def found(self, path, text, her_values=()):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(text)
            return scan(Path(folder), [path], her_values)

    def test_the_repository_is_clean(self):
        self.assertEqual(problems(ROOT), [])

    def test_every_identity_file_is_scanned(self):
        files = set(shipping_files(ROOT))
        for path in ('config/revenuecat.json', 'ios/Runner/Info.plist', 'tool/connect_apple.sh',
                     'tool/verify_archive.py', 'functions/billing.js', 'lib/firebase_options.dart'):
            self.assertIn(path, files)

    def test_placeholders_are_refused(self):
        self.assertTrue(self.found('config/revenuecat.json', '{"appId": "REPLACE_WITH_HOLYHIM_APP_ID"}'))
        self.assertTrue(self.found('ios/Runner/Info.plist', '<string>000000000000-REPLACE.apps.googleusercontent.com</string>'))
        self.assertTrue(self.found('tool/verify_archive.py', "GOOGLE_APP = '1:000000000000:ios:abc'"))

    def test_xcode_object_ids_are_not_placeholders(self):
        self.assertEqual(self.found('ios/Runner.xcodeproj/project.pbxproj', 'fileRef = A11000000000000000000004 /* x */;'), [])

    def test_holyher_may_not_be_named_in_the_app(self):
        self.assertTrue(self.found('lib/app.dart', "const title = 'HolyHer';"))
        self.assertTrue(self.found('public/index.html', '<a href="https://holyher-app-production.web.app">'))

    def test_the_name_may_not_be_built_from_pieces(self):
        self.assertTrue(self.found('lib/design/widgets/text_halo.dart', "        TextSpan(text: 'Her',"))
        self.assertTrue(self.found('public/index.html', '<a class="wordmark">Holy<span>Her</span></a>'))
        self.assertEqual(self.found('lib/design/typography.dart', "TextSpan(text: 'Him', style: style)"), [])
        self.assertEqual(self.found('lib/features/x.dart', "'Here is your first week'"), [])

    def test_tooling_may_mention_holyher_but_not_use_its_identifiers(self):
        self.assertEqual(self.found('tool/setup.py', "# HolyHer's project is never read or changed."), [])
        self.assertEqual(self.found('store/metadata/en-US/review_notes.txt', 'separate from our app HolyHer (for women)'), [])
        for line in ("PROJECT = 'holyher-app-production'", "rc setup apple app294eba1272", "bundle = 'com.holyher.app'",
                     "product = 'holyher_annual'", 'ENTITLEMENT = "entlf63e788b71"', 'https://apps.apple.com/app/id6828594137'):
            self.assertTrue(self.found('tool/setup.py', line), line)

    def test_values_read_from_holyher_are_refused(self):
        self.assertTrue(self.found('lib/services/billing_config.dart', "const key = 'appl_HerKeyHerKey';", ['appl_HerKeyHerKey']))

    def test_identifiers_must_agree(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertTrue(consistency(Path(folder)))


if __name__ == '__main__':
    unittest.main()
