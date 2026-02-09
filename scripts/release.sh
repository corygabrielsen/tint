#!/usr/bin/env bash
set -euo pipefail

# Guard: only run in CI
[ -n "${CI:-}" ] || { echo "::error::release.sh must be run in CI" >&2; exit 1; }

# Extract version from tint script
[ -f tint ] || { echo "::error::tint file not found" >&2; exit 1; }
[ "$(grep -c '^TINT_VERSION=' tint)" -eq 1 ] || { echo "::error::Expected exactly one TINT_VERSION in tint" >&2; exit 1; }
version=$(grep '^TINT_VERSION=' tint | cut -d'"' -f2 | tr -d '[:space:]')
tag="v$version"

# Skip if already released
if git ls-remote --tags origin "$tag" | grep -q "refs/tags/$tag$"; then
    echo "$tag already exists, nothing to release"
    exit 0
fi

# Validate semver format — must be canonical (npx semver normalizes loose inputs)
canonical=$(npx --yes semver@7 -- "$version" 2>/dev/null) || true
if [ -z "$canonical" ] || [ "$canonical" != "$version" ]; then
    echo "::error::Invalid version: $version (expected canonical semver like 1.2.3)" >&2
    exit 1
fi

# Validate version is newer than latest release
git fetch --tags --force --quiet
tags=$(git tag -l 'v*' | sed -n 's/^v\([0-9]\)/\1/p')
if [ -n "$tags" ]; then
    # Sentinel: 0.0.0-0 is the lowest possible semver, guaranteed valid input.
    # If npx is functional, output always contains at least the sentinel.
    # Empty output = npx crashed (not "all tags invalid").
    # shellcheck disable=SC2086
    latest=$(npx --yes semver@7 -- 0.0.0-0 $tags 2>/dev/null | tail -1) || true
    if [ -z "$latest" ]; then
        echo "::error::npx --yes semver@7 produced no output (is npx installed and working?)" >&2
        exit 1
    fi
    if [ "$latest" != "0.0.0-0" ]; then
        if ! npx --yes semver@7 -p "$version" -r ">$latest" >/dev/null 2>&1; then
            echo "::error::Version $version is not greater than $latest" >&2
            exit 1
        fi
    fi
fi

echo "Releasing $tag"

# Create GitHub release with checksum
# gh release create creates the tag via the GitHub API — if it fails, neither
# the tag nor the release exist, so retries start clean (no orphaned tags).
sha256sum tint > tint.sha256
gh release create "$tag" \
    --target "$(git rev-parse HEAD)" \
    --title "$tag" \
    --generate-notes \
    tint tint.sha256

echo "Released $tag"
