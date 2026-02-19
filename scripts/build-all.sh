#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building all exercise packages..."
for dir in exercises/chapter*/; do
  if [ -f "$dir/gleam.toml" ]; then
    echo "  Building $dir..."
    (cd "$dir" && gleam build)
  fi
done

echo "==> Building book..."
mdbook build

echo "==> Done."
