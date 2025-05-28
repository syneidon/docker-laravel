#!/usr/bin/env bash

set -e

DRY_RUN=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    *) echo "❌ Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# set timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Configuration
MATRIX_FILE="./src/versions-matrix.json"
RELEASES_FILE="./src/releases.json"
TEMPLATE_FILE="./src/Dockerfile.tpl"
NODE_TEMPLATE_FILE="./src/Dockerfile-node.tpl"
BASE_DIST_DIR="./dist"
DIST_DIR="${BASE_DIST_DIR}/${TIMESTAMP}"
REPO="syneidon/laravel"

# Read suffixes
BASE_SUFFIX=$(jq -r '.base' "$RELEASES_FILE")
NODE_SUFFIX=$(jq -r '.node' "$RELEASES_FILE")

[[ -z "$BASE_SUFFIX" || -z "$NODE_SUFFIX" ]] && {
  echo "❌ Invalid or missing suffix in releases.json"
  exit 1
}

# Prepare directories
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "./logs"

# Log setup
JSON_FILE="./logs/build-${TIMESTAMP}.json"
echo "[]" > "$JSON_FILE"

# Stub out logging to log file
write_group_log() {
  :
}

append_json_entry() {
  local title="$1"
  local digest="$2"
  shift 2
  local tags=("$@")
  json_tags=$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)
  jq --arg title "$title" --arg digest "$digest" --argjson tags "$json_tags" '
    if any(.[]; .title == $title) then
      map(if .title == $title then
            .tags += $tags | .tags |= unique | .digest = $digest
          else .
          end)
    else
      . + [{"title": $title, "tags": $tags, "digest": $digest}]
    end
  ' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

# Build base images
declare -A seen_php
echo -e "\n🔧 Building base images..."
jq -r '.[] | .php[]' "$MATRIX_FILE" | sort -u | while read -r php_version; do
  php_version=$(echo "$php_version" | tr -d '\r\n')
  safe_php=$(echo "$php_version" | sed 's/\.//g')
  base_tag="php${safe_php}-nonode"
  full_tag="${base_tag}-${BASE_SUFFIX}"
  base_file="$DIST_DIR/${base_tag}-${BASE_SUFFIX}.Dockerfile"
  [[ -n "${seen_php[$safe_php]}" ]] && continue
  seen_php[$safe_php]=1

  sed -e "s|{{LARAVEL_VERSION}}|placeholder|g" \
      -e "s|{{PHP_VERSION}}|$php_version|g" "$TEMPLATE_FILE" > "$base_file"

  all_tags=("$base_tag" "$full_tag")
  write_group_log "$REPO:$base_tag" "${all_tags[@]}"

  digest="sha256:<dry-run>"
  append_json_entry "$REPO:$full_tag" "$digest" "${all_tags[@]}"
done

# Build node images
echo -e "\n🔧 Building Node-enabled images..."
laravel_versions=$(jq -r 'keys[]' "$MATRIX_FILE")
for laravel_version in $laravel_versions; do
  laravel_version=$(echo "$laravel_version" | tr -d '\r')
  php_versions=$(jq -r --arg v "$laravel_version" '.[$v].php // [] | .[]' "$MATRIX_FILE")
  node_versions=$(jq -r --arg v "$laravel_version" '.[$v].node // [] | .[]' "$MATRIX_FILE")
  # Aggiunta delle variabili per la combinazione primaria
  last_php=$(jq -r --arg v "$laravel_version" '.[$v].php | last' "$MATRIX_FILE")
  last_node=$(jq -r --arg v "$laravel_version" '.[$v].node | last' "$MATRIX_FILE")
  
  for php_version in $php_versions; do
    safe_php=$(echo "$php_version" | sed 's/\.//g')
    for node_version in $node_versions; do
      safe_node=$(echo "$node_version" | sed 's/\.//g')
      combo_tag="php${safe_php}-node${safe_node}"
      full_tag="${combo_tag}-${NODE_SUFFIX}"
      base_tag="php${safe_php}-nonode-${BASE_SUFFIX}"
      outfile="$DIST_DIR/${combo_tag}-${NODE_SUFFIX}.Dockerfile"

      sed -e "s|{{NODE_VERSION}}|$node_version|g" \
          -e "s|{{BASE_IMAGE}}|$REPO:$base_tag|g" "$NODE_TEMPLATE_FILE" > "$outfile"

      stable_tags=("$combo_tag" "v${laravel_version#v}-$combo_tag")
      # Modifica della condizione: aggiunge tag vX solo per la combinazione primaria
      if [[ "$php_version" == "$last_php" && "$node_version" == "$last_node" ]]; then
        stable_tags+=("v${laravel_version#v}")
      fi

      all_tags=()
      for tag in "${stable_tags[@]}"; do
        all_tags+=("$tag")
        all_tags+=("${tag}-${NODE_SUFFIX}")
      done

      build_args=()
      for tag in "${all_tags[@]}"; do
        build_args+=("-t" "$REPO:$tag")
      done

      digest="sha256:<dry-run>"
      append_json_entry "$REPO:$full_tag" "$digest" "${all_tags[@]}"
    done
  done
done

echo -e "\n✅ Release complete."
echo "📝 JSON blueprint written to: $JSON_FILE"

if [ "$DRY_RUN" = false ]; then
  echo "🛑 Dry run mode disabled. Images are going to be built and pushed..."

  tmp_json="${JSON_FILE}.tmp"
  echo "[]" > "$tmp_json"

  jq -c '.[]' "$JSON_FILE" | while read -r entry; do
    title=$(echo "$entry" | jq -r '.title')
    dockerfile_tag=${title##*:}
    dockerfile_path="$DIST_DIR/${dockerfile_tag}.Dockerfile"
    tags=$(echo "$entry" | jq -r '.tags[]' | grep -v '^\s*$') # remove empty lines

    # Skip invalid dockerfile path
    if [[ ! -f "$dockerfile_path" ]]; then
      echo "⚠️ Dockerfile not found: $dockerfile_path. Skipping $title"
      continue
    fi

    # Build image with first valid tag
    first_tag=$(echo "$tags" | head -n1)
    echo "🚧 Building $REPO:$first_tag from $dockerfile_path..."
    docker build -f "$dockerfile_path" -t "$REPO:$first_tag" .

    # Apply all other tags
    echo "$tags" | tail -n +2 | while read -r tag; do
      [[ -n "$tag" ]] && docker tag "$REPO:$first_tag" "$REPO:$tag"
    done

    # Push all tags
    digest=""
    for tag in $tags; do
      if [[ "$tag" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "📤 Pushing $REPO:$tag..."
        docker push "$REPO:$tag" | tee /tmp/push-output.log
        if [[ -z "$digest" ]]; then
          digest=$(grep -o 'sha256:[a-f0-9]\{64\}' /tmp/push-output.log | head -n1)
          if [[ -z "$digest" ]]; then
            echo "❌ Failed to extract digest for $REPO:$tag"
            digest="sha256:unknown"
          fi
        fi
      else
        echo "❌ Invalid tag format: '$tag' — skipping"
      fi
    done

    # Rebuild JSON entry
    json_tags=$(echo "$tags" | jq -R . | jq -s .)
    jq --arg title "$title" --arg digest "$digest" --argjson tags "$json_tags" \
      '. + [{"title": $title, "tags": $tags, "digest": $digest}]' "$tmp_json" > "$tmp_json.new" && mv "$tmp_json.new" "$tmp_json"
  done

  mv "$tmp_json" "$JSON_FILE"
  echo "✅ Docker images built, pushed, and digests recorded in: $JSON_FILE"
fi
