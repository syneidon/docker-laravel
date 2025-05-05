#!/usr/bin/env bash

set -e

FORCE_PUSH=false
[[ "$1" == "--force" ]] && FORCE_PUSH=true

MATRIX_FILE="./src/versions-matrix.json"
DIST_DIR="./dist"
REPO="syneidon/laravel"

# Check for required tools
for tool in jq docker; do
  if ! command -v "$tool" &>/dev/null; then
    echo "❌ $tool is required but not installed."
    exit 1
  fi
done

check_remote_tag_exists() {
  local image="$1"
  docker manifest inspect "$image" >/dev/null 2>&1
}

echo "🚀 Starting Docker image push process..."

# Push base (nonode) images
echo "📦 Pushing base images..."
jq -r 'to_entries[] | .value.php[]' "$MATRIX_FILE" | sed 's/\.//g' | sort -u | while read -r safe_php; do
  tag="php${safe_php}-nonode"
  image="$REPO:$tag"

  if check_remote_tag_exists "$image" && [ "$FORCE_PUSH" = false ]; then
    echo "⏭ Skipping $image (already exists)"
  else
    echo "🔄 Pushing $image..."
    docker push "$image"
  fi
done

# Push versioned images and tags
echo ""
echo "📦 Pushing Laravel + PHP + Node combo images..."
jq -r 'keys[]' "$MATRIX_FILE" | while read -r laravel_version; do
  laravel_version=$(echo "$laravel_version" | tr -d '\r')
  php_versions=$(jq -r --arg v "$laravel_version" '.[$v].php // [] | .[]' "$MATRIX_FILE")
  node_versions=$(jq -r --arg v "$laravel_version" '.[$v].node // [] | .[]' "$MATRIX_FILE")

  latest_php=""
  latest_node=""

  for php_version in $php_versions; do
    latest_php=$php_version
    safe_php=$(echo "$php_version" | sed 's/\.//g')

    for node_version in $node_versions; do
      latest_node=$node_version
      safe_node=$(echo "$node_version" | sed 's/\.//g')

      base_tag="php${safe_php}-node${safe_node}"
      versioned_tag="v${laravel_version#v}-${base_tag}"
      dockerfile="$DIST_DIR/${base_tag}.Dockerfile"

      if ! docker image inspect "$REPO:$base_tag" >/dev/null 2>&1; then
        echo "🧱 Building $REPO:$base_tag from $dockerfile..."
        docker build -f "$dockerfile" -t "$REPO:$base_tag" .
      fi

      if check_remote_tag_exists "$REPO:$base_tag" && [ "$FORCE_PUSH" = false ]; then
        echo "⏭ Skipping push for $REPO:$base_tag (already exists)"
      else
        echo "🔄 Pushing $REPO:$base_tag"
        docker push "$REPO:$base_tag"
      fi

      if check_remote_tag_exists "$REPO:$versioned_tag" && [ "$FORCE_PUSH" = false ]; then
        echo "⏭ Skipping tag $REPO:$versioned_tag (already exists)"
      else
        echo "🏷 Tagging $REPO:$base_tag as $REPO:$versioned_tag"
        docker tag "$REPO:$base_tag" "$REPO:$versioned_tag"
        docker push "$REPO:$versioned_tag"
      fi
    done
  done

  latest_safe_php=$(echo "$latest_php" | sed 's/\.//g')
  latest_safe_node=$(echo "$latest_node" | sed 's/\.//g')
  latest_tag="v${laravel_version#v}"
  combo_tag="php${latest_safe_php}-node${latest_safe_node}"

  if check_remote_tag_exists "$REPO:$latest_tag" && [ "$FORCE_PUSH" = false ]; then
    echo "⏭ Skipping alias tag $REPO:$latest_tag (already exists)"
  else
    echo "🏷 Tagging $REPO:$combo_tag as $REPO:$latest_tag"
    docker tag "$REPO:$combo_tag" "$REPO:$latest_tag"
    docker push "$REPO:$latest_tag"
  fi
done

echo ""
echo "✅ All images built and pushed (or skipped if already present)."
