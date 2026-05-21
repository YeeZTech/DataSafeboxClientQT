#!/usr/bin/env bash
# build_appimage.sh — Linux 一键构建 + 打包脚本
#
# 用法：./build_appimage.sh
#
# 自动完成：环境检测安装 → 编译 → linuxdeploy → .AppImage
# 幂等设计：已安装的依赖自动跳过，重复运行安全。
#
# 所有路径均可通过环境变量覆盖：
#   QT_VERSION      Qt 版本（默认 6.7.3）
#   SENTRY_ROOT_DIR vcpkg sentry-native 安装目录

set -euo pipefail

# ── 颜色输出 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

# ── 路径 & 版本常量 ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # builder/linux/
PROJECT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"        # 仓库根目录
PARENT_DIR="$(dirname "${PROJECT_DIR}")"
APP_NAME="DataSafebox"
QT_VERSION="${QT_VERSION:-6.7.3}"
BUILD_DIR="${PROJECT_DIR}/build/linux"
DIST_DIR="${SCRIPT_DIR}"
APPDIR="${BUILD_DIR}/AppDir"

VERSION="$(grep -oE '<Version>[^<]+' \
    "${PROJECT_DIR}/installer/packages/com.datasafebox.client/meta/package.xml" \
    | head -1 | sed 's|<Version>||')"
[[ -z "${VERSION}" ]] && VERSION="1.0.0"

# ── 自动检测 CPU 架构 ──────────────────────────────────────────
ARCH_RAW="$(uname -m)"
if [[ "${ARCH_RAW}" == "aarch64" || "${ARCH_RAW}" == "arm64" ]]; then
    VCPKG_TRIPLET="arm64-linux"
    APPIMAGE_ARCH="aarch64"
    QT_ARCH_DIR="gcc_arm64"
else
    VCPKG_TRIPLET="x64-linux"
    APPIMAGE_ARCH="x86_64"
    QT_ARCH_DIR="gcc_64"
fi

QT_DIR="${HOME}/Qt/${QT_VERSION}/${QT_ARCH_DIR}"
VCPKG_DIR="${PARENT_DIR}/vcpkg"
SENTRY_ROOT="${SENTRY_ROOT_DIR:-${VCPKG_DIR}/installed/${VCPKG_TRIPLET}}"

# ── USE_TEST_ENV 校验 ─────────────────────────────────────────
if [[ -z "${USE_TEST_ENV:-}" ]]; then
    error "USE_TEST_ENV is not set. Export USE_TEST_ENV=0 (production) or USE_TEST_ENV=1 (test) before running this script."
fi
if [[ "${USE_TEST_ENV}" != "0" && "${USE_TEST_ENV}" != "1" ]]; then
    error "USE_TEST_ENV=${USE_TEST_ENV} is invalid. Only 0 or 1 is accepted."
fi

echo ""
echo "=================================================="
echo "  DatasafeBox ${VERSION} — Linux 构建打包"
echo "  CPU 架构  : ${ARCH_RAW}"
echo "  vcpkg 三元: ${VCPKG_TRIPLET}"
echo "  Qt        : ${QT_VERSION}"
echo "  Env       : $([[ "${USE_TEST_ENV}" == "1" ]] && echo 'TEST' || echo 'PRODUCTION')"
echo "=================================================="
echo ""

# ══════════════════════════════════════════════════════
# Part 1: 环境准备（幂等，已装则跳过）
# ══════════════════════════════════════════════════════

# ── 1. 系统依赖 ───────────────────────────────────────
info "检查系统依赖..."
MISSING_PKGS=()
for pkg in curl git cmake ninja-build libgl1-mesa-dev libglu1-mesa-dev \
           libx11-dev libxkbcommon-dev libxkbcommon-x11-dev libxcb-icccm4-dev \
           libxcb-image0-dev libxcb-keysyms1-dev libxcb-randr0-dev \
           libxcb-render-util0-dev libxcb-xinerama0-dev libxcb-xfixes0-dev \
           librsvg2-bin libfuse2 python3-pip patchelf; do
    dpkg -s "${pkg}" &>/dev/null || MISSING_PKGS+=("${pkg}")
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    info "安装缺失系统包：${MISSING_PKGS[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends "${MISSING_PKGS[@]}"
    success "系统依赖安装完成"
