#!/bin/bash
# trigger.sh - Trigger a CircleCI pipeline with proper error handling
#
# This is a fork of circleci/trigger-pipeline with fixes for:
# - Validating API responses (the upstream orb ignores errors)
# - Pre-flight validation of definition_id format
# - Clear error messages when triggers fail

set -euo pipefail

PARAM_PROJECT_SLUG="$(circleci env subst "$PARAM_PROJECT_SLUG")"
PARAM_TOKEN="$(circleci env subst "$PARAM_TOKEN")"
PARAM_BRANCH="$(circleci env subst "$PARAM_BRANCH")"
PARAM_TAG="$(circleci env subst "$PARAM_TAG")"
PARAM_DEFINITION_ID="$(circleci env subst "$PARAM_DEFINITION_ID")"
PARAM_PARAMETERS="$(circleci env subst "$PARAM_PARAMETERS")"

# --- Pre-flight validation ---

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed"
    exit 1
fi

if [ -z "$PARAM_PROJECT_SLUG" ]; then
    echo "ERROR: project_slug is required"
    exit 1
fi

if [ -z "$PARAM_DEFINITION_ID" ]; then
    echo "ERROR: definition_id is required"
    exit 1
fi

if [ -z "$PARAM_TOKEN" ]; then
    echo "ERROR: token is required"
    exit 1
fi

if [ -z "$PARAM_BRANCH" ] && [ -z "$PARAM_TAG" ]; then
    echo "ERROR: Either branch or tag is required"
    exit 1
fi

# Validate definition_id is a UUID (not a placeholder like "abcd1234")
UUID_REGEX='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if ! echo "$PARAM_DEFINITION_ID" | grep -qiE "$UUID_REGEX"; then
    echo "ERROR: definition_id does not appear to be a valid UUID"
    echo "       Got: $PARAM_DEFINITION_ID"
    echo "       Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    exit 1
fi

# --- Build request payload ---

if [ -n "$PARAM_PARAMETERS" ]; then
    PARAMETERS=$(printf '%s\n' "$PARAM_PARAMETERS" | jq -Rn '
      ( input | split(",") | map( split("=") | { (.[0]): .[1] } ) | add )
    ')
else
    PARAMETERS="{}"
fi

if [ -n "$PARAM_BRANCH" ]; then
    echo "Triggering pipeline for project: $PARAM_PROJECT_SLUG"
    echo "  Branch: $PARAM_BRANCH"
    echo "  Definition ID: $PARAM_DEFINITION_ID"
    echo "  Parameters: $PARAMETERS"
    DATA=$(jq -n --arg definition_id "$PARAM_DEFINITION_ID" --arg branch "$PARAM_BRANCH" --argjson params "$PARAMETERS" \
        '{definition_id: $definition_id, config: {branch: $branch}, checkout: {branch: $branch}, parameters: $params}')
elif [ -n "$PARAM_TAG" ]; then
    echo "Triggering pipeline for project: $PARAM_PROJECT_SLUG"
    echo "  Tag: $PARAM_TAG"
    echo "  Definition ID: $PARAM_DEFINITION_ID"
    echo "  Parameters: $PARAMETERS"
    DATA=$(jq -n --arg definition_id "$PARAM_DEFINITION_ID" --arg tag "$PARAM_TAG" --argjson params "$PARAMETERS" \
        '{definition_id: $definition_id, config: {tag: $tag}, checkout: {tag: $tag}, parameters: $params}')
fi

# --- Make API request and validate response ---

RESPONSE_FILE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
    -X POST "https://circleci.com/api/v2/project/$PARAM_PROJECT_SLUG/pipeline/run" \
    --header "Circle-Token: $PARAM_TOKEN" \
    --header "content-type: application/json" \
    --data "$DATA")

RESPONSE=$(cat "$RESPONSE_FILE")
rm -f "$RESPONSE_FILE"

echo ""
echo "API Response (HTTP $HTTP_CODE):"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

# Check HTTP status code
if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "ERROR: CircleCI API returned HTTP $HTTP_CODE"
    exit 1
fi

# Check for error message in response
if echo "$RESPONSE" | jq -e '.message' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message')
    echo "ERROR: CircleCI API returned error: $ERROR_MSG"
    exit 1
fi

# Check for pipeline ID in successful response
if ! echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
    echo "ERROR: Response missing expected 'id' field - trigger may have failed"
    exit 1
fi

PIPELINE_ID=$(echo "$RESPONSE" | jq -r '.id')
PIPELINE_NUMBER=$(echo "$RESPONSE" | jq -r '.number // "unknown"')

echo "SUCCESS: Pipeline triggered"
echo "  Pipeline ID: $PIPELINE_ID"
echo "  Pipeline Number: $PIPELINE_NUMBER"
