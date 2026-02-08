#!/usr/bin/env bash
set -euo pipefail

# Extract version from tint script
version=$(grep '^TINT_VERSION=' tint | cut -d'"' -f2)
tag="v$version"

echo "Releasing $tag"

# Create and push tag
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git tag "$tag"
git push origin "$tag"

# Create GitHub release with checksum
sha256sum tint > tint.sha256
gh release create "$tag" \
    --title "$tag" \
    --generate-notes \
    tint tint.sha256

echo "Released $tag"
