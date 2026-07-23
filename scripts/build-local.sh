#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h}/.."
build_root="${project_dir}/.build/LocalBuild"
module_cache="${build_root}/ModuleCache"
app_bundle="${build_root}/KeyPilot.app"
main_executable="${app_bundle}/Contents/MacOS/KeyPilot"
helper_bundle="${app_bundle}/Contents/Library/LoginItems/KeyPilotLoginHelper.app"
helper_executable="${helper_bundle}/Contents/MacOS/KeyPilotLoginHelper"

cd "${project_dir}"

source_files=(
    KeyPilot/App/*.swift
    KeyPilot/Core/*.swift
    KeyPilot/Models/*.swift
    KeyPilot/Services/*.swift
    KeyPilot/Utilities/*.swift
    KeyPilot/Views/Components/*.swift
    KeyPilot/Views/MenuBar/*.swift
    KeyPilot/Views/Onboarding/*.swift
    KeyPilot/Views/Settings/*.swift
)
build_inputs=(
    "${source_files[@]}"
    KeyPilotLoginHelper/LoginHelperMain.swift
    KeyPilot/KeyPilot.entitlements
    scripts/ManualKeyPilotInfo.plist
    scripts/ManualLoginHelperInfo.plist
)

needs_build=false
if [[ ! -x "${main_executable}" ]]; then
    needs_build=true
else
    for input_file in "${build_inputs[@]}"; do
        if [[ "${input_file}" -nt "${main_executable}" ]]; then
            needs_build=true
            break
        fi
    done
fi

if [[ "${needs_build}" == false ]]; then
    print "KeyPilot 已是最新版本：${app_bundle}"
    exit 0
fi

rm -rf "${app_bundle}"
mkdir -p \
    "${app_bundle}/Contents/MacOS" \
    "${app_bundle}/Contents/Resources" \
    "${helper_bundle}/Contents/MacOS"
cp scripts/ManualKeyPilotInfo.plist "${app_bundle}/Contents/Info.plist"
cp scripts/ManualLoginHelperInfo.plist "${helper_bundle}/Contents/Info.plist"

function compile_architecture() {
    local architecture="$1"
    local target="${architecture}-apple-macosx12.0"
    local architecture_cache="${module_cache}/${architecture}"
    mkdir -p "${architecture_cache}"
    print "正在编译 KeyPilot（${architecture}）…"
    xcrun swiftc \
        -parse-as-library \
        -whole-module-optimization \
        -module-cache-path "${architecture_cache}" \
        -target "${target}" \
        -module-name KeyPilot \
        -o "${build_root}/KeyPilot-${architecture}" \
        "${source_files[@]}"

    print "正在编译登录助手（${architecture}）…"
    xcrun swiftc \
        -parse-as-library \
        -whole-module-optimization \
        -module-cache-path "${architecture_cache}" \
        -target "${target}" \
        -module-name KeyPilotLoginHelper \
        -o "${build_root}/KeyPilotLoginHelper-${architecture}" \
        KeyPilotLoginHelper/LoginHelperMain.swift
}

compile_architecture x86_64
compile_architecture arm64

lipo -create \
    "${build_root}/KeyPilot-x86_64" \
    "${build_root}/KeyPilot-arm64" \
    -output "${main_executable}"
lipo -create \
    "${build_root}/KeyPilotLoginHelper-x86_64" \
    "${build_root}/KeyPilotLoginHelper-arm64" \
    -output "${helper_executable}"

"${project_dir}/scripts/sign-app.sh" "${app_bundle}"

print "Universal 2 应用构建完成：${app_bundle}"
