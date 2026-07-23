#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
archive_path="${PWD}/build/KeyPilot.xcarchive"
mkdir -p "${PWD}/build"
xcodegen generate
xcodebuild -project KeyPilot.xcodeproj \
  -scheme KeyPilot \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${archive_path}" archive
ditto -c -k --sequesterRsrc --keepParent \
  "${archive_path}/Products/Applications/KeyPilot.app" \
  "${PWD}/build/KeyPilot.zip"
