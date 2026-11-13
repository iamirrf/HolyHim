#!/bin/zsh
set -e
# Pin the official version containing the Apple auth-service endpoint fix.
npx --yes @revenuecat/cli@0.1.7 setup apple "${RC_APP_ID:-REPLACE_WITH_HOLYHIM_APP_ID}" --project-id "${RC_PROJECT_ID:-REPLACE_WITH_HOLYHIM_PROJECT_ID}" --yes
