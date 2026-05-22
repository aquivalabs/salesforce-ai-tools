#!/bin/bash
source "$(dirname "$0")/config.sh"

# Salesforce CLI secret redaction change:
# https://www.salesforceben.com/urgent-salesforce-security-update-will-break-your-ci-cd-unless-you-act-now/
#
# After the May 27, 2026 CLI rollout, replace the auth-cache command near the
# end of this file with:
# sf org auth show-sfdx-auth-url --target-org "$SCRATCH_ORG_ALIAS" --json \
#   | jq -r .result.sfdxAuthUrl > "$AUTH_CACHE_FILE"

execute() {
  "$@" || exit
}

# Restore from cache if we have an auth URL for this alias.
AUTH_CACHE_FILE="/tmp/sfdx-auth-${SCRATCH_ORG_ALIAS}.url"
if [ -s "$AUTH_CACHE_FILE" ]; then
  echo "Found cached auth for $SCRATCH_ORG_ALIAS — attempting restore"
  if sf org login sfdx-url --alias "$SCRATCH_ORG_ALIAS" --set-default --sfdx-url-stdin < "$AUTH_CACHE_FILE" \
     && sf org display --target-org "$SCRATCH_ORG_ALIAS" >/dev/null 2>&1; then
    echo "Restored $SCRATCH_ORG_ALIAS — skipping provisioning"
    exit 0
  fi
  echo "Cached auth invalid — falling through to fresh provisioning"
  rm -f "$AUTH_CACHE_FILE"
fi

if [ -z "$DEV_HUB_URL" ]; then
  echo "Setting default dev hub"
  execute sf config set target-dev-hub=$DEV_HUB_ALIAS

  echo "Deleting old scratch org"
  sf org delete scratch --no-prompt --target-org $SCRATCH_ORG_ALIAS
fi

echo "Creating scratch org"
execute sf org create scratch --alias $SCRATCH_ORG_ALIAS --set-default --definition-file ./config/project-scratch-def.json --duration-days 30

echo "Making org user English"
sf data update record --sobject User --where "Name='User User'" --values "Languagelocalekey=en_US"

echo "Enabling Agentforce"
sf org assign permset --name EinsteinGPTPromptTemplateManager --name AgentPlatformBuilder

echo "Deploying force-app"
sf project deploy start --source-dir force-app --concise --ignore-conflicts || true

echo "Running Apex tests"
sf apex run test --test-level RunLocalTests --wait 30 --result-format human || true

echo "Caching auth URL for reuse across CI runs"
sf org display --target-org "$SCRATCH_ORG_ALIAS" --verbose --json \
  | jq -r .result.sfdxAuthUrl > "$AUTH_CACHE_FILE"

if [ "${HEADLESS:-false}" != "true" ]; then
  sf org open
fi
