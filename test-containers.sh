#!/usr/bin/env bash

set -e

COMPOSE_TEMPLATE="./test/docker-compose.test.yaml"
TEMP_COMPOSE="./test/docker-compose.temp.yaml"
LARAVEL_PORT=80

# Check for curl
if ! command -v curl &>/dev/null; then
  echo "❌ curl is required for health checks."
  exit 1
fi

# Loop over all simplified Dockerfiles in ./test
find ./test -maxdepth 1 -type f -name 'php*-node*.Dockerfile' | sort | while read -r dockerfile; do
  filename=$(basename "$dockerfile")                         # e.g. php82-node20.Dockerfile
  name="${filename%.Dockerfile}"                             # e.g. php82-node20
  tag_name="syneidon-laravel-test:${name}"                   # e.g. syneidon-laravel-test:php82-node20

  echo ""
  echo "🔧 Building image: $tag_name"
  docker build -f "$dockerfile" -t "$tag_name" ./test

  echo "📄 Preparing docker-compose file..."
  sed "s|ordinov/php-apache-laravel:latest|$tag_name|" "$COMPOSE_TEMPLATE" > "$TEMP_COMPOSE"

  echo "🚀 Starting test container for $tag_name..."
  docker-compose -f "$TEMP_COMPOSE" up -d

  echo "⏳ Waiting for Laravel to become available at http://localhost:$LARAVEL_PORT..."
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

  echo "✅ Laravel is up and responding for $tag_name"

  echo "🧹 Cleaning up containers..."
  docker-compose -f "$TEMP_COMPOSE" down -v
done

echo ""
echo "🎉 All test containers built and verified successfully."
