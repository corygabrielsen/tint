#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export RELEASE_SCRIPT="$DIR/scripts/release.sh"

    # Create sandbox
    export SANDBOX="$BATS_TEST_TMPDIR"
    mkdir -p "$SANDBOX/bin"

    # Fake tint file (default version, tests can override)
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"

    # Default stub data: tag doesn't exist, no prior tags
    echo -n "" > "$SANDBOX/git-ls-remote.out"
    echo -n "" > "$SANDBOX/git-tags.out"

    _create_stubs

    cd "$SANDBOX" || return
    export PATH="$SANDBOX/bin:$PATH"
}

_create_stubs() {
    # git stub
    cat > "$SANDBOX/bin/git" << 'STUB'
#!/usr/bin/env bash
echo "git $*" >> "$SANDBOX/calls.log"
case "$1" in
    ls-remote)
        cat "$SANDBOX/git-ls-remote.out" 2>/dev/null
        ;;
    tag)
        case "$2" in
            -l) cat "$SANDBOX/git-tags.out" 2>/dev/null ;;
            *)  ;; # create tag — no-op
        esac
        ;;
    rev-parse) echo "abc1234def5678" ;;
    fetch) ;; # no-op
esac
STUB
    chmod +x "$SANDBOX/bin/git"

    # npx stub — handles the three calling patterns release.sh uses:
    #   1. npx semver@7 [--] <ver>            — single version validation
    #   2. npx semver@7 -p <ver> -r "<range>" — exit 0 if ver matches range
    #   3. npx semver@7 [--] <versions...>    — filter valid semver, sort, print
    cat > "$SANDBOX/bin/npx" << 'STUB'
#!/usr/bin/env bash
echo "npx $*" >> "$SANDBOX/calls.log"
shift  # drop "--yes"
shift  # drop "semver@7"
if [ "${1:-}" = "--" ]; then shift; fi

# Pattern 1: npx semver@7 [--] "<ver>" — single version validation
if [ $# -eq 1 ] && [ "$1" != "-p" ]; then
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        echo "$1"
        exit 0
    fi
    exit 1
fi

# Pattern 2: npx semver@7 -p <ver> -r ">latest"
if [ "$1" = "-p" ]; then
    ver="$2"
    # $3 is -r, $4 is the range like ">0.2.0"
    range="$4"
    # Extract the comparison version from ">X.Y.Z"
    latest="${range#>}"

    # Simple version comparison: split into parts
    IFS='.' read -r v1 v2 v3 <<< "${ver%%-*}"
    IFS='.' read -r l1 l2 l3 <<< "${latest%%-*}"

    # Compare major.minor.patch numerically
    if [ "$v1" -gt "$l1" ] 2>/dev/null; then
        exit 0
    elif [ "$v1" -eq "$l1" ] 2>/dev/null; then
        if [ "$v2" -gt "$l2" ] 2>/dev/null; then
            exit 0
        elif [ "$v2" -eq "$l2" ] 2>/dev/null; then
            if [ "$v3" -gt "$l3" ] 2>/dev/null; then
                exit 0
            fi
        fi
    fi
    exit 1
fi

# Pattern 3: npx semver@7 [--] <versions...> — filter & sort valid semver
if [ "${1:-}" = "--" ]; then shift; fi
results=()
for v in "$@"; do
    # Only keep versions matching semver X.Y.Z with optional prerelease
    if [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        results+=("$v")
    fi
done

if [ ${#results[@]} -eq 0 ]; then
    exit 1
fi

# Sort by version (simple lexicographic on dotted numbers works for our tests)
printf '%s\n' "${results[@]}" | sort -t. -k1,1n -k2,2n -k3,3n
STUB
    chmod +x "$SANDBOX/bin/npx"

    # gh stub
    cat > "$SANDBOX/bin/gh" << 'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$SANDBOX/calls.log"
STUB
    chmod +x "$SANDBOX/bin/gh"

    # sha256sum stub
    cat > "$SANDBOX/bin/sha256sum" << 'STUB'
#!/usr/bin/env bash
echo "fakechecksum  $1"
STUB
    chmod +x "$SANDBOX/bin/sha256sum"
}

# =============================================================================
# Version Extraction
# =============================================================================

@test "release: missing tint file exits 1 with clear error" {
    rm "$SANDBOX/tint"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tint file not found"* ]]
}

@test "release: multiple TINT_VERSION lines exits 1 with clear error" {
    printf 'TINT_VERSION="0.2.0"\nTINT_VERSION="0.3.0"\n' > "$SANDBOX/tint"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"exactly one TINT_VERSION"* ]]
}

@test "release: whitespace in version is trimmed" {
    echo 'TINT_VERSION=" 0.3.0 "' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.3.0"* ]]
}

# =============================================================================
# Idempotency
# =============================================================================

@test "release: already-released tag exits 0 with message" {
    echo "abc1234 refs/tags/v0.3.0" > "$SANDBOX/git-ls-remote.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
}

# =============================================================================
# Format Validation
# =============================================================================

@test "release: valid semver passes format validation" {
    echo 'TINT_VERSION="1.2.3"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v1.2.3"* ]]
}

@test "release: valid semver with prerelease passes format validation" {
    echo 'TINT_VERSION="1.2.3-beta.1"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v1.2.3-beta.1"* ]]
}

@test "release: invalid semver (two-part) exits 1" {
    echo 'TINT_VERSION="1.2"' > "$SANDBOX/tint"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid version"* ]]
}

@test "release: invalid semver (letters) exits 1" {
    echo 'TINT_VERSION="abc"' > "$SANDBOX/tint"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid version"* ]]
}

@test "release: npx failure during format validation exits 1" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"

    # Replace npx stub with one that crashes
    cat > "$SANDBOX/bin/npx" << 'STUB'
#!/usr/bin/env bash
echo "npx error: command not found" >&2
exit 127
STUB
    chmod +x "$SANDBOX/bin/npx"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid version"* ]]
}

