#!/usr/bin/env bash
# build_dmg.sh -- macOS one-click build + package script
#
# Usage:
#   ./build_dmg.sh
#   QT_VERSION=6.7.3 DSCC_DIR=/path/to/DSCC ./build_dmg.sh
#
# First-time notarization setup (run once, credentials stored in Keychain):
#   xcrun notarytool store-credentials "datasafebox-notary" \
#       --apple-id "<your-apple-id>" \
#       --team-id  "<your-team-id>" \
#       --password "<app-specific-password>"
#
# Overridable via environment variables:
#   QT_VERSION, SENTRY_ROOT_DIR, DSCC_DIR

# Preflight phase accumulates ALL failures before exiting — no -e yet.
set -uo pipefail

# ===========================================================================
# Output helpers
# ===========================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { printf "\n${BLUE}[%s]${NC} %s\n" "$1" "$2"; }
ok()   { printf "${GREEN}[OK]${NC}   %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
die()  { printf "${RED}[ERR]${NC}  %s\n" "$*" >&2; exit 1; }

# ===========================================================================
# Configuration  (all paths overridable via environment variables)
# ===========================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # builder/macos/
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"              # repo root
PARENT_DIR="$(dirname "${PROJECT_DIR}")"

APP_NAME="DataSafebox"
PRO_FILE="${PROJECT_DIR}/datasafebox-qt-client.pro"
QT_VERSION="${QT_VERSION:-6.7.3}"
DEPLOY_TARGET="12.0"
BUILD_DIR="${PROJECT_DIR}/build/macos"
DIST_DIR="${SCRIPT_DIR}"

# Single entitlements file shared by the app bundle and QtWebEngineProcess
ENTITLEMENTS="${SCRIPT_DIR}/entitlements.plist"

NOTARY_PROFILE="datasafebox-notary"
SKIP_NOTARY="${SKIP_NOTARY:-1}"   # set to 0 to enable notarization

ARCH="$(uname -m)"
VCPKG_TRIPLET="$([[ "${ARCH}" == arm64 ]] && echo arm64-osx || echo x64-osx)"
QT_DIR="${HOME}/Qt/${QT_VERSION}/macos"
VCPKG_DIR="${PARENT_DIR}/vcpkg"
SENTRY_ROOT="${SENTRY_ROOT_DIR:-${VCPKG_DIR}/installed/${VCPKG_TRIPLET}}"
DSCC_DIR="${DSCC_DIR:-/usr/local/DSCC}"

# Auto-detect Developer ID certificate from Keychain
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 \
    | grep -oE '"[^"]+"' | head -1 | tr -d '"')"

# Read version from the single canonical source: installer/config/config.xml
VERSION="$(grep -oE '<Version>[^<]+' \
    "${PROJECT_DIR}/installer/config/config.xml" \
    2>/dev/null | head -1 | sed 's|<Version>||')"
VERSION="${VERSION:-1.0.0}"

DMG_NAME="DataSafebox_${VERSION}.dmg"

printf "\n"
printf "==================================================\n"
printf "  DatasafeBox %-8s  macOS Build + Package\n" "${VERSION}"
printf "  Arch    : %s (%s)\n"  "${ARCH}" "${VCPKG_TRIPLET}"
printf "  Qt      : %s\n"       "${QT_DIR}"
printf "  Sentry  : %s\n"       "${SENTRY_ROOT}"
printf "  DSCC    : %s\n"       "${DSCC_DIR:-<not set>}"
printf "  Sign    : %s\n"       "${SIGN_IDENTITY:-<ad-hoc>}"
printf "==================================================\n\n"

# ===========================================================================
# Generic helpers used by the preflight checks
# ===========================================================================

# fail_check <description>
# Record a preflight failure — does NOT exit, so all checks always run.
PREFLIGHT_FAILED=()
fail_check() { PREFLIGHT_FAILED+=("$1"); warn "  FAILED: $1"; }

