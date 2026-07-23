#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
xcodegen generate
xcodebuild -project KeyPilot.xcodeproj \
  -scheme KeyPilot \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
