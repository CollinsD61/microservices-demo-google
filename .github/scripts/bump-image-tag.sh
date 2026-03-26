#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <new-tag> [values-file]" >&2
  exit 1
fi

new_tag="$1"
values_file="${2:-helm-chart/values.yaml}"

if [[ ! -f "$values_file" ]]; then
  echo "Values file not found: $values_file" >&2
  exit 1
fi

tmp_file="${values_file}.tmp"

awk -v tag="$new_tag" '
BEGIN {
  in_images = 0
  updated = 0
}
{
  if ($0 ~ /^images:[[:space:]]*$/) {
    in_images = 1
    print
    next
  }

  if (in_images == 1 && $0 ~ /^[^[:space:]]/) {
    in_images = 0
  }

  if (in_images == 1 && updated == 0 && $0 ~ /^[[:space:]]*tag:[[:space:]]*/) {
    print "  tag: \"" tag "\""
    updated = 1
    next
  }

  print
}
END {
  if (updated == 0) {
    exit 2
  }
}
' "$values_file" > "$tmp_file"

mv "$tmp_file" "$values_file"
