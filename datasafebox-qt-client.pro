QT += quick qml network core svg quickcontrols2 widgets webview

CONFIG += c++17

CONFIG -= qtquickcompiler
win32:CONFIG -= depend_includepath
# Release builds still need a PDB so Sentry can symbolicate native crash stack traces
# (uploaded to Sentry in CI, never shipped to users — see build_installer.bat's robocopy).
win32:CONFIG(release, debug|release): CONFIG += force_debug_info

# ── 敏感配置注入（密钥 / 令牌 / DSN）────────────────────────────────────
# 不在源码中硬编码：构建时从 secrets.env 读取，以编译期宏 DSBOX_<KEY> 注入，
# 供 src/config/AppConfig.h 使用。单一安装包同时内置测试/正式两套服务配置
# （登录页选择环境），因此 CASDOOR_CLIENT_ID 需要 test/prod 两个值。
# 本地开发：复制 .env.example 为 secrets.env 并填入真实值。
# CI：由 GitHub Secrets 在构建前写入。该文件已在 .gitignore 中，不会提交。
ENV_FILE = $$PWD/secrets.env
!exists($$ENV_FILE) {
    error("Secrets file not found: $$ENV_FILE — copy .env.example to secrets.env (local dev), or let CI write it from GitHub Secrets. See .env.example.")
}
ENV_REQUIRED_KEYS = SOKETI_APP_KEY CASDOOR_CLIENT_ID_TEST CASDOOR_CLIENT_ID_PROD CUSTOMER_SERVICE_TOKEN SENTRY_DSN
ENV_SEEN_KEYS =
ENV_LINES = $$cat($$ENV_FILE, lines)
for(line, ENV_LINES) {
    key = $$section(line, =, 0, 0)
    contains(ENV_REQUIRED_KEYS, $$key) {
        val = $$section(line, =, 1, -1)
        val ~= s/\\s+$//
        isEmpty(val): error("Empty value for $$key in $$ENV_FILE")
        DEFINES += DSBOX_$${key}=\\\"$${val}\\\"
        ENV_SEEN_KEYS += $$key
    }
}
for(k, ENV_REQUIRED_KEYS) {
    !contains(ENV_SEEN_KEYS, $$k): error("Missing required key $$k in $$ENV_FILE (see .env.example).")
}
message("Injected sensitive config from $$ENV_FILE")

# ── USE_LANG 编译期强制界面语言（EN = 英文，CN = 中文；不设置则按运行时逻辑）──
!isEmpty(USE_LANG) {
    USE_LANG_NORM = $$upper($$USE_LANG)
    equals(USE_LANG_NORM, EN) {
        DEFINES += FORCE_LANGUAGE=\\\"en\\\"
    } else:equals(USE_LANG_NORM, CN) {
        DEFINES += FORCE_LANGUAGE=\\\"zh_cn\\\"
    } else {
        error("USE_LANG=$$USE_LANG is invalid. Only EN or CN is accepted.")
    }
    message("USE_LANG=$$USE_LANG (forced UI language)")
}

# Application name
TARGET = DataSafebox

# Application version — Single Source of Truth
# Change this value to update all installer XML files and the C++ APP_VERSION macro.
VERSION = 1.1.2

# Inject into C++ code
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

# Sync version and release date to installer XML files at qmake time
CONFIG_XML = $$PWD/installer/config/config.xml
PKG_XML    = $$PWD/installer/packages/com.datasafebox.client/meta/package.xml
win32 {
    RELEASE_DATE = $$system("powershell -NoProfile -Command \"(Get-Date).ToString('yyyy-MM-dd')\"")
    DUMMY = $$system("powershell -NoProfile -Command \"$e=New-Object Text.UTF8Encoding($false); foreach($p in @('$$CONFIG_XML','$$PKG_XML')){$c=[IO.File]::ReadAllText($p,$e); $c=$c -replace '<Version>[^<]*</Version>','<Version>$$VERSION</Version>' -replace '<ReleaseDate>[^<]*</ReleaseDate>','<ReleaseDate>$$RELEASE_DATE</ReleaseDate>'; [IO.File]::WriteAllText($p,$c,$e)}\"")
} else {
    RELEASE_DATE = $$system(date +%Y-%m-%d)
    DUMMY = $$system("perl -i -pe 's|<Version>[^<]*</Version>|<Version>$$VERSION</Version>|; s|<ReleaseDate>[^<]*</ReleaseDate>|<ReleaseDate>$$RELEASE_DATE</ReleaseDate>|' '$$CONFIG_XML' '$$PKG_XML'")
}
message("Building version: $$VERSION ($$RELEASE_DATE)")

