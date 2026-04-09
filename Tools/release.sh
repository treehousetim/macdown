#!/usr/bin/env bash
#
# Tools/release.sh — build, sign, notarize, staple, and publish a
# treehousetim release of MacDown to GitHub.
#
# Usage:
#   ./Tools/release.sh                       # uses CFBundleShortVersionString from Info.plist as the tag version
#   ./Tools/release.sh 1.0.1                 # bumps the source plist to 1.0.1, then releases
#   ./Tools/release.sh 1.0.1 --dry-run       # do everything locally but don't tag, push, or publish
#
# Pre-conditions (one-time setup, not handled here):
#   * Developer ID Application identity installed in the login keychain
#   * `xcrun notarytool store-credentials macdown-notary --apple-id <id> --team-id <id>` already run
#   * `gh auth login` already run for github.com / treehousetim
#   * Working tree is clean (no uncommitted changes other than the version bump this script makes)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ----- args -----------------------------------------------------------------

NEW_VERSION=""
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            sed -n '3,15p' "$0"
            exit 0
            ;;
        -*) echo "unknown flag: $arg" >&2; exit 2 ;;
        *)  NEW_VERSION="$arg" ;;
    esac
done

INFO_PLIST="MacDown/MacDown-Info.plist"
KEYCHAIN_PROFILE="macdown-notary"
SCHEME="MacDown"
DEPLOYMENT_TARGET="14.0"
GITHUB_REPO="treehousetim/macdown"

# ----- step 1: version ------------------------------------------------------

if [[ -n "$NEW_VERSION" ]]; then
    echo "==> Setting CFBundleShortVersionString to $NEW_VERSION in $INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
TAG="v${VERSION}"
ZIP="MacDown-${VERSION}.zip"

# Apple's CFBundleShortVersionString must be X[.Y[.Z]] all numeric.
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "ERROR: version '$VERSION' is not a valid CFBundleShortVersionString (must be X[.Y[.Z]] numeric)" >&2
    exit 1
fi

echo "==> Releasing version $VERSION (tag $TAG)"
$DRY_RUN && echo "    (dry run — will skip tag, push, and release create)"

# ----- step 2: commit + tag + push ------------------------------------------

if ! $DRY_RUN; then
    if ! git diff --quiet -- "$INFO_PLIST"; then
        echo "==> Committing version bump"
        git add "$INFO_PLIST"
        git commit -m "Bump version to $VERSION for $TAG release"
    fi

    if git rev-parse --quiet --verify "refs/tags/$TAG" >/dev/null; then
        echo "ERROR: tag $TAG already exists locally; refusing to overwrite" >&2
        echo "       delete it explicitly with: git tag -d $TAG && git push origin :refs/tags/$TAG" >&2
        exit 1
    fi

    echo "==> Tagging $TAG"
    git tag -a "$TAG" -m "treehousetim release $TAG"

    echo "==> Pushing master and $TAG"
    git push origin master "$TAG"
fi

# ----- step 3: clean build --------------------------------------------------

echo "==> Cleaning previous build"
rm -rf build

echo "==> xcodebuild Release (this takes a couple minutes)"
env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin" \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    xcodebuild \
        -workspace MacDown.xcworkspace \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath build \
        MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    > /tmp/macdown_release_build.log 2>&1

if ! grep -q "BUILD SUCCEEDED" /tmp/macdown_release_build.log; then
    echo "ERROR: xcodebuild failed; see /tmp/macdown_release_build.log" >&2
    tail -30 /tmp/macdown_release_build.log >&2
    exit 1
fi

APP="build/Build/Products/Release/MacDown.app"

# ----- step 4: verify no debug entitlements ---------------------------------

echo "==> Checking for forbidden debug entitlements"
for bin in \
    "$APP/Contents/MacOS/MacDown" \
    "$APP/Contents/PlugIns/MacDownQuickLook.appex/Contents/MacOS/MacDownQuickLook" \
    "$APP/Contents/SharedSupport/bin/macdown" ; do
    if codesign -d --entitlements - "$bin" 2>/dev/null | grep -q "get-task-allow"; then
        echo "ERROR: $bin has com.apple.security.get-task-allow — notary will reject" >&2
        exit 1
    fi
done

# ----- step 5: zip ----------------------------------------------------------

ZIP_PATH="build/Build/Products/Release/$ZIP"
echo "==> Creating $ZIP"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent --sequesterRsrc "$APP" "$ZIP_PATH"

# ----- step 6: notarize -----------------------------------------------------

echo "==> Submitting to Apple notary service (typical wait: 2-10 minutes)"
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# notarytool exits nonzero on Invalid; set -e aborts here if rejected.

# ----- step 7: staple + re-zip ----------------------------------------------

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Re-zipping stapled .app"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent --sequesterRsrc "$APP" "$ZIP_PATH"

SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "==> SHA-256: $SHA"

# ----- step 8: gh release ---------------------------------------------------

if $DRY_RUN; then
    echo "==> Dry run: skipping gh release create"
    echo "    artifact ready at: $ZIP_PATH"
    exit 0
fi

NOTES_FILE="$(mktemp -t macdown-release-notes)"
cat > "$NOTES_FILE" <<NOTES
treehousetim release $TAG of MacDown.

Universal binary, Developer ID signed, notarized by Apple, hardened runtime.
Built against the macOS 14 (Sonoma) deployment target and later.

## Install

1. Download \`$ZIP\`.
2. Unzip and drag \`MacDown.app\` to \`/Applications\`.
3. Launch.

## Verify integrity

\`\`\`
shasum -a 256 $ZIP
# $SHA

xcrun stapler validate /Applications/MacDown.app
\`\`\`

## Credit

Original MacDown by Tzu-ping Chung and contributors. This binary is a fork build, not an upstream release.
NOTES

echo "==> Creating GitHub release $TAG on $GITHUB_REPO"
gh release create "$TAG" "$ZIP_PATH" \
    --repo "$GITHUB_REPO" \
    --title "$TAG" \
    --notes-file "$NOTES_FILE"

rm -f "$NOTES_FILE"

echo
echo "==> Done. Release published at:"
echo "    https://github.com/$GITHUB_REPO/releases/tag/$TAG"
