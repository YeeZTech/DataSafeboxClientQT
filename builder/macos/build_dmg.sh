#!/usr/bin/env bash
# build_dmg.sh -- macOS one-click build + package script
#
# Usage:
#   ./build_dmg.sh          # Developer ID 签名 + Apple 公证（使用 Keychain 存储的凭据）
#
# 首次使用前，运行一次以下命令将公证凭据存入 Keychain（之后无需再输入）：
#   xcrun notarytool store-credentials "datasafebox-notary" \
#       --apple-id "<your-apple-id>" \
#       --team-id "<your-team-id>" \
#       --password "<app-specific-password>"
#
# Override paths via env vars:
#   QT_VERSION=6.7.3 ./build_dmg.sh
#   SENTRY_ROOT_DIR=/path/to/vcpkg/installed/arm64-osx ./build_dmg.sh

set -euo pipefail

# -- Color output (printf-based for macOS bash compatibility) -----------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}   %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error()   { printf "${RED}[ERR]${NC}  %s\n" "$*" >&2; exit 1; }

# -- Paths & version constants ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # builder/macos/
PROJECT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"        # 仓库根目录
PARENT_DIR="$(dirname "${PROJECT_DIR}")"
APP_NAME="safebox"
PRO_NAME="datasafebox-qt-client"
QT_VERSION="${QT_VERSION:-6.7.3}"
BUILD_DIR="${PROJECT_DIR}/build/macos"
DIST_DIR="${SCRIPT_DIR}"

# -- Apple 签名 & 公证凭据（从 Keychain 自动读取）------------------------------
# 公证 Keychain profile 名称（首次运行前用 notarytool store-credentials 存储）
NOTARY_PROFILE="datasafebox-notary"
# 从 Keychain 自动匹配 Developer ID Application 证书
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' \
    | head -1 | grep -oE '"[^"]+"' | head -1 | tr -d '"')"

VERSION="$(grep -oE '<Version>[^<]+' \
    "${PROJECT_DIR}/installer/packages/com.datasafebox.client/meta/package.xml" \
    | head -1 | sed 's|<Version>||')"
[[ -z "${VERSION}" ]] && VERSION="1.0.0"

# -- Auto-detect CPU arch -----------------------------------------------------
ARCH="$(uname -m)"
if [[ "${ARCH}" == "arm64" ]]; then
    VCPKG_TRIPLET="arm64-osx"
else
    VCPKG_TRIPLET="x64-osx"
fi

QT_DIR="${HOME}/Qt/${QT_VERSION}/macos"
VCPKG_DIR="${PARENT_DIR}/vcpkg"
SENTRY_ROOT="${SENTRY_ROOT_DIR:-${VCPKG_DIR}/installed/${VCPKG_TRIPLET}}"

echo ""
echo "=================================================="
echo "  DatasafeBox ${VERSION} -- macOS Build + Package"
echo "  Arch      : ${ARCH}"
echo "  vcpkg     : ${VCPKG_TRIPLET}"
echo "  Qt        : ${QT_VERSION}"
echo "=================================================="
echo ""

# ============================================================================
# Part 1: Environment setup (idempotent)
# ============================================================================

# -- 1. Xcode CLI Tools -------------------------------------------------------
info "Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    success "Installed: $(xcode-select -p)"
else
    warn "Installing Xcode CLI tools (interactive prompt will appear)..."
    xcode-select --install
    echo "Press Enter after installation completes..."; read -r
fi

# -- 2. Homebrew + librsvg ----------------------------------------------------
info "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ "${ARCH}" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    success "Homebrew already installed"
fi

if ! command -v rsvg-convert &>/dev/null; then
    info "Installing librsvg..."
    brew install librsvg
else
    success "librsvg already installed"
fi

if ! command -v pkg-config &>/dev/null; then
    info "Installing pkg-config (required by vcpkg/openssl)..."
    brew install pkg-config
else
    success "pkg-config already installed"
fi

# Pillow is required by icons/generate_platform_icons.sh to add padding to icon PNGs
if ! python3 -c "from PIL import Image" &>/dev/null 2>&1; then
    info "Installing Python Pillow (required for icon generation)..."
    python3 -m pip install --quiet Pillow
    success "Pillow installed"
