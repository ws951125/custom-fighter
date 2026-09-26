#!/usr/bin/env bash
# Same-origin, source-pinned PR preview for a public GitHub Pages project.
# It never executes preview code; it attaches already validated static Web assets.
# Missing/expired PR artifacts must not stop deployment of the validated main Web root.
set -euo pipefail
: "$GITHUB_REPOSITORY" "$GITHUB_OUTPUT" "$GH_TOKEN" "$PREVIEW_RUN_ID" "$PREVIEW_HEAD_SHA"
preview_dir="build/web/preview/pr-212"
enabled=false
record_result() { printf 'enabled=%s\n' "$enabled" >> "$GITHUB_OUTPUT"; }
trap record_result EXIT

if ! run_record="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$PREVIEW_RUN_ID" --jq '[.head_sha, .status, .conclusion] | @tsv' 2>/dev/null)"; then
  echo '::warning::Gallery preview run metadata is unavailable; main site remains deployable.'
  exit 0
fi
expected="$(printf '%s\tcompleted\tsuccess' "$PREVIEW_HEAD_SHA")"
if [[ "$run_record" != "$expected" ]]; then
  echo '::warning::Gallery preview run is not SUCCESS at the pinned source SHA; omit preview.'
  exit 0
fi

mkdir -p "$preview_dir"
if ! gh run download "$PREVIEW_RUN_ID" --repo "$GITHUB_REPOSITORY" --name custom-fighter-web --dir "$preview_dir"; then
  rm -rf "$preview_dir"
  echo '::warning::Gallery preview artifact unavailable or expired; main site remains deployable.'
  exit 0
fi
if [[ ! -s "$preview_dir/index.html" || ! -s "$preview_dir/index.js" ]]; then
  rm -rf "$preview_dir"
  echo '::warning::Gallery preview artifact is incomplete; omit preview.'
  exit 0
fi
printf '%s\n' "$PREVIEW_HEAD_SHA" > "$preview_dir/preview-source.txt"
enabled=true
echo "WU5_PAGES_PREVIEW_ATTACHED source=$PREVIEW_HEAD_SHA path=/preview/pr-212/"
