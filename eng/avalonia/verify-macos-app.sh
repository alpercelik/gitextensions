#!/usr/bin/env bash
set -euo pipefail

app=${1:?usage: verify-macos-app.sh <app-directory>}
contents="$app/Contents"
plist="$contents/Info.plist"
plutil -lint "$plist"
for pair in 'CFBundleExecutable:GitExtensions.Avalonia' 'CFBundleIdentifier:com.github.gitextensions.GitExtensions.Avalonia' 'CFBundleIconFile:GitExtensions.icns' 'LSMinimumSystemVersion:15.0'; do
    if [[ "$(plutil -extract "${pair%%:*}" raw -o - "$plist")" != "${pair#*:}" ]]; then
        echo "error: unexpected ${pair%%:*}" >&2; exit 1
    fi
done
for executable in GitExtensions.Avalonia GitExtensions.ProcessGroupLauncher; do
    [[ -x "$contents/MacOS/$executable" ]] || { echo "error: missing executable $executable" >&2; exit 1; }
    lipo "$contents/MacOS/$executable" -verify_arch arm64
done
for file in GitExtensions.Avalonia.dll GitExtensions.Avalonia.runtimeconfig.json GitExtensions.Avalonia.deps.json libhostfxr.dylib libcoreclr.dylib libAvaloniaNative.dylib; do
    [[ -s "$contents/MacOS/$file" ]] || { echo "error: missing $file" >&2; exit 1; }
done
for plugin in AppVeyorIntegration AutoCompileSubmodules AzureDevOpsIntegration BackgroundFetch CreateLocalBranches DeleteUnusedBranches FindLargeFiles GitHub3 GitHubActionsIntegration GitImpact GitlabIntegration GitStatistics Gource JenkinsIntegration ProxySwitcher ReleaseNotesGenerator TeamCityIntegration; do
    [[ -s "$contents/MacOS/Plugins/$plugin/GitExtensions.Plugins.$plugin.dll" ]] || { echo "error: missing plugin $plugin" >&2; exit 1; }
done
work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT
iconutil -c iconset "$contents/Resources/GitExtensions.icns" -o "$work_directory/check.iconset"
for size in 16 32 128 256 512; do
    for suffix in '' '@2x'; do
        icon="$work_directory/check.iconset/icon_${size}x${size}${suffix}.png"
        expected=$size
        if [[ -n "$suffix" ]]; then expected=$((size * 2)); fi
        actual=$(sips -g pixelWidth -g pixelHeight "$icon")
        [[ "$actual" == *"pixelWidth: $expected"* && "$actual" == *"pixelHeight: $expected"* ]] || { echo "error: incorrect icon dimensions: $icon" >&2; exit 1; }
    done
done
printf 'Verified %s\n' "$app"