else
    success "Pillow already installed"
fi

# -- 3. Qt --------------------------------------------------------------------
info "Checking Qt ${QT_VERSION}..."
if [[ ! -x "${QT_DIR}/bin/qmake" ]]; then
    info "Installing Qt ${QT_VERSION} (~2-3 GB)..."
    command -v python3 &>/dev/null || error "python3 not found. Run: brew install python3"

    python3 -m pip install --quiet --upgrade aqtinstall

    # Add pip user bin to PATH so aqt is immediately available in this session
    PIP_USER_BIN="$(python3 -m site --user-base)/bin"
    export PATH="${PIP_USER_BIN}:${PATH}"

    if ! command -v aqt &>/dev/null; then
        error "aqt not found in PATH after install. Try: export PATH=\"${PIP_USER_BIN}:\$PATH\""
    fi

    aqt install-qt mac desktop "${QT_VERSION}" clang_64 \
        --outputdir "${HOME}/Qt" \
        -m qtwebengine qtquick3d qtwebchannel qtpositioning qtlocation
    success "Qt ${QT_VERSION} installed"
else
    success "Qt ${QT_VERSION} already installed"
fi

# Ensure qmake is in PATH for this session
export PATH="${QT_DIR}/bin:${PATH}"

# Persist to shell config (idempotent)
SHELL_RC="${HOME}/.zshrc"
[[ "${SHELL}" == *"bash"* ]] && SHELL_RC="${HOME}/.bash_profile"
if ! grep -qF "${QT_DIR}/bin" "${SHELL_RC}" 2>/dev/null; then
    echo "export PATH=\"${QT_DIR}/bin:\$PATH\"" >> "${SHELL_RC}"
fi

qmake -v 2>/dev/null | grep -qF "${QT_VERSION}" || error "qmake version check failed: expected ${QT_VERSION}"
success "qmake: $(qmake -v | head -1)"

