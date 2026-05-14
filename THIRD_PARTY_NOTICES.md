# Third-Party Notices

This document summarizes third-party components used by DataSafebox Qt Client.
It is not a substitute for legal review. Release packages should include the
license texts and notices for the exact binary dependencies shipped in that
package.

## Project Source Code

- Component: DataSafebox Qt Client source code in this repository
- Copyright: Copyright (C) 2026 北京熠智科技有限公司
- License: GNU Lesser General Public License v3.0 or later
- SPDX: `LGPL-3.0-or-later`
- License files: `LICENSE`, `LICENSES/LGPL-3.0-or-later.txt`,
  `LICENSES/GPL-3.0-or-later.txt`

## Qt

- Component: Qt 6.7.3, including Qt Core, Qt QML, Qt Quick,
  Qt Quick Controls 2, Qt Network, Qt SVG, Qt Widgets, and Qt WebEngineQuick
- License: Qt is available under commercial and open-source licenses. This
  project is intended to be used with Qt open-source licensing, primarily
  LGPLv3/GPLv3 terms for the Qt modules used by the application.
- Notes: When distributing Qt runtime libraries, QML modules, plugins, and
  tools with the application, keep the corresponding Qt license texts and
  third-party notices from the exact Qt installation used for the build.
- Reference: https://doc.qt.io/qt-6/licensing.html

## Qt WebEngine and Chromium

- Component: Qt WebEngine / Chromium runtime bundled by Qt deployment tools
- License: Qt-specific WebEngine code is available under Qt commercial terms
  or open-source GPL/LGPL terms. The Chromium portion contains code under
  multiple third-party open-source licenses.
- Notes: Release packages that include Qt WebEngine must preserve the relevant
  Qt WebEngine and Chromium third-party license notices for the exact Qt
  version and platform build.
- Reference: https://doc.qt.io/qt-6/qtwebengine-licensing.html

## Sentry Native

- Component: Sentry Native, brought in through vcpkg
- License: MIT
- Notes: Include the Sentry Native MIT license text when distributing Sentry
  runtime binaries such as `sentry.dll`/`libsentry` and `crashpad_handler`.
- Reference: https://vcpkg.io/en/package/sentry-native

## DSCC Runtime and Related Binaries

- Component: DSCC SDK/runtime and related binaries copied or linked by the
  Windows build, including DSCC, WCDB, ycrypto, Boost, glog/gflags, OpenSSL,
  and related runtime libraries supplied through `DSCC_DIR`
- License: Separately licensed external dependency
- Notes: These binaries are not licensed by this repository's LGPL grant.
  Obtain distribution permission and third-party notices from the DSCC SDK or
  the corresponding upstream projects before publishing release packages.
