#!/usr/bin/env python3
"""Build a local system-font pipe for composition review; never save font data."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = (root/'ios/Runner/AppDelegate.swift').read_text()
source = source[source.index('private enum RoundedTypography {'):source.index('  static func specimen()')]
source = source.replace('UIFont', 'NSFont').replace('return NSFont(descriptor: descriptor, size: 22)', 'return NSFont(descriptor: descriptor, size: 22)!')
program = 'import Foundation\nimport AppKit\nimport CoreText\n' + source + '}\nlet regular=try RoundedTypography.font(.regular),semibold=try RoundedTypography.font(.semibold)\nlet data:[String:Any]=[\n "regular":try RoundedTypography.data(regular).base64EncodedString(),\n "semibold":try RoundedTypography.data(semibold).base64EncodedString(),\n "source":"AppKit rounded system descriptor; tables streamed in memory for design review only",\n "regularName":regular.fontName,"semiboldName":semibold.fontName\n]\nFileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:data))\n'
path = Path('/tmp/holyher-native-review-fonts.swift')
path.write_text(program)
subprocess.run(['xcrun', 'swiftc', '-O', '-module-cache-path', '/tmp/holyher-review-module-cache', str(path), '-o', '/tmp/holyher-native-review-fonts'], check=True)
print('Built memory-only review font resolver from the native adapter source.')
