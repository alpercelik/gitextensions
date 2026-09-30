#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_directory/../.." && pwd)
output_directory="$repo_root/artifacts/macos/osx-arm64"
bundle_version=0.0.0
display_version=0.0.0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-directory|--bundle-version|--display-version)
            if [[ $# -lt 2 || -z "$2" ]]; then echo "error: $1 requires a value" >&2; exit 2; fi
            case "$1" in
                --output-directory) output_directory=$2 ;;
                --bundle-version) bundle_version=$2 ;;
                --display-version) display_version=$2 ;;
            esac
            shift 2 ;;
        --help)
            echo "usage: build-macos-app.sh [--output-directory PATH] [--bundle-version NUMBER] [--display-version NUMBER]"
            exit 0 ;;
        *) echo "error: unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
    echo "error: build on an Apple Silicon Mac" >&2
    exit 1
fi
for tool in dotnet pwsh cc ditto plutil iconutil lipo sips; do
    if ! command -v "$tool" >/dev/null 2>&1; then echo "error: required command '$tool' is not installed" >&2; exit 1; fi
done
for version in "$bundle_version" "$display_version"; do
    if [[ ! "$version" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
        echo "error: versions must contain one to three decimal components" >&2
        exit 2
    fi
done
if [[ ! -f "$repo_root/externals/Git.hub/Git.hub/Git.hub.csproj" ]]; then
    echo "error: initialize submodules with git submodule update --init --recursive" >&2
    exit 1
fi
mkdir -p "$output_directory"
output_directory=$(cd "$output_directory" && pwd)
work_directory=$(mktemp -d "$output_directory/.macos-build.XXXXXX")
trap 'rm -rf -- "$work_directory"' EXIT
cd "$repo_root"

dotnet publish src/app/GitExtensions.Avalonia/GitExtensions.Avalonia.csproj \
    -c Release -p:BuildAvalonia=true -p:UseAppHost=true -r osx-arm64 \
    --self-contained true -m:1 --output "$work_directory/publish"
pwsh -NoProfile -File "$script_directory/Stage-MaintainerPublish.ps1" -PublishDirectory "$work_directory/publish"
bash "$script_directory/package-macos-app.sh" "$work_directory/publish" \
    "$output_directory/Git Extensions Avalonia.app.zip" "$bundle_version" "$display_version" \
    "$output_directory/Git Extensions Avalonia.app"
printf 'App: %s/Git Extensions Avalonia.app\n' "$output_directory"