else
    success "系统依赖已就绪"
fi

# ── 2. Qt ─────────────────────────────────────────────
info "检查 Qt ${QT_VERSION}..."
if [[ ! -x "${QT_DIR}/bin/qmake" ]]; then
    info "安装 Qt ${QT_VERSION}（约 2-3 GB）..."
    pip3 install --quiet --upgrade aqtinstall
    aqt install-qt linux desktop "${QT_VERSION}" "${QT_ARCH_DIR}" \
        --outputdir "${HOME}/Qt" \
        -m qtwebengine qtquick3d
    success "Qt ${QT_VERSION} 安装完成"
else
    success "Qt ${QT_VERSION} 已安装"
fi

# 确保 qmake 在当前会话 PATH 中
export PATH="${QT_DIR}/bin:${PATH}"

# 写入 shell 配置（幂等）
SHELL_RC="${HOME}/.bashrc"
[[ "${SHELL}" == *"zsh"* ]] && SHELL_RC="${HOME}/.zshrc"
if ! grep -qF "${QT_DIR}/bin" "${SHELL_RC}" 2>/dev/null; then
    echo "export PATH=\"${QT_DIR}/bin:\$PATH\"" >> "${SHELL_RC}"
fi

qmake -v 2>/dev/null | grep -q "${QT_VERSION}" || error "qmake 验证失败，版本不匹配"
success "qmake：$(qmake -v | head -1)"

# ── 3. vcpkg ──────────────────────────────────────────
info "检查 vcpkg..."
if [[ ! -x "${VCPKG_DIR}/vcpkg" ]]; then
    info "克隆 vcpkg 到 ${VCPKG_DIR}..."
    git clone https://github.com/microsoft/vcpkg.git "${VCPKG_DIR}"
    "${VCPKG_DIR}/bootstrap-vcpkg.sh" -disableMetrics
    success "vcpkg 初始化完成"
else
    success "vcpkg 已存在"
fi

# ── 4. sentry-native ──────────────────────────────────
info "检查 sentry-native（${VCPKG_TRIPLET}）..."
if [[ ! -f "${SENTRY_ROOT}/lib/libsentry.a" ]]; then
    info "编译安装 sentry-native（首次约 15-20 分钟）..."
    "${VCPKG_DIR}/vcpkg" install --triplet "${VCPKG_TRIPLET}" \
        --x-manifest-root "${PROJECT_DIR}" \
        --x-install-root "${VCPKG_DIR}/installed"
    success "sentry-native 安装完成"
else
    success "sentry-native 已安装"
fi

# ── 5. linuxdeploy ────────────────────────────────────
LINUXDEPLOY="${HOME}/.local/bin/linuxdeploy-${APPIMAGE_ARCH}.AppImage"
LINUXDEPLOY_QT="${HOME}/.local/bin/linuxdeploy-plugin-qt-${APPIMAGE_ARCH}.AppImage"
info "检查 linuxdeploy..."
if [[ ! -x "${LINUXDEPLOY}" ]]; then
    info "下载 linuxdeploy..."
    mkdir -p "$(dirname "${LINUXDEPLOY}")"
    curl -fsSL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${APPIMAGE_ARCH}.AppImage" \
        -o "${LINUXDEPLOY}"
    chmod +x "${LINUXDEPLOY}"
    success "linuxdeploy 下载完成"
else
    success "linuxdeploy 已存在"
fi
if [[ ! -x "${LINUXDEPLOY_QT}" ]]; then
    info "下载 linuxdeploy-plugin-qt..."
    curl -fsSL "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-${APPIMAGE_ARCH}.AppImage" \
        -o "${LINUXDEPLOY_QT}"
    chmod +x "${LINUXDEPLOY_QT}"
    success "linuxdeploy-plugin-qt 下载完成"
else
    success "linuxdeploy-plugin-qt 已存在"
fi
export PATH="${HOME}/.local/bin:${PATH}"
# 为 linuxdeploy 创建无后缀软链接（插件发现机制要求）
ln -sf "${LINUXDEPLOY}"    "${HOME}/.local/bin/linuxdeploy"
ln -sf "${LINUXDEPLOY_QT}" "${HOME}/.local/bin/linuxdeploy-plugin-qt"

