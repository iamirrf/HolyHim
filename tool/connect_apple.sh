#!/bin/zsh
set -e
# Pin the official version containing the Apple auth-service endpoint fix.
npx --yes @revenuecat/cli@0.1.7 setup apple app294eba1272 --project-id proj802af471 --yes
