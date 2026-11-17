#!/bin/bash
# Runs tool/asc_release.rb on the pinned Ruby 3.4.7 / fastlane 2.229.1 runtime,
# signed with an App Store Connect API key (no Apple ID session or password).
#   ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=~/Downloads/AuthKey_....p8 \
#     bash tool/asc_release.sh inspect
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
release_ruby=/opt/homebrew/Cellar/ruby/3.4.7/bin/ruby
release_gems=/opt/homebrew/Cellar/fastlane/2.229.1/libexec
if [[ ! -x "$release_ruby" || ! -d "$release_gems" ]]; then
  echo 'The verified Ruby 3.4.7 / fastlane 2.229.1 installation is unavailable.' >&2
  exit 1
fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID}" "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}" "${ASC_KEY_PATH:?Set ASC_KEY_PATH}"
export GEM_HOME="$HOME/.local/share/fastlane/3.4.0"
export GEM_PATH="$GEM_HOME:$release_gems"
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_HIDE_CHANGELOG=1
export FASTLANE_DISABLE_COLORS=1
exec "$release_ruby" "$script_dir/asc_release.rb" "$@"
