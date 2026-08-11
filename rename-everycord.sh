#!/usr/bin/env bash

set -euo pipefail

ROOT="${1:-$(pwd)}"
FROM="everycord"
TO="everycord"

echo "========================================"
echo " OpenCord → EveryCord"
echo "========================================"
echo
echo "Root: $ROOT"
echo "Replacing: '$FROM' → '$TO'"
echo

# Safety check
if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: Directory does not exist: $ROOT"
    exit 1
fi

if [[ ! -d "$ROOT/.git" ]]; then
    echo "WARNING: $ROOT does not appear to be a Git repository."
    read -r -p "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

echo "[1/3] Replacing text inside files..."

# Replace text recursively.
# -I skips binary files
# -l outputs filenames only
# Excludes Git, dependencies, build output and caches.
grep -RIl \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=dist \
    --exclude-dir=build \
    --exclude-dir=.cache \
    --exclude-dir=.turbo \
    --exclude-dir=coverage \
    --exclude-dir=.next \
    --exclude-dir=.vite \
    "$FROM" "$ROOT" 2>/dev/null |
while IFS= read -r file; do
    echo "  Updating: ${file#$ROOT/}"

    # Perl handles files safely without shell interpolation problems.
    perl -pi -e "s/\Q$FROM\E/$TO/g" "$file"
done

echo
echo "[2/3] Renaming files/directories containing '$FROM'..."

# Rename deepest paths first so directory renames don't break later paths.
find "$ROOT" \
    -depth \
    -not -path "$ROOT/.git*" \
    -not -path "$ROOT/node_modules*" \
    -not -path "$ROOT/dist*" \
    -not -path "$ROOT/build*" \
    -not -path "$ROOT/.cache*" \
    -not -path "$ROOT/.turbo*" \
    -not -path "$ROOT/coverage*" \
    -not -path "$ROOT/.next*" \
    -not -path "$ROOT/.vite*" \
    -print0 |
while IFS= read -r -d '' path; do
    base="$(basename "$path")"
    dir="$(dirname "$path")"

    if [[ "$base" == *"$FROM"* ]]; then
        newbase="${base//$FROM/$TO}"
        newpath="$dir/$newbase"

        if [[ "$path" != "$newpath" ]]; then
            echo "  Renaming: ${path#$ROOT/}"
            echo "        -> ${newpath#$ROOT/}"
            mv -- "$path" "$newpath"
        fi
    fi
done

echo
echo "[3/3] Checking for remaining occurrences..."

remaining="$(grep -RIn \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=dist \
    --exclude-dir=build \
    --exclude-dir=.cache \
    --exclude-dir=.turbo \
    --exclude-dir=coverage \
    --exclude-dir=.next \
    --exclude-dir=.vite \
    "$FROM" "$ROOT" 2>/dev/null || true)"

if [[ -n "$remaining" ]]; then
    echo
    echo "WARNING: Remaining occurrences were found:"
    echo "$remaining"
else
    echo "No remaining '$FROM' occurrences found."
fi

echo
echo "========================================"
echo " Replacement complete"
echo "========================================"
echo
echo "Recommended next step:"
echo "  git diff --stat"
echo "  git diff"
