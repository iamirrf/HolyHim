"""Run production SQLite configuration through the shipped Darwin native driver.

Unlike Dart FFI tests, this catches result-returning PRAGMAs incorrectly sent
through the iOS/macOS update API. It creates no user/account data.
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

ROOT = Path(__file__).resolve().parents[1]
if sys.platform != 'darwin':
    raise SystemExit('This native-driver verification requires macOS/Xcode.')
config_path = ROOT / '.dart_tool/package_config.json'
packages = json.loads(config_path.read_text())['packages']
package = next(row for row in packages if row['name'] == 'sqflite_darwin')
package_root = Path(unquote(urlparse(urljoin(config_path.as_uri(), package['rootUri'])).path))
sources = package_root / 'darwin/sqflite_darwin/Sources/sqflite_darwin'
source = (ROOT / 'lib/services/durable_store.dart').read_text()
configuration = source.split('onConfigure:', 1)[1].split('onCreate:', 1)[0]
calls = re.findall(r"await db\.(execute|rawQuery)\(\s*'([^']+)'\s*\)", configuration)
assert len(calls) == 2, 'Review native fixture extraction after changing onConfigure.'
with tempfile.TemporaryDirectory(prefix='holyher-native-sqlite-') as temp:
    executable = Path(temp) / 'verify'
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-w', '-I', str(sources),
                    str(ROOT / 'test/native/sqlite_configuration_test.m'),
                    str(sources / 'SqfliteDarwinDatabase.m'), str(sources / 'SqfliteDarwinResultSet.m'),
                    '-framework', 'Foundation', '-lsqlite3', '-o', str(executable)], check=True)
    result = subprocess.run([str(executable), str(Path(temp) / 'startup.db'),
                             *[value for call in calls for value in call]], check=False)
    raise SystemExit(result.returncode)
