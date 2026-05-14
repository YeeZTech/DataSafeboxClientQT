#!/usr/bin/env bash
# 从 icons/SafeLogo.svg 生成跨平台图标。
# macOS: 生成 SafeLogo.icns（需要 iconutil + rsvg-convert 或 sips）
# Linux: 生成 SafeLogo_256.png（需要 rsvg-convert 或 inkscape）
#
# 使用方法:
#   ./icons/generate_platform_icons.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG="${SCRIPT_DIR}/SafeLogo.svg"

# Ensure Pillow is available (required for transparent-canvas padding step)
if ! python3 -c "from PIL import Image" &>/dev/null 2>&1; then
    echo "Installing Python Pillow..."
    python3 -m pip install --quiet Pillow
fi

if [[ ! -f "${SVG}" ]]; then
    echo "ERROR: ${SVG} not found" >&2
    exit 1
fi

render_png() {
    local out="$1" size="$2" padding="${3:-0}"
    local inner=$((size - padding * 2))
    if [[ "${padding}" -gt 0 ]]; then
        # Render at inner size then expand canvas with transparent padding via Python
        local tmp="${out%.png}_tmp.png"
        if command -v rsvg-convert >/dev/null 2>&1; then
            rsvg-convert -w "${inner}" -h "${inner}" -o "${tmp}" "${SVG}"
        elif command -v inkscape >/dev/null 2>&1; then
            inkscape --export-type=png --export-filename="${tmp}" -w "${inner}" -h "${inner}" "${SVG}"
        else
            echo "ERROR: need rsvg-convert or inkscape installed" >&2
            exit 1
        fi
        python3 - "${tmp}" "${out}" "${size}" "${padding}" <<'PYEOF'
import sys
from PIL import Image
src, dst, size, pad = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
img = Image.open(src).convert("RGBA")
canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
canvas.paste(img, (pad, pad))
canvas.save(dst)
PYEOF
        rm -f "${tmp}"
    else
        if command -v rsvg-convert >/dev/null 2>&1; then
            rsvg-convert -w "${size}" -h "${size}" -o "${out}" "${SVG}"
        elif command -v inkscape >/dev/null 2>&1; then
            inkscape --export-type=png --export-filename="${out}" -w "${size}" -h "${size}" "${SVG}"
        else
            echo "ERROR: need rsvg-convert or inkscape installed" >&2
            exit 1
        fi
    fi
}

# Linux PNG
render_png "${SCRIPT_DIR}/SafeLogo_256.png" 256
echo "Generated ${SCRIPT_DIR}/SafeLogo_256.png"

# macOS .icns（仅在 macOS 上生效，需要 iconutil）
if [[ "$(uname -s)" == "Darwin" ]] && command -v iconutil >/dev/null 2>&1; then
    ICONSET="${SCRIPT_DIR}/SafeLogo.iconset"
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"
    # macOS HIG: icon artwork should occupy ~80% of the canvas (10% padding each side)
    for s in 16 32 64 128 256 512; do
        pad=$((s / 10))
        render_png "${ICONSET}/icon_${s}x${s}.png" "${s}" "${pad}"
        s2=$((s * 2))
        pad2=$((s2 / 10))
        render_png "${ICONSET}/icon_${s}x${s}@2x.png" "${s2}" "${pad2}"
    done
    iconutil -c icns -o "${SCRIPT_DIR}/SafeLogo.icns" "${ICONSET}"
    rm -rf "${ICONSET}"
    echo "Generated ${SCRIPT_DIR}/SafeLogo.icns"
else
    echo "Skip .icns generation (not on macOS or iconutil missing)"
fi
