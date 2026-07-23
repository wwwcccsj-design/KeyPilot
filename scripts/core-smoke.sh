#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
mkdir -p .build/CoreSmokeModuleCache
xcrun swiftc \
  -parse-as-library \
  -module-cache-path .build/CoreSmokeModuleCache \
  -target x86_64-apple-macosx12.0 \
  -o .build/keypilot-core-smoke \
  KeyPilot/Core/*.swift \
  KeyPilot/Models/*.swift \
  KeyPilot/Services/ApplicationLauncher.swift \
  KeyPilot/Services/ApplicationResolver.swift \
  KeyPilot/Services/ConfigurationStore.swift \
  KeyPilot/Services/DiagnosticsService.swift \
  KeyPilot/Services/KeyboardLayoutService.swift \
  KeyPilot/Utilities/AtomicBox.swift \
  KeyPilot/Utilities/FileLocations.swift \
  KeyPilot/Utilities/KeyCodeNames.swift \
  scripts/CoreSmoke.swift
.build/keypilot-core-smoke
