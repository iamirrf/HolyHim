"""Refuse a release whose membership offer could be closed or skipped.

HolyHim has no way past the offer in any build: no development switch, no
testing close button. This check fails if one ever returns, or if the gate
opens for anything but membership.
"""
import base64
import re
from pathlib import Path

# Words only a way past the offer would use.
_EXITS = ('HOLYHIM_TESTING_PAYWALL_EXIT', 'dismissForTesting', 'testingDismissed')


def production_gate_disabled(root: Path) -> bool:
    for path in sorted((root / 'lib').rglob('*.dart')):
        if any(word in path.read_text(encoding='utf-8') for word in _EXITS):
            return False
    gate = (root / 'lib/services/app_router.dart').read_text(encoding='utf-8')
    if not re.search(r'\(a\)\s*=>\s*\(open:\s*a\.active\s*,', gate):
        return False
    settings = root / 'ios/Flutter/Generated.xcconfig'
    if settings.is_file():
        match = re.search(r'^DART_DEFINES=(.*)$', settings.read_text(), re.M)
        if match and match.group(1).strip():
            for item in match.group(1).split(','):
                try:
                    decoded = base64.b64decode(item).decode('utf-8')
                except (ValueError, UnicodeError):
                    return False
                if decoded.startswith('HOLYHIM_TESTING_PAYWALL_EXIT='):
                    return False
    return True


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    if not production_gate_disabled(root):
        raise SystemExit('Release rejected: a way past the membership offer exists, or build defines are unreadable.')
    print('The membership offer has no way past it in source or in the current build defines.')
