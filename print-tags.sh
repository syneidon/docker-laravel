#!/bin/bash

# Usage: ./generate-md-table.sh 20250527212831

TIMESTAMP="$1"
JSON_FILE="logs/build-${TIMESTAMP}.json"
BASE_URL="https://github.com/syneidon/docker-laravel/blob/main/dist/${TIMESTAMP}"

if [[ -z "$TIMESTAMP" ]]; then
  echo "Usage: $0 <timestamp>"
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "Error: File not found: $JSON_FILE"
  exit 2
fi

# Print Markdown table header
echo "| Dockerfile | Tags |"
echo "|------------|------|"

# Generate each row
jq -r --arg url "$BASE_URL" '
  .[] |
  "| [`\(.title | split(":")[1])`](" + $url + "/" + (.title | split(":")[1]) + ".Dockerfile) | " +
  (.tags | map("`\(.)`") | join(", ")) + " |"
' "$JSON_FILE"