# brew_tool <command> <brew-package>
# Check if <command> exists; if not, attempt to install via Homebrew.
brew_tool() {
    local cmd="$1" pkg="$2"
    if command -v "${cmd}" &>/dev/null; then
        ok "${cmd}: $(command -v "${cmd}")"
        return
    fi
    if ! command -v brew &>/dev/null; then
        fail_check "${cmd}  ->  brew install ${pkg}  (install Homebrew first -- see [2/10])"
        return
    fi
    warn "  Not found -- installing via Homebrew..."
    brew install "${pkg}" 2>&1 | tail -3 || true
    if command -v "${cmd}" &>/dev/null; then
        ok "  ${cmd} installed"
    else
        fail_check "${cmd}  ->  brew install ${pkg}"
    fi
}

# find_sdk
# Print the path of the best available macOS SDK.
# Prefers MacOSX14 (most compatible with Qt 6.7.x), falls back to 15, then
# the system default (macOS 26+ SDK may be unsupported by Qt 6.7.3).
find_sdk() {
    local clt_base="/Library/Developer/CommandLineTools/SDKs"
    local xcode_base
    xcode_base="$(xcode-select -p 2>/dev/null)/Platforms/MacOSX.platform/Developer/SDKs"
    local sdk=""
    for ver in 14 15; do
        sdk="$(find "${clt_base}" "${xcode_base}" -maxdepth 1 \
                   -name "MacOSX${ver}*.sdk" -type d 2>/dev/null \
               | sort -V | tail -1)"
        [[ -n "${sdk}" ]] && echo "${sdk}" && return
    done
    warn "No MacOSX14/15 SDK found -- falling back to system default (build may fail with Qt 6.7.3)"
    xcrun --show-sdk-path 2>/dev/null
}

# sign_target <path>
# Sign a single target (without --deep) using Developer ID or ad-hoc.
sign_target() {
    local target="$1"
    if [[ -n "${SIGN_IDENTITY}" ]]; then
        codesign --force --options runtime \
            --entitlements "${ENTITLEMENTS}" \
            --sign "${SIGN_IDENTITY}" \
            "${target}" 2>&1 | grep -v "replacing existing signature" || true
    else
        codesign --force --sign - "${target}" 2>&1 | grep -v "replacing existing signature" || true
    fi
}

# ===========================================================================
# PRE-FLIGHT  (10 checks -- all run even if earlier ones fail)
# ===========================================================================
printf "==================================================\n"
printf "  Scanning build environment...\n"
printf "==================================================\n"

# -- [1/10] Xcode Command Line Tools -----------------------------------------
step "1/10" "Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
    ok "Xcode CLT: $(xcode-select -p)"
else
    warn "  Not found -- launching installer (interactive prompt will appear)..."
    xcode-select --install 2>/dev/null || true
    printf "  Press Enter after installation completes... "; read -r
    if xcode-select -p &>/dev/null; then
        ok "  Installed: $(xcode-select -p)"
    else
        fail_check "Xcode CLT  ->  xcode-select --install"
    fi
fi

# -- [2/10] Homebrew ---------------------------------------------------------
step "2/10" "Homebrew"
if command -v brew &>/dev/null; then
    ok "brew: $(brew --prefix)"
else
    warn "  Not found -- installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tail -5 || true
    BREW_BIN="$([[ "${ARCH}" == arm64 ]] && echo /opt/homebrew || echo /usr/local)/bin/brew"
    [[ -x "${BREW_BIN}" ]] && eval "$("${BREW_BIN}" shellenv)" 2>/dev/null || true
    if command -v brew &>/dev/null; then
        ok "  Homebrew installed: $(brew --prefix)"
    else
        fail_check "Homebrew  ->  https://brew.sh"
    fi
fi

# -- [3/10] librsvg ----------------------------------------------------------
step "3/10" "librsvg (rsvg-convert)"
brew_tool rsvg-convert librsvg