# The following defines are for the application itself.
SOURCES += \
    src/main.cpp \
    src/app/SingleApplication.cpp \
    src/core/PathManager.cpp \
    src/core/LanguageManager.cpp \
    src/services/CasdoorHelper.cpp \
    src/services/UpdateManager.cpp \
    src/services/SentryBridge.cpp \
    src/services/ArrearsManager.cpp \
    src/services/DsccBridge.cpp \
    src/services/FileTransferBridge.cpp

HEADERS += \
    src/config/AppConfig.h \
    src/app/SingleApplication.h \
    src/core/PathManager.h \
    src/core/LanguageManager.h \
    src/services/CasdoorHelper.h \
    src/services/UpdateManager.h \
    src/services/SentryBridge.h \
    src/services/ArrearsManager.h \
    src/services/DsccBridge.h \
    src/services/FileTransferBridge.h

INCLUDEPATH += \
    $$PWD/src/app \
    $$PWD/src/config \
    $$PWD/src/core \
    $$PWD/src/services

# Enable MOC for source files and headers that contain Q_OBJECT classes
CONFIG += automoc

# Qt Linguist — automatically compile .ts → .qm during the build
# and embed them into the Qt resource system under :/translations/.
CONFIG += lrelease embed_translations
QM_FILES_RESOURCE_PREFIX = translations
TRANSLATIONS += \
    translations/qml_zh_cn.ts \
    translations/notification_zh_cn.ts

RESOURCES += resources/resources.qrc

# Additional import path used to resolve QML modules in this project.
QML_IMPORT_PATH += $$PWD/qml

# Additional import path used to resolve QML modules just for Qt Creator
QML_DESIGNER_IMPORT_PATH += $$PWD/qml

# ===========================================================================
# 平台资源（图标 / Bundle 元信息 / Linux 桌面集成）
# ===========================================================================
win32 {
    exists($$PWD/icons/SafeLogo_256.ico) {
        RC_ICONS += $$PWD/icons/SafeLogo_256.ico
        message("Using application icon: $$PWD/icons/SafeLogo_256.ico")
    } else {
        message("Warning: icons/SafeLogo_256.ico not found. Executable will use default Windows icon.")
    }

    # 进程级 UTF-8 活动代码页（Win10 1903+）：DSCC/ycrypto 以窄字符 ANSI API 打开文件，
    # 没有它，非 ACP 字符（如英文系统区域下的中文文件名）会导致加解密 open file failed。
    # 由链接器在链接期把 manifest 并入（CONFIG 默认带 embed_manifest_exe → link /MANIFEST:embed）。
    # 用 /MANIFESTINPUT 而非链接后 mt.exe：链接期原子合并，失败会直接让链接报错，
    # 不会像 post-link "mt.exe & copy & copy" 那样被 & 串联吞掉退出码而静默产出缺 manifest 的 exe。
    QMAKE_LFLAGS += /MANIFESTINPUT:$$shell_quote($$shell_path($$PWD/builder/windows/utf8.manifest))
}
macx {
    exists($$PWD/icons/SafeLogo.icns) {
        ICON = $$PWD/icons/SafeLogo.icns
    }
    exists($$PWD/builder/macos/Info.plist) {
        QMAKE_INFO_PLIST = $$PWD/builder/macos/Info.plist
    }
}
linux {
    target.path = /opt/datasafebox-client
    INSTALLS += target
    exists($$PWD/builder/linux/datasafebox-client.desktop) {
        desktop.path = /usr/share/applications
        desktop.files = $$PWD/builder/linux/datasafebox-client.desktop
        INSTALLS += desktop
    }
    exists($$PWD/icons/SafeLogo_256.png) {
        appicon.path = /usr/share/icons/hicolor/256x256/apps
        appicon.files = $$PWD/icons/SafeLogo_256.png
        appicon.extra = $(COPY) $$PWD/icons/SafeLogo_256.png $(INSTALL_ROOT)/usr/share/icons/hicolor/256x256/apps/datasafebox-client.png
        INSTALLS += appicon
    }
}

