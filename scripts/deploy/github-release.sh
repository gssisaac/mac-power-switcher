#!/usr/bin/env bash
# Create or update a GitHub release with the notarized DMG. Requires gh CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${MAC_POWER_SWITCHER_VERSION:?MAC_POWER_SWITCHER_VERSION required}"
NOTES_FILE="${MAC_POWER_SWITCHER_RELEASE_NOTES:?MAC_POWER_SWITCHER_RELEASE_NOTES required}"
TAG="v${VERSION}"

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ gh CLI not found. Install: brew install gh"
  exit 1
fi

DMG="$ROOT/dist/MacPowerSwitcher.dmg"
if [[ ! -f "$DMG" ]]; then
  echo "✗ No dist/MacPowerSwitcher.dmg found. Run bash scripts/deploy/build-macos.sh first."
  exit 1
fi

echo "→ GitHub release ${TAG}"

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG" --clobber
  gh release edit "$TAG" --title "Mac Power Switcher ${VERSION}" --notes-file "$NOTES_FILE"
  echo "✓ Updated release ${TAG}"
else
  gh release create "$TAG" "$DMG" --title "Mac Power Switcher ${VERSION}" --notes-file "$NOTES_FILE"
  echo "✓ Created release ${TAG}"
fi