# -- [4/10] pkg-config -------------------------------------------------------
step "4/10" "pkg-config"
brew_tool pkg-config pkg-config

# -- [5/10] Python Pillow (required by generate_platform_icons.sh) -----------
step "5/10" "Python Pillow"
if python3 -c "from PIL import Image" &>/dev/null 2>&1; then
    ok "Pillow: installed"
elif ! command -v python3 &>/dev/null; then
    fail_check "Pillow  ->  brew install python3  then  python3 -m pip install Pillow"
else
    warn "  Not found -- installing via pip..."
    python3 -m pip install --quiet Pillow 2>&1 | tail -3 || true
    if python3 -c "from PIL import Image" &>/dev/null 2>&1; then
        ok "  Pillow installed"
    else
        fail_check "Pillow  ->  python3 -m pip install Pillow"
    fi
fi

# -- [6/10] Qt ---------------------------------------------------------------
step "6/10" "Qt ${QT_VERSION}"
if [[ -x "${QT_DIR}/bin/qmake" ]]; then
    export PATH="${QT_DIR}/bin:${PATH}"
    ok "Qt: ${QT_DIR}"
elif ! command -v python3 &>/dev/null; then
    fail_check "Qt ${QT_VERSION}  ->  brew install python3  then re-run"
else
    warn "  Not found -- installing via aqt (~2-3 GB, may take a while)..."
    python3 -m pip install --quiet --upgrade aqtinstall 2>&1 | tail -2 || true
    PIP_BIN="$(python3 -m site --user-base)/bin"
    export PATH="${PIP_BIN}:${PATH}"
    if command -v aqt &>/dev/null; then
        aqt install-qt mac desktop "${QT_VERSION}" clang_64 \
            --outputdir "${HOME}/Qt" \
            -m qtwebengine qtquick3d qtwebchannel qtpositioning qtlocation 2>&1 | tail -5 || true
    fi
    if [[ -x "${QT_DIR}/bin/qmake" ]]; then
        export PATH="${QT_DIR}/bin:${PATH}"
        grep -qF "${QT_DIR}/bin" "${HOME}/.zshrc" 2>/dev/null \
            || echo "export PATH=\"${QT_DIR}/bin:\$PATH\"" >> "${HOME}/.zshrc"
        ok "  Qt ${QT_VERSION} installed"
    else
        fail_check "Qt ${QT_VERSION}  ->  aqt install-qt mac desktop ${QT_VERSION} clang_64 --outputdir ~/Qt -m qtwebengine qtquick3d qtwebchannel qtpositioning qtlocation"
    fi
fi

# -- [7/10] vcpkg ------------------------------------------------------------
step "7/10" "vcpkg"
if [[ -x "${VCPKG_DIR}/vcpkg" ]]; then
    ok "vcpkg: ${VCPKG_DIR}"
elif ! command -v git &>/dev/null; then
    fail_check "vcpkg  ->  install Xcode CLT first (provides git)"
else
    warn "  Not found -- cloning to ${VCPKG_DIR}..."
    git clone https://github.com/microsoft/vcpkg.git "${VCPKG_DIR}" 2>&1 | tail -3 || true
    if [[ -f "${VCPKG_DIR}/bootstrap-vcpkg.sh" ]]; then
        "${VCPKG_DIR}/bootstrap-vcpkg.sh" -disableMetrics 2>&1 | tail -3 || true
        # Pin to the commit matching the downloaded binary to avoid script/binary mismatch
        BIN_DATE="$("${VCPKG_DIR}/vcpkg" version 2>/dev/null \
            | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)"
        if [[ -n "${BIN_DATE}" ]]; then
            PIN="$(git -C "${VCPKG_DIR}" log --before="${BIN_DATE} 23:59:59" \
                       -1 --format="%H" 2>/dev/null || true)"
            [[ -n "${PIN}" ]] && git -C "${VCPKG_DIR}" checkout "${PIN}" --quiet 2>/dev/null || true
        fi
    fi
    if [[ -x "${VCPKG_DIR}/vcpkg" ]]; then
        ok "  vcpkg initialized"
    else
        fail_check "vcpkg  ->  git clone https://github.com/microsoft/vcpkg.git ${VCPKG_DIR} && ${VCPKG_DIR}/bootstrap-vcpkg.sh -disableMetrics"
    fi