# =============================================================================
# Ordering Validation
# =============================================================================

@test "release: version greater than latest proceeds" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.3.0"* ]]
}

@test "release: version equal to latest exits 1" {
    echo 'TINT_VERSION="0.2.0"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not greater than"* ]]
}

@test "release: version less than latest exits 1" {
    echo 'TINT_VERSION="0.1.0"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not greater than"* ]]
}

@test "release: first release (no tags) skips ordering check" {
    echo 'TINT_VERSION="0.1.0"' > "$SANDBOX/tint"
    echo -n "" > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.1.0"* ]]
}

@test "release: all-invalid tags skips ordering check" {
    echo 'TINT_VERSION="0.1.0"' > "$SANDBOX/tint"
    printf 'vnext\nvlatest\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.1.0"* ]]
}

@test "release: mixed valid/invalid tags uses valid ones only" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"
    printf 'vnext\nv0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.3.0"* ]]
}

@test "release: dash-prefixed tags are not parsed as CLI flags" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"
    printf 'v-r\nv0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v0.3.0"* ]]
}

@test "release: prerelease version greater than stable passes" {
    echo 'TINT_VERSION="1.0.0"' > "$SANDBOX/tint"
    printf 'v0.2.0-beta.1\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Released v1.0.0"* ]]
}

@test "release: npx failure during ordering check exits 1" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    # npx stub that works for validation but crashes for sorting (no output)
    cat > "$SANDBOX/bin/npx" << 'STUB'
#!/usr/bin/env bash
shift  # drop --yes
shift  # drop semver@7
if [ "${1:-}" = "--" ]; then shift; fi
# Single-version validation: succeed
if [ $# -eq 1 ] && [ "$1" != "-p" ]; then
    echo "$1"
    exit 0
fi
# Multi-version sorting: crash with no output
exit 1
STUB
    chmod +x "$SANDBOX/bin/npx"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"produced no output"* ]]
}

# =============================================================================
# Happy Path
# =============================================================================

@test "release: full flow creates release with --target" {
    echo 'TINT_VERSION="0.3.0"' > "$SANDBOX/tint"
    printf 'v0.1.0\nv0.2.0\n' > "$SANDBOX/git-tags.out"

    run "$RELEASE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Releasing v0.3.0"* ]]
    [[ "$output" == *"Released v0.3.0"* ]]

    # Verify gh release create is called with --target (tag created via API, not git)
    run cat "$SANDBOX/calls.log"
    [[ "$output" == *"gh release create v0.3.0 --target abc1234def5678"* ]]
    # No local git tag or push
    [[ "$output" != *"git tag v0.3.0"* ]]
    [[ "$output" != *"git push origin v0.3.0"* ]]
    [[ "$output" != *"git config"* ]]
}
