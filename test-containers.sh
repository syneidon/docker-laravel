#!/usr/bin/env bash

set -e

MATRIX_FILE="./src/versions-matrix.json"
COMPOSE_TEMPLATE="./docker-compose.test.yaml"
TEMP_COMPOSE="./test/docker-compose.temp.yaml"
DIST_DIR="./dist"
LARAVEL_PORT=8089

# Ensure required tools are available
for tool in curl docker docker-compose jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "❌ $tool is required but not installed."
    exit 1
  fi
done

echo "🔍 Testing Laravel combinations from matrix..."

jq -r 'to_entries[] | "\(.key)|\(.value.php[])|\(.value.node[])"' "$MATRIX_FILE" | while IFS='|' read -r laravel_version php_version node_version; do
  safe_php=$(echo "$php_version" | sed 's/\.//g')
  safe_node=$(echo "$node_version" | sed 's/\.//g')
  dockerfile="$DIST_DIR/php${safe_php}-node${safe_node}.Dockerfile"
  tag_name="syneidon-laravel-test:php${safe_php}-node${safe_node}"

  if [[ ! -f "$dockerfile" ]]; then
    echo "⚠️  Dockerfile not found for php${safe_php}-node${safe_node}, skipping..."
    continue
  fi

  echo ""
  echo "🔧 Building image: $tag_name"
  docker build -f "$dockerfile" -t "$tag_name" "$DIST_DIR"

  echo "📄 Preparing docker-compose file..."
  mkdir -p "$(dirname "$TEMP_COMPOSE")"
  sed "s|syneidon/laravel:latest|$tag_name|" "$COMPOSE_TEMPLATE" > "$TEMP_COMPOSE"

  echo "🚀 Starting container for php${safe_php}-node${safe_node}..."
  docker-compose -f "$TEMP_COMPOSE" up -d

  container_id=$(docker-compose -f "$TEMP_COMPOSE" ps -q syneidon-laravel-test-app)

  echo "🧹 Cleaning Laravel folder before installation..."
  docker exec "$container_id" bash -c 'rm -rf /var/www/html/.* /var/www/html/* || true'

  # Laravel version string is like "v8", remove "v" for composer constraint
  laravel_major_version=$(echo "$laravel_version" | sed 's/^v//')
  echo "🧱 Installing Laravel ${laravel_version} inside the container..."
  docker exec "$container_id" bash -c "composer create-project laravel/laravel:^${laravel_major_version}.0 . --quiet"
  docker exec "$container_id" cp .env.example .env
  docker exec "$container_id" php artisan key:generate

  echo "⏳ Waiting for Laravel to be available on :$LARAVEL_PORT..."
  timeout=60
  elapsed=0
  until curl -sSf "http://localhost:$LARAVEL_PORT" > /dev/null 2>&1; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "❌ Timeout: Laravel did not start in $timeout seconds for $tag_name"
      docker-compose -f "$TEMP_COMPOSE" down -v
      exit 1
    fi
  done

  echo "✅ Laravel container is live for $tag_name"

  echo "🧪 Running runtime checks..."
  docker exec "$container_id" composer dump-autoload
  docker exec "$container_id" php artisan cache:clear
  docker exec "$container_id" curl --version >/dev/null

  actual_node_version=$(docker exec "$container_id" node --version | sed 's/^v//' | cut -d. -f1)
  if [[ "$actual_node_version" != "$safe_node" ]]; then
    echo "❌ Node.js version mismatch: expected $safe_node.x, got v$actual_node_version"
    docker-compose -f "$TEMP_COMPOSE" down -v
    exit 1
  fi

  docker exec "$container_id" npm install -g yarn
  docker exec "$container_id" yarn --version

  echo "✅ Runtime checks passed for $tag_name"

  echo "🧹 Cleaning up..."
  docker-compose -f "$TEMP_COMPOSE" down -v
done

echo ""
echo "🎉 All containers tested successfully!"