fi

# -- [8/10] sentry-native ----------------------------------------------------
step "8/10" "sentry-native (${VCPKG_TRIPLET})"
if [[ -f "${SENTRY_ROOT}/lib/libsentry.a" ]]; then
    ok "sentry: ${SENTRY_ROOT}"
elif [[ ! -x "${VCPKG_DIR}/vcpkg" ]]; then
    fail_check "sentry-native  ->  install vcpkg first (see [7/10])"
else
    warn "  Not found -- building via vcpkg (~15-20 min first time)..."
    "${VCPKG_DIR}/vcpkg" install \
        --triplet "${VCPKG_TRIPLET}" \
        --x-manifest-root "${PROJECT_DIR}" \
        --x-install-root "${VCPKG_DIR}/installed" 2>&1 | tail -5 || true
    if [[ -f "${SENTRY_ROOT}/lib/libsentry.a" ]]; then
        ok "  sentry-native installed"
    else
        fail_check "sentry-native  ->  ${VCPKG_DIR}/vcpkg install --triplet ${VCPKG_TRIPLET} --x-manifest-root ${PROJECT_DIR}"
    fi
fi

# -- [9/10] DSCC SDK  (must be provided manually -- no auto-install possible) -
step "9/10" "DSCC SDK"
if [[ -z "${DSCC_DIR}" ]]; then
    fail_check "DSCC SDK  ->  export DSCC_DIR=/path/to/DSCC  (must be set manually)"
elif [[ ! -f "${DSCC_DIR}/include/dscc/core/common/active_notify.h" ]]; then
    fail_check "DSCC SDK  ->  ${DSCC_DIR} does not contain SDK headers; verify DSCC_DIR"
else
    ok "DSCC: ${DSCC_DIR}"
fi

# -- [10/10] App icon  (depends on librsvg [3] and Pillow [5]) ---------------
step "10/10" "App icon (SafeLogo.icns)"
if [[ -f "${PROJECT_DIR}/icons/SafeLogo.icns" ]]; then
    ok "SafeLogo.icns: ${PROJECT_DIR}/icons/SafeLogo.icns"
else
    warn "  Not found -- generating..."
    bash "${PROJECT_DIR}/icons/generate_platform_icons.sh" 2>&1 | tail -3 || true
    if [[ -f "${PROJECT_DIR}/icons/SafeLogo.icns" ]]; then
        ok "  SafeLogo.icns generated"
    else
        fail_check "SafeLogo.icns  ->  bash ${PROJECT_DIR}/icons/generate_platform_icons.sh  (requires librsvg + Pillow)"
    fi
fi

