#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h}/.."
app_bundle="${1:-}"

if [[ -z "${app_bundle}" || ! -d "${app_bundle}" ]]; then
    print "用法：${0:t} /path/to/KeyPilot.app"
    exit 2
fi

helper_bundle="${app_bundle}/Contents/Library/LoginItems/KeyPilotLoginHelper.app"
signing_identity="${KEYPILOT_SIGNING_IDENTITY:-}"
if [[ -z "${signing_identity}" ]]; then
    signing_identity="$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk '/"(Developer ID Application|Apple Development|Mac Developer):/ { print $2; exit }')"
fi

if [[ -n "${signing_identity}" ]]; then
    print "正在使用稳定的 Apple 代码签名身份。"
else
    signing_identity="-"
    print "警告：未找到稳定签名身份，暂时使用临时签名；重新构建后可能需要再次授权。"
fi

if [[ -d "${helper_bundle}" ]]; then
    /usr/bin/codesign \
        --force \
        --sign "${signing_identity}" \
        --timestamp=none \
        "${helper_bundle}"
fi

/usr/bin/codesign \
    --force \
    --sign "${signing_identity}" \
    --timestamp=none \
    --entitlements "${project_dir}/KeyPilot/KeyPilot.entitlements" \
    "${app_bundle}"

/usr/bin/codesign --verify --deep --strict "${app_bundle}"
