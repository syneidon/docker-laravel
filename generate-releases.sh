#!/usr/bin/env bash

set -e

MATRIX_FILE="./src/versions-matrix.json"
TEMPLATE_FILE="./src/Dockerfile.tpl"
BASE_DIR="./base"
DIST_DIR="./dist"
TEST_DIR="./test"

# Check required tools
for bin in jq curl; do
  if ! command -v $bin &>/dev/null; then
    echo "❌ Error: $bin is not installed."
    exit 1
  fi
done

# Clean output folders
echo "🧹 Cleaning base/, dist/, and test/ directories..."
rm -rf "$BASE_DIR" "$DIST_DIR" "$TEST_DIR"
mkdir -p "$BASE_DIR" "$DIST_DIR" "$TEST_DIR"

declare -A seen_php
declare -A seen_combination
latest_php=""
latest_node=""

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
    latest_php=$php_version_clean

    # Build PHP base without Node.js (nonode)
    if [[ -z "${seen_php[$safe_php]}" ]]; then
      base_file="$BASE_DIR/php${safe_php}-nonode.Dockerfile"
      base_tag="syneidon/laravel:php${safe_php}-nonode"

      # Generate base Dockerfile
      sed \
        -e "s|{{LARAVEL_VERSION}}|$laravel_version|g" \
        -e "s|{{PHP_VERSION}}|$php_version_clean|g" \
        -e "/^# NODE START/,/^# NODE END/d" \
        "$TEMPLATE_FILE" > "$base_file"

      # Build only if image doesn't already exist
      if docker image inspect "$base_tag" > /dev/null 2>&1; then
        echo "🟡 Base image $base_tag already exists, skipping build."
      else
        docker build -f "$base_file" -t "$base_tag" "$BASE_DIR"
        echo "🧱 Built base image $base_tag"
      fi

      seen_php[$safe_php]=1
    fi

    for node_version in $node_versions; do
      node_version_clean=$(echo "$node_version" | tr -d '\r')
      safe_node=$(echo "$node_version_clean" | sed 's/\.//g')
      latest_node=$node_version_clean

      combo_key="php${safe_php}-node${safe_node}"
      if [[ -n "${seen_combination[$combo_key]}" ]]; then
        continue
      fi
      seen_combination[$combo_key]=1

      for dir in "$DIST_DIR" "$TEST_DIR"; do
        outfile="$dir/php${safe_php}-node${safe_node}.Dockerfile"

        sed \
          -e "s|{{LARAVEL_VERSION}}|$laravel_version|g" \
          -e "s|{{PHP_VERSION}}|$php_version_clean|g" \
          -e "s|{{NODE_VERSION}}|$node_version_clean|g" \
          -e "s|^FROM php:.*-apache|FROM syneidon/laravel:php${safe_php}-nonode|" \
          "$TEMPLATE_FILE" |
          if [[ "$dir" == "$TEST_DIR" ]]; then
            awk -v version="$laravel_version" '
              /# Use non-root user/ {
                print "RUN composer create-project laravel/laravel:^" version ".0 ."
                print "RUN cp .env.example .env \\"
                print " && sed -i \"s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/\" .env \\"
                print " && sed -i \"s/^DB_HOST=.*/DB_HOST=syneidon-laravel-test-db/\" .env \\"
                print " && sed -i \"s/^DB_PORT=.*/DB_PORT=3306/\" .env \\"
                print " && sed -i \"s/^DB_DATABASE=.*/DB_DATABASE=laravel/\" .env \\"
                print " && sed -i \"s/^DB_USERNAME=.*/DB_USERNAME=root/\" .env \\"
                print " && sed -i \"s/^DB_PASSWORD=.*/DB_PASSWORD=password/\" .env \\"
                print " && php artisan key:generate"
                print "RUN chown -R appuser:appuser storage bootstrap/cache"
              }
              { print }
            '
          else
            cat
          fi > "$outfile"

        echo "📄 Created $outfile [${dir##*/}]"
      done
    done
  done
done

# Set default Dockerfiles
latest_safe_php=$(echo "$latest_php" | sed 's/\.//g')
latest_safe_node=$(echo "$latest_node" | sed 's/\.//g')

cp "$DIST_DIR/php${latest_safe_php}-node${latest_safe_node}.Dockerfile" "$DIST_DIR/Dockerfile"
cp "$TEST_DIR/php${latest_safe_php}-node${latest_safe_node}.Dockerfile" "$TEST_DIR/Dockerfile"

echo "🔗 Default Dockerfiles set to php${latest_php} + node${latest_node}"
echo "✅ All Dockerfiles and base images generated successfully."
