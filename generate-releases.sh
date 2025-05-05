#!/usr/bin/env bash

set -e

MATRIX_FILE="./src/versions-matrix.json"
TEMPLATE_FILE="./src/Dockerfile.tpl"
NODE_TEMPLATE_FILE="./src/Dockerfile-node.tpl"
BASE_DIR="./base"
DIST_DIR="./dist"

# Check required tools
for bin in jq curl; do
  if ! command -v $bin &>/dev/null; then
    echo "❌ Error: $bin is not installed."
    exit 1
  fi
done

# Clean output folders
echo "🧹 Cleaning base/ and dist/ directories..."
rm -rf "$BASE_DIR" "$DIST_DIR"
mkdir -p "$BASE_DIR" "$DIST_DIR"

declare -A seen_php
declare -A seen_combination

# Normalize matrix file
dos2unix "$MATRIX_FILE" >/dev/null 2>&1

laravel_versions=$(jq -r 'keys[]' "$MATRIX_FILE")

for laravel_version in $laravel_versions; do
  laravel_version=$(echo "$laravel_version" | tr -d '\r')

  php_versions=$(jq -r --arg v "$laravel_version" '.[$v].php // empty | .[]' "$MATRIX_FILE")
  node_versions=$(jq -r --arg v "$laravel_version" '.[$v].node // empty | .[]' "$MATRIX_FILE")

  for php_version in $php_versions; do
    php_version_clean=$(echo "$php_version" | tr -d '\r')
    safe_php=$(echo "$php_version_clean" | sed 's/\.//g')

    # Build PHP base without Node.js (nonode)
    if [[ -z "${seen_php[$safe_php]}" ]]; then
      base_file="$BASE_DIR/php${safe_php}-nonode.Dockerfile"
      base_tag="syneidon/laravel:php${safe_php}-nonode"

      sed \
        -e "s|{{LARAVEL_VERSION}}|$laravel_version|g" \
        -e "s|{{PHP_VERSION}}|$php_version_clean|g" \
        -e "/^# NODE START/,/^# NODE END/d" \
        "$TEMPLATE_FILE" > "$base_file"

      if docker image inspect "$base_tag" > /dev/null 2>&1; then
        echo "🟡 Base image $base_tag already exists, skipping build."
      else
        echo "🧱 Building base image $base_tag ..."
        docker build -f "$base_file" -t "$base_tag" .
        echo "🧱 Base image $base_tag successfully built"
      fi

      seen_php[$safe_php]=1
    fi

    for node_version in $node_versions; do
      node_version_clean=$(echo "$node_version" | tr -d '\r')
      safe_node=$(echo "$node_version_clean" | sed 's/\.//g')

      combo_key="php${safe_php}-node${safe_node}"
      if [[ -n "${seen_combination[$combo_key]}" ]]; then
        continue
      fi
      seen_combination[$combo_key]=1

      outfile="$DIST_DIR/php${safe_php}-node${safe_node}.Dockerfile"

      sed \
        -e "s|{{NODE_VERSION}}|$node_version_clean|g" \
        -e "s|{{BASE_IMAGE}}|syneidon/laravel:php${safe_php}-nonode|g" \
        "$NODE_TEMPLATE_FILE" > "$outfile"

      echo "📄 Created $outfile"
    done
  done
done

echo "✅ All Dockerfiles and base images generated successfully."