# ===========================================================================
# 外部库路径配置
# 优先级：qmake 命令行参数 > 环境变量。
# 不在工程文件中探测本机相对目录或构建产物目录；请显式设置 SENTRY_ROOT_DIR / DSCC_DIR。
# 运行时服务 URL 在 AppConfig.h 中管理；密钥 / 令牌 / DSN 由 secrets.env 注入（见上方敏感配置注入段）。
# ===========================================================================

# Sentry Native (via vcpkg)
# SENTRY_DSN 由 secrets.env 注入（见上方敏感配置注入段）
isEmpty(SENTRY_ROOT_DIR): SENTRY_ROOT_DIR = $$(SENTRY_ROOT_DIR)
isEmpty(SENTRY_ROOT_DIR) {
    error("Sentry Native not found. Set SENTRY_ROOT_DIR to the vcpkg installed triplet root, for example D:/vcpkg/installed/x64-windows")
}
SENTRY_ROOT_DIR = $$clean_path($$SENTRY_ROOT_DIR)
!exists("$$SENTRY_ROOT_DIR/include/sentry.h") {
    error("Sentry Native headers not found at $$SENTRY_ROOT_DIR/include/sentry.h. Set SENTRY_ROOT_DIR to a valid installed triplet root.")
}
message("Sentry root dir: $$SENTRY_ROOT_DIR")
INCLUDEPATH += "$$SENTRY_ROOT_DIR/include"
LIBS        += -L"$$SENTRY_ROOT_DIR/lib" -lsentry
# Linux 上 sentry-native 的 crashpad backend 依赖 curl
linux: LIBS += -lcurl

