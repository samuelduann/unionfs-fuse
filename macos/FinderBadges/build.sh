#!/bin/sh
set -eu
SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SOURCE_DIR/../.." && pwd)
OUTPUT_DIR=${1:-"$REPO_DIR/build/finder-badges"}
APP="$OUTPUT_DIR/UnionFS Finder Badges.app"
EXT="$APP/Contents/PlugIns/UnionFSFinderSync.appex"
mkdir -p "$APP/Contents/MacOS" "$EXT/Contents/MacOS"

# No Xcode project required: Apple's Command Line Tools include these SDKs.
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=11.0 \
    -framework AppKit -framework FinderSync "$SOURCE_DIR/main.m" \
    -o "$APP/Contents/MacOS/UnionFSFinderBadges"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=11.0 \
    -fapplication-extension -iquote "$REPO_DIR/src" -framework AppKit -framework FinderSync \
    -Wl,-e,_NSExtensionMain "$SOURCE_DIR/FinderSync.m" \
    -o "$EXT/Contents/MacOS/UnionFSFinderSync"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.unionfs-fuse.finder-badges</string>
<key>CFBundleName</key><string>UnionFS Finder Badges</string>
<key>CFBundleExecutable</key><string>UnionFSFinderBadges</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
cat > "$EXT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.unionfs-fuse.finder-badges.extension</string>
<key>CFBundleName</key><string>UnionFS Finder Badges</string>
<key>CFBundleDisplayName</key><string>UnionFS Finder Badges</string>
<key>CFBundleExecutable</key><string>UnionFSFinderSync</string>
<key>CFBundlePackageType</key><string>XPC!</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSExtension</key><dict>
<key>NSExtensionPointIdentifier</key><string>com.apple.FinderSync</string>
<key>NSExtensionPrincipalClass</key><string>UnionFSFinderSync</string>
<key>NSExtensionAttributes</key><dict/>
</dict>
</dict></plist>
PLIST
# Local development signing. Use SIGN_IDENTITY for a real signing certificate.
codesign --force --sign "${SIGN_IDENTITY:--}" --entitlements "$SOURCE_DIR/extension.entitlements" "$EXT"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "$APP"
