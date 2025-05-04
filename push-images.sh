#!/usr/bin/env bash

set -e

MATRIX_FILE="./src/versions-matrix.json"

# Check for required tools
if ! command -v jq &>/dev/null; then
    echo "❌ jq is required but not installed."
    exit 1
fi

echo "🚀 Starting Docker image push process..."

# Push base (nonode) images
echo "📦 Pushing base images..."
jq -r 'to_entries[] | .value.php[]' "$MATRIX_FILE" | sed 's/\.//g' | sort -u | while read -r safe_php; do
  tag="php${safe_php}-nonode"
  image="syneidon/laravel:$tag"
  echo "🔄 Pushing $image..."
  docker push "$image"
done

# Push versioned images and tags
echo ""
echo "📦 Pushing Laravel + PHP + Node combo images..."
jq -r 'keys[]' "$MATRIX_FILE" | while read -r laravel_version; do
  php_versions=$(jq -r --arg v "$laravel_version" '.[$v].php[]' "$MATRIX_FILE")
  node_versions=$(jq -r --arg v "$laravel_version" '.[$v].node[]' "$MATRIX_FILE")

  latest_php=""
  latest_node=""

  for php_version in $php_versions; do
    latest_php=$php_version
    safe_php=$(echo "$php_version" | sed 's/\.//g')

    for node_version in $node_versions; do
      latest_node=$node_version
      safe_node=$(echo "$node_version" | sed 's/\.//g')

      base_tag="php${safe_php}-node${safe_node}"
      versioned_tag="v${laravel_version#v}-${base_tag}"  # e.g. v8-php81-node18

      echo "🔄 Pushing syneidon/laravel:$base_tag"
      docker push "syneidon/laravel:$base_tag"

      echo "🔄 Tagging syneidon/laravel:$versioned_tag"
      docker tag "syneidon/laravel:$base_tag" "syneidon/laravel:$versioned_tag"
      docker push "syneidon/laravel:$versioned_tag"
    done
  done

  # Tag latest for this Laravel version
  latest_safe_php=$(echo "$latest_php" | sed 's/\.//g')
  latest_safe_node=$(echo "$latest_node" | sed 's/\.//g')
  latest_tag="v${laravel_version#v}"
  combo_tag="php${latest_safe_php}-node${latest_safe_node}"

  echo "🏷 Tagging syneidon/laravel:$combo_tag as syneidon/laravel:$latest_tag"
  docker tag "syneidon/laravel:$combo_tag" "syneidon/laravel:$latest_tag"
  docker push "syneidon/laravel:$latest_tag"
done

echo ""
echo "✅ All images pushed successfully."
