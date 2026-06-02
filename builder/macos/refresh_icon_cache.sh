#!/usr/bin/env bash
# refresh_icon_cache.sh -- force macOS to drop cached app icons and reload them.
#
# The icon embedded in the .app bundle is always correct after a build; this only
# clears the OS-side caches (LaunchServices + IconServices + Dock/Finder) that can
# keep showing a previous version's icon after an in-place upgrade. This is the
# macOS counterpart of the icon-cache refresh the Windows installer does itself
# (a DMG is drag-installed, so it has no post-install hook to run this for you).
#
# Usage:
#   ./builder/macos/refresh_icon_cache.sh                 # default /Applications app
#   ./builder/macos/refresh_icon_cache.sh /path/to/App.app
set -uo pipefail

APP="${1:-/Applications/数据安全柜控制台.app}"

echo "Refreshing macOS icon / LaunchServices cache for: ${APP}"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [[ -x "${LSREGISTER}" ]]; then
    # Re-register the specific bundle so LaunchServices picks up its new icon.
    [[ -d "${APP}" ]] && "${LSREGISTER}" -f "${APP}" && echo "  re-registered bundle"
    # Rebuild the whole LaunchServices database (clears stale/duplicate entries).
    "${LSREGISTER}" -kill -r -domain local -domain system -domain user || true
    echo "  LaunchServices database rebuilt"
else
    echo "  (lsregister not found -- skipping LaunchServices step)"
fi

# Clear the on-disk IconServices cache (needs sudo).
if sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null; then
    echo "  IconServices cache cleared"
else
    echo "  (skip IconServices clear -- re-run with sudo to enable)"
fi

# Restart Dock + Finder so they redraw with fresh icons.
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
echo "  Dock + Finder restarted"

echo "Done. If the icon is still stale, log out and back in (or reboot)."