# -- 4. vcpkg -----------------------------------------------------------------
info "Checking vcpkg..."
command -v git &>/dev/null || error "git not found. Install Xcode Command Line Tools: xcode-select --install"
if [[ ! -x "${VCPKG_DIR}/vcpkg" ]]; then
    info "Cloning vcpkg to ${VCPKG_DIR}..."
    git clone https://github.com/microsoft/vcpkg.git "${VCPKG_DIR}"
    "${VCPKG_DIR}/bootstrap-vcpkg.sh" -disableMetrics
    # Pin scripts to date matching the downloaded binary (avoids script/binary mismatch)
    # Binary version format: YYYY-MM-DD-<hash>, extract the date part
    VCPKG_BIN_DATE=$("${VCPKG_DIR}/vcpkg" version 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    if [[ -n "${VCPKG_BIN_DATE}" ]]; then
        VCPKG_PIN_COMMIT=$(git -C "${VCPKG_DIR}" log --before="${VCPKG_BIN_DATE} 23:59:59" -1 --format="%H")
        if [[ -n "${VCPKG_PIN_COMMIT}" ]]; then
            git -C "${VCPKG_DIR}" checkout "${VCPKG_PIN_COMMIT}" --quiet
        fi
    fi
    success "vcpkg initialized"
else
    success "vcpkg already exists"
fi

# -- 5. sentry-native ---------------------------------------------------------
info "Checking sentry-native (${VCPKG_TRIPLET})..."
if [[ ! -f "${SENTRY_ROOT}/lib/libsentry.a" ]]; then
    info "Building sentry-native (~15-20 min first time)..."
    "${VCPKG_DIR}/vcpkg" install \
        --triplet "${VCPKG_TRIPLET}" \
        --x-manifest-root "${PROJECT_DIR}" \
        --x-install-root "${VCPKG_DIR}/installed"
    success "sentry-native installed"
else
    success "sentry-native already installed"
fi

# -- 6. App icon --------------------------------------------------------------
info "Checking macOS icon..."
if [[ ! -f "${PROJECT_DIR}/icons/SafeLogo.icns" ]]; then
    chmod +x "${PROJECT_DIR}/icons/generate_platform_icons.sh"
    bash "${PROJECT_DIR}/icons/generate_platform_icons.sh"
else
    success "SafeLogo.icns already exists"
fi

# ============================================================================
# Part 2: Compile + Package
# ============================================================================

info "Compiling DatasafeBox ${VERSION}..."
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

# On macOS 26 beta CLT, MacOSX.sdk symlinks to 26.x which Qt 6.7.3 doesn't support.
# Prefer MacOSX14 SDK, then fall back to MacOSX15, then xcrun default.
CLT_SDKS="/Library/Developer/CommandLineTools/SDKs"
XCODE_SDKS="$(xcode-select -p 2>/dev/null)/Platforms/MacOSX.platform/Developer/SDKs"
SDKROOT=""
# Try MacOSX14.x from CLT first (most compatible with Qt 6.7.3)
SDKROOT="$(find "${CLT_SDKS}" -maxdepth 1 -name "MacOSX14*.sdk" -type d 2>/dev/null \
    | sort -V | tail -1)"
# Try MacOSX14.x from Xcode.app (for machines without standalone CLT SDKs)
if [[ -z "${SDKROOT}" ]]; then
    SDKROOT="$(find "${XCODE_SDKS}" -maxdepth 1 -name "MacOSX14*.sdk" -type d 2>/dev/null \
        | sort -V | tail -1)"
fi
# Fall back to MacOSX15.x from CLT
if [[ -z "${SDKROOT}" ]]; then
    SDKROOT="$(find "${CLT_SDKS}" -maxdepth 1 -name "MacOSX15*.sdk" -type d 2>/dev/null \
        | sort -V | tail -1)"
fi
# Fall back to MacOSX15.x from Xcode.app
if [[ -z "${SDKROOT}" ]]; then
    SDKROOT="$(find "${XCODE_SDKS}" -maxdepth 1 -name "MacOSX15*.sdk" -type d 2>/dev/null \
        | sort -V | tail -1)"
fi
# Last resort: system default (may be macOS 26+ which Qt 6.7.3 doesn't support)
if [[ -z "${SDKROOT}" ]]; then
    SDKROOT="$(xcrun --show-sdk-path)"
    warn "No MacOSX14/15 SDK found — using system SDK: ${SDKROOT}"
    warn "Qt 6.7.3 may not support this SDK; build might fail."
fi
export SDKROOT
info "Using SDK: ${SDKROOT}"

# Derive QMAKE_MAC_SDK from SDKROOT path (e.g. MacOSX14.4.sdk → macosx14.4)
# qmake's macx-clang mkspec uses xcrun internally and ignores $SDKROOT env,
# so we must pass QMAKE_MAC_SDK explicitly to force the correct sysroot.
QMAKE_MAC_SDK_VAL="$(basename "${SDKROOT}" .sdk | tr 'A-Z' 'a-z')"
info "Using QMAKE_MAC_SDK: ${QMAKE_MAC_SDK_VAL}"

# Clean stale build artifacts (moc files from different Qt versions will cause build failures)
info "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

qmake "${PROJECT_DIR}/${PRO_NAME}.pro" \
    CONFIG+=release \
    CONFIG+=sdk_no_version_check \
    QMAKE_MACOSX_DEPLOYMENT_TARGET=12.0 \
    QMAKE_MAC_SDK="${QMAKE_MAC_SDK_VAL}" \
    "QMAKE_CXXFLAGS+=-isystem ${SDKROOT}/usr/include/c++/v1" \
    "QMAKE_LIBS_OPENGL=-framework OpenGL" \
    SENTRY_ROOT_DIR="${SENTRY_ROOT}"

# Patch generated Makefile: remove -framework AGL which was removed in macOS 14+
# AGL leaks in via Qt's prl files and cannot be overridden via qmake command line.
info "Patching Makefile: removing deprecated -framework AGL..."
sed -i '' 's/-framework AGL//g' "${BUILD_DIR}/Makefile"
make -j"$(sysctl -n hw.ncpu)"

APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
[[ -d "${APP_BUNDLE}" ]] || error "Build failed: ${APP_BUNDLE} not found"
success "Compile done"

# Copy crashpad_handler into app bundle
CRASHPAD="${SENTRY_ROOT}/tools/sentry-native/crashpad_handler"
if [[ -f "${CRASHPAD}" ]]; then
    cp "${CRASHPAD}" "${APP_BUNDLE}/Contents/MacOS/"
    chmod +x "${APP_BUNDLE}/Contents/MacOS/crashpad_handler"
    success "crashpad_handler copied"
else
    warn "crashpad_handler not found (${CRASHPAD}) -- Sentry crash reporting disabled"
fi

# macdeployqt: bundle Qt frameworks into app (no -dmg; we build the DMG manually below)
DMG_NAME="safebox_${VERSION}.dmg"

# macOS 26+ removed otool-classic; macdeployqt 6.7.x requires it.
# Create a local shim so macdeployqt can find it without sudo.
if ! command -v otool-classic &>/dev/null; then
    info "otool-classic not found; creating local shim for macdeployqt..."
    SHIM_DIR="${BUILD_DIR}/.shims"
    mkdir -p "${SHIM_DIR}"
    ln -sf "$(command -v otool)" "${SHIM_DIR}/otool-classic"
    export PATH="${SHIM_DIR}:${PATH}"
fi

info "Running macdeployqt..."
macdeployqt "${APP_BUNDLE}" -qmldir="${PROJECT_DIR}/qml"

# Strip debug symbols from all dylibs and frameworks to reduce bundle size
info "Stripping debug symbols..."
find "${APP_BUNDLE}" -type f \( -name "*.dylib" -o -name "*.so" \) -exec strip -x {} \; 2>/dev/null
find "${APP_BUNDLE}/Contents/Frameworks" -type f -perm +111 ! -name "*.pak" ! -name "*.dat" ! -name "*.bin" \
    -exec sh -c 'file "$1" | grep -q "Mach-O" && strip -x "$1"' _ {} \; 2>/dev/null

# Remove unused WebEngine locales (keep only zh-CN and en-US)
LOCALES_DIR="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Resources/qtwebengine_locales"
if [[ -d "${LOCALES_DIR}" ]]; then
    info "Removing unused WebEngine locales..."
    find "${LOCALES_DIR}" -name "*.pak" \
        ! -name "zh-CN.pak" \
        ! -name "en-US.pak" \
        -delete
fi

# Remove WebEngine devtools (not needed in production)
DEVTOOLS="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Resources/qtwebengine_devtools_resources.pak"
[[ -f "${DEVTOOLS}" ]] && rm -f "${DEVTOOLS}" && info "Removed qtwebengine_devtools_resources.pak"

# Remove unused QML Controls styles — project uses QQuickStyle::setStyle("Basic") exclusively
# Safe to remove: iOS, macOS, Fusion, Universal, Imagine, Material, and dev-only dirs
info "Removing unused QML Controls styles..."
QML_CONTROLS="${APP_BUNDLE}/Contents/Resources/qml/QtQuick/Controls"
for STYLE in iOS macOS Fusion Universal Imagine Material designer; do
    if [[ -d "${QML_CONTROLS}/${STYLE}" ]]; then
        rm -rf "${QML_CONTROLS}/${STYLE}"
        info "  Removed Controls/${STYLE}"
    fi
done

# Remove Qt Creator tooling metadata (not needed at runtime)
TOOLING="${APP_BUNDLE}/Contents/Resources/qml/QtQuick/tooling"
[[ -d "${TOOLING}" ]] && rm -rf "${TOOLING}" && info "Removed QtQuick/tooling"

# Copy open-source license and third-party notices before signing.
LICENSE_DST="${APP_BUNDLE}/Contents/Resources/licenses"
info "Copying open-source license files..."
rm -rf "${LICENSE_DST}"
mkdir -p "${LICENSE_DST}"
cp "${PROJECT_DIR}/LICENSE" "${LICENSE_DST}/LICENSE"
cp "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md" "${LICENSE_DST}/THIRD_PARTY_NOTICES.md"
cp -R "${PROJECT_DIR}/LICENSES" "${LICENSE_DST}/LICENSES"
success "License files copied"

# Re-apply code signature after all post-processing modifications.
# macdeployqt signs the bundle; subsequent file removal (locales, QML styles)
# invalidates that signature. macOS then blocks QtWebEngineProcess from launching,
# causing WebEngine to fail loading any page.
ENTITLEMENTS_PLIST="${SCRIPT_DIR}/entitlements.plist"
ENTITLEMENTS_WE_PLIST="${SCRIPT_DIR}/entitlements_webengine.plist"
WEBENGINE_PROCESS="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Helpers/QtWebEngineProcess.app"

if [[ -n "${SIGN_IDENTITY}" ]]; then
    info "使用 Developer ID 签名: ${SIGN_IDENTITY}"
    # 1. 整体签名（--deep 会签所有嵌套组件）
    codesign --force --deep --options runtime \
        --entitlements "${ENTITLEMENTS_PLIST}" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing signature" || true
    # 2. 单独给 QtWebEngineProcess 追加 JIT entitlements（--deep 会用通用 entitlements 覆盖它，
    #    必须在整体签名之后单独重签，否则 JavaScript JIT 被 Hardened Runtime 阻止导致登录页空白）
    if [[ -d "${WEBENGINE_PROCESS}" ]]; then
        codesign --force --options runtime \
            --entitlements "${ENTITLEMENTS_WE_PLIST}" \
            --sign "${SIGN_IDENTITY}" \
            "${WEBENGINE_PROCESS}" 2>&1 | grep -v "replacing existing signature" || true
    fi
    success "Developer ID 签名完成"
else
    warn "未找到 Developer ID 证书，使用 ad-hoc 签名（发布版本请先安装证书）"
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing signature" || true
fi

# Build a proper installer DMG with Applications alias so users can drag-to-install
info "Creating DMG with Applications shortcut..."
DMG_STAGING="${BUILD_DIR}/dmg_staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
# Use ditto (not cp -r) to preserve symlinks inside Qt .framework bundles.
# cp -r dereferences framework symlinks, causing each binary to be stored twice
# and inflating the installed app size ~3x.
ditto "${APP_BUNDLE}" "${DMG_STAGING}/$(basename "${APP_BUNDLE}")"
ln -s /Applications "${DMG_STAGING}/Applications"

# Create compressed read-write image, then convert to read-only UDZO
DMG_TMP="${BUILD_DIR}/tmp_rw.dmg"
rm -f "${DMG_TMP}" "${DIST_DIR}/${DMG_NAME}"
hdiutil create \
    -volname "Safebox ${VERSION}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDRW \
    "${DMG_TMP}" >/dev/null

hdiutil convert "${DMG_TMP}" \
    -format UDZO \
    -o "${DIST_DIR}/${DMG_NAME}" >/dev/null

rm -f "${DMG_TMP}"

# -- DMG 签名 & Apple 公证 ---------------------------------------------------
if [[ -n "${SIGN_IDENTITY}" ]]; then
    info "对 DMG 签名..."
    codesign --force --sign "${SIGN_IDENTITY}" "${DIST_DIR}/${DMG_NAME}" 2>&1 | grep -v "replacing existing signature" || true
    success "DMG 签名完成"
    if xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" &>/dev/null; then
        info "提交 Apple 公证（需要几分钟，请等待）..."
        xcrun notarytool submit "${DIST_DIR}/${DMG_NAME}" \
            --keychain-profile "${NOTARY_PROFILE}" \
            --wait
        xcrun stapler staple "${DIST_DIR}/${DMG_NAME}"
        success "公证完成，DMG 已加盖 staple"
    else
        warn "未找到公证凭据，跳过公证。请先运行:"
        warn "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" --apple-id <id> --team-id <team> --password <pwd>"
    fi
else
    warn "未找到 Developer ID 证书，DMG 使用 ad-hoc 签名（发布版本请先安装证书）"
fi

echo ""
echo "=================================================="
printf "${GREEN}  Build complete!${NC}\n"
echo "  Output: ${DIST_DIR}/${DMG_NAME}"
echo "=================================================="
