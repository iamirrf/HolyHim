#!/bin/zsh
set -e
# Pin the official version containing the Apple auth-service endpoint fix.
npx --yes @revenuecat/cli@0.1.7 setup apple REPLACE_WITH_HOLYHIM_REVENUECAT_APP --project-id REPLACE_WITH_HOLYHIM_REVENUECAT_PROJECT --yes
