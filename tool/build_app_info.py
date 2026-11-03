#!/usr/bin/env python3
"""Keep the non-native test fallback in sync with pubspec's build identity."""
import argparse,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
version=re.search(r'^version:\s*(\S+)',Path('pubspec.yaml').read_text(),re.M)[1];name,build=version.split('+')
text=f"// Generated from pubspec.yaml by tool/build_app_info.py.\nabstract final class AppBuildInfo {{\n  static const name = '{name}';\n  static const build = '{build}';\n}}\n"
path=Path('lib/core/constants/build_info.dart')
if args.check:
 if not path.exists() or path.read_text()!=text:raise SystemExit('Run python3 tool/build_app_info.py after changing pubspec version.')
 print('Build identity matches pubspec.yaml')
else:path.write_text(text)
