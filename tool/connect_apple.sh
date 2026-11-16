#!/bin/zsh
set -e
# Pin the official version containing the Apple auth-service endpoint fix.
npx --yes @revenuecat/cli@0.1.7 setup apple app9d001a6c4f --project-id proj1b08bf4e --yes