# -- Preflight result --------------------------------------------------------
printf "\n"
if [[ ${#PREFLIGHT_FAILED[@]} -gt 0 ]]; then
    printf "==================================================\n"
    printf "${RED}  Pre-flight FAILED -- %d item(s) not ready${NC}\n\n" "${#PREFLIGHT_FAILED[@]}"
    for item in "${PREFLIGHT_FAILED[@]}"; do
        printf "  ${RED}[MISSING]${NC}  %s\n" "${item}"
    done
    printf "\n  Fix the items above, then re-run this script.\n"
    printf "==================================================\n"
    exit 1
fi

printf "==================================================\n"
printf "${GREEN}  All checks passed -- starting build.${NC}\n"
printf "==================================================\n\n"

# Any unexpected error from here aborts immediately.
set -e

# ===========================================================================
# [1/5] Compile
# ===========================================================================
printf "[1/5] Compiling DatasafeBox ${VERSION}...\n"

SDKROOT="$(find_sdk)"
[[ -z "${SDKROOT}" ]] && die "No usable macOS SDK found"
QMAKE_SDK="$(basename "${SDKROOT}" .sdk | tr 'A-Z' 'a-z')"
info "SDK   : ${SDKROOT}"
info "qmake : ${QMAKE_SDK}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"
cd "${BUILD_DIR}"

qmake "${PRO_FILE}" \
    CONFIG+=release \
    CONFIG+=sdk_no_version_check \
    QMAKE_MACOSX_DEPLOYMENT_TARGET="${DEPLOY_TARGET}" \
    QMAKE_MAC_SDK="${QMAKE_SDK}" \
    "QMAKE_CXXFLAGS+=-isystem ${SDKROOT}/usr/include/c++/v1" \
    "QMAKE_LIBS_OPENGL=-framework OpenGL" \
    SENTRY_ROOT_DIR="${SENTRY_ROOT}" \
    DSCC_DIR="${DSCC_DIR}"

# -framework AGL was removed in macOS 14+; it leaks in via Qt prl files
# and cannot be overridden on the qmake command line.
sed -i '' 's/-framework AGL//g' "${BUILD_DIR}/Makefile"

make -j"$(sysctl -n hw.ncpu)"

APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
[[ -d "${APP_BUNDLE}" ]] || die "Build produced no .app bundle: ${APP_BUNDLE}"
ok "Compile done"

# Patch bundle version (Info.plist contains a static placeholder; update it
# so CFBundleVersion / CFBundleShortVersionString reflect the real release).
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" \
    "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" \
    "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true

# Copy crashpad_handler into the bundle for Sentry crash reporting
CRASHPAD="${SENTRY_ROOT}/tools/sentry-native/crashpad_handler"
if [[ -f "${CRASHPAD}" ]]; then
    cp "${CRASHPAD}" "${APP_BUNDLE}/Contents/MacOS/"
    chmod +x "${APP_BUNDLE}/Contents/MacOS/crashpad_handler"
    ok "crashpad_handler bundled"
else
    warn "crashpad_handler not found -- Sentry crash reporting disabled"
fi

# Copy DSCC dylibs and WCDB framework into the bundle before macdeployqt so
# that macdeployqt can trace their dependencies and rewrite install names.
DSCC_FWDIR="${APP_BUNDLE}/Contents/Frameworks"
mkdir -p "${DSCC_FWDIR}"

# Core DSCC dylibs
for _lib in libdscc_common.dylib libdscc_core.dylib; do
    _src="${DSCC_DIR}/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# ycrypto dylibs (libycrypto_stdeth + transitive: core, toolkit)
for _lib in libycrypto_stdeth.dylib libycrypto_core.dylib libycrypto_toolkit.dylib; do
    _src="${DSCC_DIR}/deps/ycrypto/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# OpenSSL (required by libycrypto_stdeth)
for _lib in libcrypto.3.dylib libssl.3.dylib; do
    _src="${DSCC_DIR}/deps/openssl/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# secp256k1 (required by libycrypto_stdeth)
for _lib in libsecp256k1.6.dylib; do
    _src="${DSCC_DIR}/deps/secp256k1/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# Boost (required by libdscc_common + libdscc_core + libycrypto_core/toolkit)
for _lib in libboost_system.dylib libboost_filesystem.dylib libboost_atomic.dylib libboost_program_options.dylib; do
    _src="${DSCC_DIR}/deps/boost/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# fflib (required by libdscc_core)
for _lib in libff_net.dylib; do
    _src="${DSCC_DIR}/deps/fflib/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# glog (required by libycrypto_core + libycrypto_toolkit)
# Note: libglog.2.dylib install name is @rpath/libglog.0.7.1.dylib -- fix it so
# dyld resolves by the actual filename in the bundle.
for _lib in libglog.2.dylib; do
    _src="${DSCC_DIR}/deps/glog/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        install_name_tool -id "@rpath/${_lib}" "${DSCC_FWDIR}/${_lib}"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# gflags (required by libycrypto_core + libycrypto_toolkit)
# Note: libgflags.2.3.dylib install name is @rpath/libgflags.2.3.0.dylib -- fix.
for _lib in libgflags.2.3.dylib; do
    _src="${DSCC_DIR}/deps/gflags/lib/${_lib}"
    if [[ -f "${_src}" ]]; then
        cp -f "${_src}" "${DSCC_FWDIR}/"
        install_name_tool -id "@rpath/${_lib}" "${DSCC_FWDIR}/${_lib}"
        ok "bundled ${_lib}"
    else
        warn "${_src} not found -- bundle may be incomplete"
    fi
done

# WCDB framework
_wcdb_src="${DSCC_DIR}/deps/wcdb/lib/WCDB.framework"
if [[ -d "${_wcdb_src}" ]]; then
    cp -Rf "${_wcdb_src}" "${DSCC_FWDIR}/"
    ok "bundled WCDB.framework"
else
    warn "${_wcdb_src} not found -- bundle may be incomplete"
fi

# ===========================================================================
# [2/5] Deploy Qt frameworks
# ===========================================================================
printf "\n[2/5] Running macdeployqt...\n"

# macOS 26+ removed otool-classic; macdeployqt 6.7.x requires it.
# Create a local shim so it works without sudo.
if ! command -v otool-classic &>/dev/null; then
    mkdir -p "${BUILD_DIR}/.shims"
    ln -sf "$(command -v otool)" "${BUILD_DIR}/.shims/otool-classic"
    export PATH="${BUILD_DIR}/.shims:${PATH}"
fi

macdeployqt "${APP_BUNDLE}" -qmldir="${PROJECT_DIR}/qml"
ok "macdeployqt done"

# ===========================================================================
# [3/5] Trim bundle  (reduce distribution size)
# ===========================================================================
printf "\n[3/5] Trimming bundle...\n"

# Strip debug symbols from dylibs / shared libraries
find "${APP_BUNDLE}" -type f \( -name "*.dylib" -o -name "*.so" \) \
    -exec strip -x {} \; 2>/dev/null || true
find "${APP_BUNDLE}/Contents/Frameworks" -type f -perm +111 \
    ! -name "*.pak" ! -name "*.dat" ! -name "*.bin" \
    -exec sh -c 'file "$1" 2>/dev/null | grep -q "Mach-O" && strip -x "$1" 2>/dev/null || true' _ {} \;

# Keep only zh-CN and en-US WebEngine locales (~saves 30 MB)
LOCALES="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Resources/qtwebengine_locales"
[[ -d "${LOCALES}" ]] && find "${LOCALES}" -name "*.pak" \
    ! -name "zh-CN.pak" ! -name "en-US.pak" -delete

# Remove DevTools pak -- only needed when DevTools is explicitly enabled in code (~saves 9 MB)
DEVTOOLS="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Resources/qtwebengine_devtools_resources.pak"
[[ -f "${DEVTOOLS}" ]] && rm -f "${DEVTOOLS}"

# Remove unused QML Controls styles -- app uses QQuickStyle::setStyle("Basic") exclusively
QML_CTRL="${APP_BUNDLE}/Contents/Resources/qml/QtQuick/Controls"
for STYLE in iOS macOS Fusion Universal Imagine Material designer; do
    [[ -d "${QML_CTRL}/${STYLE}" ]] && rm -rf "${QML_CTRL}/${STYLE}"
done

# Remove Qt Creator design-time metadata (not needed at runtime)
[[ -d "${APP_BUNDLE}/Contents/Resources/qml/QtQuick/tooling" ]] \
    && rm -rf "${APP_BUNDLE}/Contents/Resources/qml/QtQuick/tooling"

# Copy open-source license files
LICENSE_DST="${APP_BUNDLE}/Contents/Resources/licenses"
rm -rf "${LICENSE_DST}"; mkdir -p "${LICENSE_DST}"
cp    "${PROJECT_DIR}/LICENSE"                "${LICENSE_DST}/LICENSE"
cp    "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md" "${LICENSE_DST}/THIRD_PARTY_NOTICES.md"
cp -R "${PROJECT_DIR}/LICENSES"               "${LICENSE_DST}/LICENSES"

ok "Bundle trimmed"

# ===========================================================================
# [4/5] Code signing
# ===========================================================================
printf "\n[4/5] Signing...\n"

WEBENGINE_PROCESS="${APP_BUNDLE}/Contents/Frameworks/QtWebEngineCore.framework/Versions/A/Helpers/QtWebEngineProcess.app"

if [[ -n "${SIGN_IDENTITY}" ]]; then
    # Sign the whole bundle first (--deep covers all nested components).
    codesign --force --deep --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing signature" || true

    # Re-sign QtWebEngineProcess separately: --deep above overwrites its JIT
    # entitlement. Without this, Hardened Runtime blocks JavaScript JIT and
    # the login page renders blank.
    [[ -d "${WEBENGINE_PROCESS}" ]] && sign_target "${WEBENGINE_PROCESS}"

    ok "Developer ID signed: ${SIGN_IDENTITY}"
else
    warn "No Developer ID certificate -- using ad-hoc signature (not suitable for distribution)"
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing signature" || true
fi

# ===========================================================================
# [5/5] Build DMG
# ===========================================================================
printf "\n[5/5] Building DMG...\n"

DMG_STAGING="${BUILD_DIR}/dmg_staging"
DMG_TMP="${BUILD_DIR}/tmp_rw.dmg"
rm -rf "${DMG_STAGING}"; mkdir -p "${DMG_STAGING}"

# Use ditto (not cp -r) to preserve symlinks inside Qt .framework bundles.
# cp -r dereferences them, doubling framework binary storage (~3x size).
ditto "${APP_BUNDLE}" "${DMG_STAGING}/$(basename "${APP_BUNDLE}")"
ln -s /Applications "${DMG_STAGING}/Applications"

rm -f "${DMG_TMP}" "${DIST_DIR}/${DMG_NAME}"
hdiutil create -volname "DataSafebox ${VERSION}" -srcfolder "${DMG_STAGING}" \
    -ov -format UDRW "${DMG_TMP}" >/dev/null
hdiutil convert "${DMG_TMP}" -format UDZO -o "${DIST_DIR}/${DMG_NAME}" >/dev/null
rm -f "${DMG_TMP}"

if [[ -n "${SIGN_IDENTITY}" ]]; then
    codesign --force --sign "${SIGN_IDENTITY}" "${DIST_DIR}/${DMG_NAME}" \
        2>&1 | grep -v "replacing existing signature" || true
    ok "DMG signed"

    if [[ "${SKIP_NOTARY}" == "1" ]]; then
        warn "Notarization skipped (SKIP_NOTARY=1)"
    elif xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" &>/dev/null; then
        info "Submitting for Apple notarization (may take a few minutes)..."
        xcrun notarytool submit "${DIST_DIR}/${DMG_NAME}" \
            --keychain-profile "${NOTARY_PROFILE}" --wait
        xcrun stapler staple "${DIST_DIR}/${DMG_NAME}"
        ok "Notarized and stapled"
    else
        warn "Notarization credentials not found -- skipping"
        warn "  Run once: xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" --apple-id <id> --team-id <team> --password <pwd>"
    fi
else
    warn "No Developer ID -- DMG uses ad-hoc signature (not suitable for distribution)"
fi

printf "\n"
printf "==================================================\n"
printf "%s  Build complete!%s\n" "${GREEN}" "${NC}"
printf "  Version : %s\n" "${VERSION}"
printf "  Output  : %s/%s\n" "${DIST_DIR}" "${DMG_NAME}"
printf "==================================================\n"
