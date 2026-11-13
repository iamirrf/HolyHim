"""Reject an enabled development paywall exit in distributable preparation."""
import base64
import re
from pathlib import Path

def production_gate_disabled(root: Path) -> bool:
    source = (root / 'lib/services/billing.dart').read_text()
    if not re.search(r"bool\.fromEnvironment\(\s*'HOLYHIM_TESTING_PAYWALL_EXIT'\s*,\s*defaultValue:\s*false\s*\)", source):
        return False
    settings = root / 'ios/Flutter/Generated.xcconfig'
    if settings.is_file():
        match = re.search(r'^DART_DEFINES=(.*)$', settings.read_text(), re.M)
        if match:
            for item in match.group(1).split(','):
                try:
                    decoded = base64.b64decode(item).decode('utf-8')
                except (ValueError, UnicodeError):
                    return False
                if decoded.startswith('HOLYHIM_TESTING_PAYWALL_EXIT=') and decoded.split('=', 1)[1].lower() in ('true', '1'):
                    return False
    return True

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    if not production_gate_disabled(root):
        raise SystemExit('Release rejected: the testing paywall exit is enabled or build defines are unreadable.')
    print('Production paywall gate is disabled in source and current build defines.')
