#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
app=${1:?usage: test-macos-package.sh <built-app-directory>}
publish_directory="$app/Contents/MacOS"
work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT
packager="$script_directory/package-macos-app.sh"

expect_failure()
{
    if "$@" >"$work_directory/failure.log" 2>&1; then
        echo "error: invalid packaging request succeeded" >&2
        exit 1
    fi
}

# Exercise the original four-argument interface and paths containing spaces.
archive="$work_directory/output with spaces/app.zip"
bash "$packager" "$publish_directory" "$archive" 12 0.12
mkdir "$work_directory/extracted"
ditto -x -k "$archive" "$work_directory/extracted"
bash "$script_directory/verify-macos-app.sh" "$work_directory/extracted/Git Extensions Avalonia.app"

before=$(shasum -a 256 "$archive")
expect_failure bash "$packager" "$publish_directory" "$archive" '1<script>' 1.0.0
expect_failure bash "$packager" "$publish_directory" "$archive" 1 '1&2'
expect_failure bash "$packager" "$publish_directory" "$archive" 1 1.2.3.4
expect_failure bash "$packager" "$work_directory/missing" "$archive" 1 1.0.0
mkdir "$work_directory/incomplete"
cp "$publish_directory/GitExtensions.Avalonia" "$work_directory/incomplete/"
expect_failure bash "$packager" "$work_directory/incomplete" "$archive" 1 1.0.0
mkdir "$work_directory/tools"
ln -s /usr/bin/dirname "$work_directory/tools/dirname"
expect_failure /usr/bin/env PATH="$work_directory/tools" /bin/bash "$packager" "$publish_directory" "$archive" 1 1.0.0
grep -q "required command 'ditto'" "$work_directory/failure.log"
[[ "$(shasum -a 256 "$archive")" == "$before" ]] || { echo 'error: failed packaging replaced existing archive' >&2; exit 1; }

output_app="$work_directory/retained app/Git Extensions Avalonia.app"
bash "$packager" "$publish_directory" "$archive" 2 1.2.3 "$output_app"
bash "$script_directory/verify-macos-app.sh" "$output_app"
bash "$packager" "$publish_directory" "$archive" 3 1.2.4 "$output_app"
[[ "$(plutil -extract CFBundleVersion raw -o - "$output_app/Contents/Info.plist")" == 3 ]]
mkdir "$work_directory/unrelated.app"
expect_failure bash "$packager" "$publish_directory" "$archive" 4 1.2.5 "$work_directory/unrelated.app"
printf 'Packaging checks passed\n'
