#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Running all tests..."
for dir in exercises/chapter*/; do
  if [ -f "$dir/gleam.toml" ]; then
    echo "  Testing $dir..."
    (cd "$dir" && gleam test) || true
  fi
done

echo "==> Done."
