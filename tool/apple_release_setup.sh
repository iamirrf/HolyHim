#!/bin/bash
# Pinned to the working Homebrew fastlane runtime already installed on this Mac.
# Does not install gems, inspect Keychain, or extract browser/Xcode credentials.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
release_ruby=/opt/homebrew/Cellar/ruby/3.4.7/bin/ruby
release_gems=/opt/homebrew/Cellar/fastlane/2.229.1/libexec
if [[ ! -x "$release_ruby" || ! -d "$release_gems" ]]; then
  echo 'The verified Ruby 3.4.7 / fastlane 2.229.1 installation is unavailable.' >&2
  exit 1
fi
export GEM_HOME="$HOME/.local/share/fastlane/3.4.0"
export GEM_PATH="$GEM_HOME:$release_gems"
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_HIDE_CHANGELOG=1
export FASTLANE_DISABLE_COLORS=1
exec "$release_ruby" "$script_dir/apple_release_setup.rb" "$@"
