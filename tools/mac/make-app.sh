#!/usr/bin/env bash
# Packages a macOS build of the USA version as "Deadly Premonition Recomp.app"
# and a zip of it: the game, the ReXGlue SDK libraries, the Vulkan loader and
# MoltenVK the build uses, the Mac default settings (deadlyprem.toml next to
# this script), the texture replacements, the icon and the license texts,
# ad-hoc signed.
#
# The app keeps the game data, saves, settings and logs in
# ~/Library/Application Support/DPRecomp (PortableRoot in deadlyprem_app.h);
# its first launch asks for the disc image.
#
# Usage: tools/mac/make-app.sh [build dir] [output dir]
#   build dir   default: usa/out/build/mac-arm64-release
#   output dir  default: dist
# GAMECONTROLLERDB=<file> also bundles SDL's controller database
# (gamecontrollerdb.txt); without it SDL's built-in mappings are used.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BUILD="$(cd "${1:-$REPO/usa/out/build/mac-arm64-release}" && pwd)"
OUT="${2:-$REPO/dist}"
NAME="Deadly Premonition Recomp"
APP="$OUT/$NAME.app"
VERSION="2.0.14"
BUNDLE_ID="${BUNDLE_ID:-local.dprecomp.deadlyprem-usa}"

[ -x "$BUILD/deadlyprem_usa" ] || { echo "No deadlyprem_usa in $BUILD" >&2; exit 1; }
[ -f "$BUILD/vulkan/lib/libMoltenVK.dylib" ] || { echo "No vulkan/lib in $BUILD" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" \
         "$APP/Contents/Resources/vulkan/icd.d" "$APP/Contents/Resources/textures"

# The game, and the GPU plugin, which the runtime loads from the game's folder.
cp "$BUILD/deadlyprem_usa" "$APP/Contents/MacOS/"
cp "$BUILD"/librexgpu-*.dylib "$APP/Contents/MacOS/"
# The libraries the game links, and the Vulkan loader and driver.
cp "$BUILD"/librexruntime*.dylib "$BUILD"/libTracyClient*.dylib "$APP/Contents/Frameworks/"
cp "$BUILD/vulkan/lib/libvulkan.1.dylib" "$BUILD/vulkan/lib/libMoltenVK.dylib" \
   "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/deadlyprem_usa"
for plugin in "$APP"/Contents/MacOS/librexgpu-*.dylib; do
  install_name_tool -add_rpath "@loader_path/../Frameworks" "$plugin"
done
# MoltenVK's manifest, pointing at the driver in Frameworks (the runtime looks
# for it in Contents/Resources/vulkan/icd.d).
sed 's#"library_path": *"[^"]*"#"library_path": "../../../Frameworks/libMoltenVK.dylib"#' \
    "$BUILD/vulkan/share/vulkan/icd.d/MoltenVK_icd.json" \
    > "$APP/Contents/Resources/vulkan/icd.d/MoltenVK_icd.json"

# Defaults copied into Application Support on the first launch. The app sets
# the texture folder itself, so the empty texture_path is left out.
sed '/^texture_path *=/d' "$HERE/deadlyprem.toml" > "$APP/Contents/Resources/deadlyprem.toml"
cp "$REPO"/textures/*.png "$REPO/textures/README.txt" "$APP/Contents/Resources/textures/"
if [ -n "${GAMECONTROLLERDB:-}" ]; then
  cp "$GAMECONTROLLERDB" "$APP/Contents/Resources/gamecontrollerdb.txt"
fi

# License texts: this port, the ReXGlue SDK, and the libraries the SDK builds
# in or the app carries (its thirdparty folder, MoltenVK and the Vulkan loader
# included). REXGLUE_SDK=<SDK source folder> if it is not next to this
# repository.
SDK_SOURCE="${REXGLUE_SDK:-$(cd "$REPO/.." && pwd)/rexglue-sdk}"
[ -f "$SDK_SOURCE/LICENSE" ] || { echo "No ReXGlue SDK source at $SDK_SOURCE (set REXGLUE_SDK)" >&2; exit 1; }
LICENSES="$APP/Contents/Resources/licenses"
mkdir -p "$LICENSES"
cp "$REPO/LICENSE" "$LICENSES/DPRecomp.txt"
cp "$SDK_SOURCE/LICENSE" "$LICENSES/ReXGlue.txt"
for dir in "$SDK_SOURCE"/thirdparty/*/; do
  name="$(basename "$dir")"
  find "$dir" -maxdepth 2 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) \
       -not -name '*.cfg' -not -path '*/test/*' -not -path '*/cli/*' | sort | while read -r file; do
    cp "$file" "$LICENSES/$name-$(basename "$file")"
  done
done

# Icon, from the Windows one (256 px at most).
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
sips -s format png "$REPO/usa/src/deadlyprem.ico" --out "$ICON_WORK/icon.png" >/dev/null
mkdir "$ICON_WORK/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_WORK/icon.png" \
       --out "$ICON_WORK/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$ICON_WORK/icon.png" \
       --out "$ICON_WORK/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key>
  <string>deadlyprem_usa</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.3</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.action-games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

# Ad-hoc signature: inner code first, then the bundle. Apple Silicon needs a
# signature to run at all; without a Developer ID the first launch still has
# to be allowed in System Settings > Privacy & Security.
for code in "$APP"/Contents/Frameworks/*.dylib "$APP"/Contents/MacOS/*.dylib; do
  codesign --force --sign - "$code"
done
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

ZIP="$OUT/DPRecomp-$VERSION-USA-macOS-arm64.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Built $APP"
echo "Zipped $ZIP ($(du -h "$ZIP" | cut -f1))"
