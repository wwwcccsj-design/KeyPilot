#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
xcodegen generate
xcodebuild -project KeyPilot.xcodeproj \
  -scheme KeyPilot \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project KeyPilot.xcodeproj \
  -scheme KeyPilot \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
