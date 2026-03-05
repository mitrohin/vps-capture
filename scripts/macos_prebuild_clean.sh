#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "$ROOT_DIR/build/macos" ]]; then
  echo "No build/macos directory found, nothing to clean."
  exit 0
fi

removed=0
while IFS= read -r -d '' file; do
  rm -f "$file"
  echo "Removed stale bundle data file: ${file#$ROOT_DIR/}"
  removed=$((removed + 1))
done < <(find "$ROOT_DIR/build/macos" -type f \
  \( -path '*/Contents/MacOS/schedule.json' -o -path '*/Contents/MacOS/test/*' \) -print0)

if [[ $removed -eq 0 ]]; then
  echo "No stale mutable files found inside macOS app bundle."
else
  echo "Cleaned $removed stale file(s) from macOS app bundle."
fi
