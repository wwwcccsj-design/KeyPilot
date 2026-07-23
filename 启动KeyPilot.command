#!/bin/zsh

set -u

project_dir="${0:A:h}"
xcode_derived_data="${project_dir}/.build/XcodeDerivedData"
app_path=""
install_directory="${HOME}/Applications"
installed_app_path="${install_directory}/KeyPilot.app"

function stop_with_message() {
    print ""
    print "启动失败：$1"
    print ""
    print -n "按任意键关闭窗口…"
    read -k 1
    print ""
    exit 1
}

cd "${project_dir}" || stop_with_message "无法进入项目目录。"

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
if (( macos_major < 12 )); then
    stop_with_message "KeyPilot 要求 macOS 12 或更高版本；当前系统是 macOS ${macos_version}。"
fi

developer_dir=""
if /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    developer_dir="$(xcode-select -p)"
elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    developer_dir="/Applications/Xcode.app/Contents/Developer"
fi

if [[ -n "${developer_dir}" ]]; then
    export DEVELOPER_DIR="${developer_dir}"
    if command -v xcodegen >/dev/null 2>&1; then
        print "正在更新 Xcode 工程…"
        xcodegen generate || stop_with_message "XcodeGen 生成工程失败。"
    fi
    print "正在使用完整 Xcode 构建 Universal 2 应用…"
    /usr/bin/xcodebuild \
        -project "${project_dir}/KeyPilot.xcodeproj" \
        -scheme KeyPilot \
        -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "${xcode_derived_data}" \
        ARCHS='x86_64 arm64' \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGNING_ALLOWED=NO \
        build || stop_with_message "Xcode 构建失败，请查看上方错误。"
    app_path="${xcode_derived_data}/Build/Products/Debug/KeyPilot.app"
else
    print "未检测到完整 Xcode，正在使用 Command Line Tools 构建…"
    "${project_dir}/scripts/build-local.sh" || stop_with_message "本地 Universal 2 构建失败。"
    app_path="${project_dir}/.build/LocalBuild/KeyPilot.app"
fi

if [[ ! -d "${app_path}" ]]; then
    stop_with_message "构建完成，但没有找到 KeyPilot.app。"
fi

"${project_dir}/scripts/sign-app.sh" "${app_path}" \
    || stop_with_message "应用签名失败。"

source_executable="${app_path}/Contents/MacOS/KeyPilot"
installed_executable="${installed_app_path}/Contents/MacOS/KeyPilot"
if [[ ! -f "${installed_executable}" ]] || ! cmp -s "${source_executable}" "${installed_executable}"; then
    if [[ -d "${installed_app_path}" ]]; then
        installed_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${installed_app_path}/Contents/Info.plist" 2>/dev/null)"
        if [[ "${installed_identifier}" != "com.keypilot.mac" ]]; then
            stop_with_message "${installed_app_path} 已被其他应用占用，未执行覆盖。"
        fi
    fi
    print "正在安装到 ${installed_app_path}…"
    mkdir -p "${install_directory}"
    pkill -x KeyPilot >/dev/null 2>&1 || true
    sleep 1
    staging_app="${install_directory}/.KeyPilot-installing.app"
    previous_app="${install_directory}/.KeyPilot-previous.app"
    rm -rf "${staging_app}" "${previous_app}"
    ditto "${app_path}" "${staging_app}" || stop_with_message "复制应用失败。"
    if [[ -d "${installed_app_path}" ]]; then
        mv "${installed_app_path}" "${previous_app}" || stop_with_message "无法替换旧版本。"
    fi
    if ! mv "${staging_app}" "${installed_app_path}"; then
        [[ -d "${previous_app}" ]] && mv "${previous_app}" "${installed_app_path}"
        stop_with_message "安装新版本失败，已恢复旧版本。"
    fi
    rm -rf "${previous_app}"
fi

app_path="${installed_app_path}"
print "正在启动 KeyPilot…"
/usr/bin/open "${app_path}" || stop_with_message "无法打开 KeyPilot.app。"

print ""
print "KeyPilot 已启动，请在屏幕顶部菜单栏寻找键盘图标。"
print "首次使用请在系统设置中授予辅助功能权限。"
sleep 3