# 运行时依赖：
#   Windows: sentry.dll + crashpad_handler.exe 需放入输出目录
#   macOS:   crashpad_handler 需打入 .app/Contents/MacOS
#   Linux:   crashpad_handler 需与可执行文件同目录
win32 {
    # sentry.dll (the app links it) + crashpad_handler.exe and the DLLs vcpkg put
    # next to it (zlib — named zlib1.dll or z.dll depending on the vcpkg version).
    # Globbing the tools dir avoids hardcoding the zlib DLL name.
    SENTRY_RUNTIME_FILES = $$SENTRY_ROOT_DIR/bin/sentry.dll
    SENTRY_RUNTIME_FILES += $$files($$SENTRY_ROOT_DIR/tools/sentry-native/*.dll)
    SENTRY_RUNTIME_FILES += $$SENTRY_ROOT_DIR/tools/sentry-native/crashpad_handler.exe

    CONFIG(release, debug|release) {
        for(file, SENTRY_RUNTIME_FILES) {
            exists($$file): QMAKE_POST_LINK += copy /Y $$shell_quote($$shell_path($$file)) $$shell_quote($$shell_path($$OUT_PWD/release)) >nul &
        }
    }
    CONFIG(debug, debug|release) {
        for(file, SENTRY_RUNTIME_FILES) {
            exists($$file): QMAKE_POST_LINK += copy /Y $$shell_quote($$shell_path($$file)) $$shell_quote($$shell_path($$OUT_PWD/debug)) >nul &
        }
    }
}

# ===========================================================================
# DSCC 核心动态库（dscc_common + dscc_core）
# 优先级：qmake 命令行参数 DSCC_DIR= > 环境变量 DSCC_DIR。
# ===========================================================================
isEmpty(DSCC_DIR): DSCC_DIR = $$(DSCC_DIR)
isEmpty(DSCC_DIR) {
    error("DSCC SDK not found. Set DSCC_DIR to a DSCC package root, for example D:/DSCC")
}

win32 {
    DSCC_DIR = $$clean_path($$DSCC_DIR)
    !exists("$$DSCC_DIR/include/dscc/core/common/active_notify.h") {
        error("DSCC SDK not found. Set DSCC_DIR to a DSCC package root that contains include/dscc/core/common/active_notify.h")
    }
    !exists("$$DSCC_DIR/bin/dscc_core.dll") {
        error("DSCC runtime not found. Set DSCC_DIR to a DSCC package root that contains bin/dscc_core.dll")
    }
    message("DSCC root dir: $$DSCC_DIR")

    INCLUDEPATH += "$$DSCC_DIR/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/boost/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/wcdb/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/ycrypto/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/openssl/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/secp256k1/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/glog/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/gflags/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/fflib/include"
    # dscc_transfer：加密文件的 WebRTC 点对点发送。libdatachannel 及其
    # usrsctp/juice 已静态链进该库，这里不需要额外的第三方依赖。
    LIBS += -L"$$DSCC_DIR/lib" -ldscc_common -ldscc_core -ldscc_transfer
    LIBS += -L"$$DSCC_DIR/deps/wcdb/lib" -lWCDB
    LIBS += -L"$$DSCC_DIR/deps/ycrypto/lib" -lycrypto_stdeth
    # C4068: 未知的杂注（WCDB 头文件含 #pragma mark，仅 Clang/Xcode 支持）
    QMAKE_CXXFLAGS += /wd4068
}

macx {
    DSCC_DIR = $$clean_path($$DSCC_DIR)
    !exists("$$DSCC_DIR/include/dscc/core/common/active_notify.h") {
        error("DSCC SDK not found. Set DSCC_DIR to a DSCC package root that contains include/dscc/core/common/active_notify.h")
    }
    message("DSCC root dir: $$DSCC_DIR")

    INCLUDEPATH += "$$DSCC_DIR/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/boost/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/wcdb/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/ycrypto/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/openssl/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/secp256k1/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/glog/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/gflags/include"
    INCLUDEPATH += "$$DSCC_DIR/deps/fflib/include"

    # dscc_transfer：加密文件的 WebRTC 点对点发送（libdatachannel 已静态链入）。
    LIBS += -L"$$DSCC_DIR/lib" -ldscc_common -ldscc_core -ldscc_transfer
    LIBS += -F"$$DSCC_DIR/deps/wcdb/lib" -framework WCDB
    LIBS += -L"$$DSCC_DIR/deps/ycrypto/lib" -lycrypto_stdeth

    # RPATH: allow the linker to resolve dylibs at compile time;
    # build_dmg.sh copies them into the bundle so macdeployqt can fix install names.
    QMAKE_RPATHDIR += "$$DSCC_DIR/lib"
    QMAKE_RPATHDIR += "$$DSCC_DIR/deps/wcdb/lib"
    QMAKE_RPATHDIR += "$$DSCC_DIR/deps/ycrypto/lib"
}

# Windows 打包：将 DSCC 运行时 DLL 复制到输出目录
# Qt6Core.dll / Qt6Network.dll 与客户端版本完全相同（MD5 一致），
# 由 windeployqt 统一处理，此处跳过，避免重复复制。
# DSCC 只提供 Release 版 DLL，Debug 构建同样使用 Release DLL。
win32 {
    # Copy EVERY DLL the DSCC SDK ships in bin/ rather than a hardcoded list, so a
    # new transitive dependency in a future SDK build never silently goes missing.
    # Skip Qt6*.dll only (windeployqt supplies copies matching the client's own Qt).
    CONFIG(release, debug|release): DSCC_COPY_DEST = $$OUT_PWD/release
    CONFIG(debug,   debug|release): DSCC_COPY_DEST = $$OUT_PWD/debug
    DSCC_BIN_DLLS = $$files($$DSCC_DIR/bin/*.dll)
    for(dllpath, DSCC_BIN_DLLS) {
        dllname = $$basename(dllpath)
        !contains(dllname, Qt6.*) {
            QMAKE_POST_LINK += copy /Y $$shell_quote($$shell_path($$dllpath)) $$shell_quote($$shell_path($$DSCC_COPY_DEST)) >nul &
        }
    }
}

# Default rules for deployment.
# Note: If qtquickcontrols2.pri is not found, comment out the line below
# include(qtquickcontrols2.pri)
