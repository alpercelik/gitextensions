#!/usr/bin/env bash
set -euo pipefail

publish_directory=${1:-}
output_archive=${2:-}
bundle_version=${3:-}
display_version=${4:-}
output_app=${5:-}
script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
logo_directory="$script_directory/../../setup/assets/Logo"

if [[ -z "$publish_directory" || -z "$output_archive" || -z "$bundle_version" || -z "$display_version" ]]; then
    echo "usage: package-macos-app.sh <publish-directory> <output-archive> <bundle-version> <display-version> [output-app-directory]" >&2
    exit 2
fi

for tool in ditto mktemp plutil iconutil lipo sips; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required command '$tool' is not installed" >&2
        exit 1
    fi
done

if [[ ! -x "$publish_directory/GitExtensions.Avalonia" ]]; then
    echo "error: publish directory does not contain the GitExtensions.Avalonia executable" >&2
    exit 1
fi

for version in "$bundle_version" "$display_version"; do
    if [[ ! "$version" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
        echo "error: versions must contain one to three decimal components" >&2
        exit 2
    fi
done

for file in GitExtensions.Avalonia.dll GitExtensions.Avalonia.deps.json GitExtensions.Avalonia.runtimeconfig.json libhostfxr.dylib libcoreclr.dylib GitExtensions.ProcessGroupLauncher; do
    if [[ ! -f "$publish_directory/$file" ]]; then
        echo "error: incomplete self-contained publish output: missing $file" >&2
        exit 1
    fi
done
lipo "$publish_directory/GitExtensions.Avalonia" -verify_arch arm64
lipo "$publish_directory/GitExtensions.ProcessGroupLauncher" -verify_arch arm64

if [[ "$output_archive" != *.zip || -L "$output_archive" || ( -e "$output_archive" && ! -f "$output_archive" ) ]]; then
    echo "error: output archive must be a regular, non-symlink .zip file path" >&2
    exit 2
fi
if [[ -n "$output_app" ]]; then
    if [[ "$output_app" != *.app || -L "$output_app" ]]; then
        echo "error: output app must be a non-symlink .app path" >&2
        exit 2
    fi
    if [[ -e "$output_app" ]] && [[ ! -f "$output_app/Contents/Info.plist" || "$(plutil -extract CFBundleIdentifier raw -o - "$output_app/Contents/Info.plist")" != com.github.gitextensions.GitExtensions.Avalonia ]]; then
        echo "error: refusing to replace an unrelated output directory" >&2
        exit 2
    fi
fi

# Stage beside the archive so publishing the completed ZIP is a rename.
mkdir -p "$(dirname "$output_archive")"
work_directory=$(mktemp -d "$(dirname "$output_archive")/.macos-package.XXXXXX")
app_staging=
cleanup()
{
    rm -rf -- "$work_directory"
    if [[ -n "$app_staging" ]]; then
        if [[ -d "$app_staging/previous.app" && ! -e "$output_app" ]]; then
            mv "$app_staging/previous.app" "$output_app"
        fi
        rm -rf -- "$app_staging"
    fi
}
trap cleanup EXIT

app_directory="$work_directory/Git Extensions Avalonia.app"
contents_directory="$app_directory/Contents"
macos_directory="$contents_directory/MacOS"
mkdir -p "$macos_directory" "$contents_directory/Resources"
cp -a "$publish_directory/." "$macos_directory/"
chmod +x "$macos_directory/GitExtensions.Avalonia" "$macos_directory/GitExtensions.ProcessGroupLauncher"

iconset="$work_directory/GitExtensions.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    cp "$logo_directory/git-extensions-logo-${size}px.png" "$iconset/icon_${size}x${size}.png"
    retina_size=$((size * 2))
    cp "$logo_directory/git-extensions-logo-${retina_size}px.png" "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o "$contents_directory/Resources/GitExtensions.icns"

cat > "$contents_directory/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Git Extensions</string>
  <key>CFBundleExecutable</key>
  <string>GitExtensions.Avalonia</string>
  <key>CFBundleIdentifier</key>
  <string>com.github.gitextensions.GitExtensions.Avalonia</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Git Extensions</string>
  <key>CFBundleIconFile</key>
  <string>GitExtensions.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$display_version</string>
  <key>CFBundleVersion</key>
  <string>$bundle_version</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

bash "$script_directory/verify-macos-app.sh" "$app_directory"
ditto -c -k --sequesterRsrc --keepParent "$app_directory" "$work_directory/bundle.zip"

if [[ -n "$output_app" ]]; then
    mkdir -p "$(dirname "$output_app")"
    app_staging=$(mktemp -d "$(dirname "$output_app")/.macos-app.XXXXXX")
    ditto "$app_directory" "$app_staging/app"
    # Keep the previous bundle until the replacement is completely staged.
    if [[ -e "$output_app" ]]; then mv "$output_app" "$app_staging/previous.app"; fi
    if ! mv "$app_staging/app" "$output_app"; then
        if [[ -d "$app_staging/previous.app" ]]; then mv "$app_staging/previous.app" "$output_app"; fi
        exit 1
    fi
fi
mv -f "$work_directory/bundle.zip" "$output_archive"
printf 'Created %s\n' "$output_archive"