# ── 6. 图标 ───────────────────────────────────────────
info "检查 Linux 图标..."
if [[ ! -f "${PROJECT_DIR}/icons/SafeLogo_256.png" ]]; then
    chmod +x "${PROJECT_DIR}/icons/generate_platform_icons.sh"
    bash "${PROJECT_DIR}/icons/generate_platform_icons.sh"
else
    success "SafeLogo_256.png 已存在"
fi

# ══════════════════════════════════════════════════════
# Part 2: 编译 + 打包
# ══════════════════════════════════════════════════════

info "开始编译 DatasafeBox ${VERSION}..."
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"
rm -rf "${APPDIR}"
cd "${BUILD_DIR}"

qmake "${PROJECT_DIR}/datasafebox-qt-client.pro" \
    CONFIG+=release \
    USE_TEST_ENV="${USE_TEST_ENV}" \
    SENTRY_ROOT_DIR="${SENTRY_ROOT}"
make -j"$(nproc)"
make INSTALL_ROOT="${APPDIR}" install

BIN_DIR="${APPDIR}/opt/datasafebox-client"
[[ -x "${BIN_DIR}/${APP_NAME}" ]] || error "编译失败，未找到 ${BIN_DIR}/${APP_NAME}"
success "编译完成"

# 拷贝 crashpad_handler
CRASHPAD="${SENTRY_ROOT}/tools/sentry-native/crashpad_handler"
if [[ -f "${CRASHPAD}" ]]; then
    cp "${CRASHPAD}" "${BIN_DIR}/"
    chmod +x "${BIN_DIR}/crashpad_handler"
    success "已打入 crashpad_handler"
else
    warn "crashpad_handler 未找到（${CRASHPAD}），Sentry 崩溃捕获不可用"
fi

# 拷贝开源许可与第三方组件声明
DOC_DIR="${APPDIR}/usr/share/doc/datasafebox-client"
info "拷贝开源许可文件..."
mkdir -p "${DOC_DIR}"
cp "${PROJECT_DIR}/LICENSE" "${DOC_DIR}/LICENSE"
cp "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md" "${DOC_DIR}/THIRD_PARTY_NOTICES.md"
cp -R "${PROJECT_DIR}/LICENSES" "${DOC_DIR}/LICENSES"
success "开源许可文件已打入 AppDir"

# AppRun 入口
cat > "${APPDIR}/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/opt/datasafebox-client:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="${HERE}/usr/plugins"
export QML2_IMPORT_PATH="${HERE}/usr/qml"
exec "${HERE}/opt/datasafebox-client/DataSafebox" "$@"
APPRUN
chmod +x "${APPDIR}/AppRun"

# linuxdeploy 收集依赖并打包 AppImage
info "运行 linuxdeploy 打包 AppImage..."
export VERSION
export ARCH="${APPIMAGE_ARCH}"
linuxdeploy \
    --appdir "${APPDIR}" \
    --executable "${BIN_DIR}/${APP_NAME}" \
    --desktop-file "${PROJECT_DIR}/builder/linux/datasafebox-client.desktop" \
    --icon-file "${PROJECT_DIR}/icons/SafeLogo_256.png" \
    --plugin qt \
    --output appimage

# 将输出文件移入 dist/
APPIMAGE_FILE="$(ls "${BUILD_DIR}"/DatasafeBox*.AppImage 2>/dev/null | head -1 || \
                 ls "${BUILD_DIR}"/*.AppImage 2>/dev/null | head -1)"
[[ -n "${APPIMAGE_FILE}" ]] || error "未找到生成的 AppImage 文件"
OUTPUT_NAME="DatasafeBox-${VERSION}-${APPIMAGE_ARCH}.AppImage"
mv "${APPIMAGE_FILE}" "${DIST_DIR}/${OUTPUT_NAME}"

echo ""
echo "=================================================="
echo -e "${GREEN}  打包完成！${NC}"
echo "  输出：${DIST_DIR}/${OUTPUT_NAME}"
echo "=================================================="
