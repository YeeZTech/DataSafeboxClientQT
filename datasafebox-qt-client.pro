QT += quick qml network core svg quickcontrols2 widgets webenginequick

CONFIG += c++17

CONFIG -= qtquickcompiler
win32:CONFIG -= depend_includepath

# Application name
TARGET = DataSafebox

# Version automation: Read version from package.xml as the Single Source of Truth
# Trying to detect OS and use appropriate command
win32 {
    # Windows: Use PowerShell to extract version
    VERSION_FROM_XML = $$system("powershell -NoProfile -Command \"(Select-Xml -Path '$$PWD/installer/packages/com.datasafebox.client/meta/package.xml' -XPath '/Package/Version').Node.InnerText\"")
} else {
    # macOS/Linux: Use sed/grep to extract version
    VERSION_FROM_XML = $$system("grep -oPm1 '(?<=<Version>)[^<]+' $$PWD/installer/packages/com.datasafebox.client/meta/package.xml 2>/dev/null || sed -n 's/.*<Version>\(.*\)<\/Version>.*/\1/p' $$PWD/installer/packages/com.datasafebox.client/meta/package.xml")
}

# Fallback if detection fails
isEmpty(VERSION_FROM_XML) {
    message("Warning: Could not read version from package.xml, falling back to 1.0.0")
    VERSION_FROM_XML = "1.0.0"
}

# Inject into C++ code
DEFINES += APP_VERSION=\\\"$$VERSION_FROM_XML\\\"
message("Building version: $$VERSION_FROM_XML")

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
    src/services/DsccBridge.cpp

HEADERS += \
    src/config/AppConfig.h \
    src/app/SingleApplication.h \
    src/core/PathManager.h \
    src/core/LanguageManager.h \
    src/services/CasdoorHelper.h \
    src/services/UpdateManager.h \
    src/services/SentryBridge.h \
    src/services/ArrearsManager.h \
    src/services/DsccBridge.h

INCLUDEPATH += \
    $$PWD/src/app \
    $$PWD/src/config \
    $$PWD/src/core \
    $$PWD/src/services

# Enable MOC for source files and headers that contain Q_OBJECT classes
CONFIG += automoc

# Qt Linguist — automatically compile .ts → .qm during the build.
# Adding lrelease to CONFIG makes qmake invoke lrelease as a build step.
CONFIG += lrelease
TRANSLATIONS += \
    translations/notification_zh_cn.ts \
    translations/qml_zh_cn.ts

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
# 所有运行时服务配置（URL / 密钥 / DSN）统一在 AppConfig.h 中管理。
# ===========================================================================

# Sentry Native (via vcpkg)
# SENTRY_DSN 已移入 AppConfig.h
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
    SENTRY_RUNTIME_FILES = \
        $$SENTRY_ROOT_DIR/bin/sentry.dll \
        $$SENTRY_ROOT_DIR/bin/zlib1.dll \
        $$SENTRY_ROOT_DIR/tools/sentry-native/crashpad_handler.exe

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
    LIBS += -L"$$DSCC_DIR/lib" -ldscc_common -ldscc_core
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

    LIBS += -L"$$DSCC_DIR/lib" -ldscc_common -ldscc_core
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
    DSCC_COPY_DLLS = \
        dscc_common.dll \
        dscc_core.dll \
        WCDB.dll \
        ff_net.dll \
        boost_filesystem-vc143-mt-x64-1_89.dll \
        boost_program_options-vc143-mt-x64-1_89.dll \
        glog.dll \
        gflags.dll \
        libcrypto-3-x64.dll \
        libsecp256k1-6.dll \
        ycrypto_core.dll \
        ycrypto_stdeth.dll \
        ycrypto_toolkit.dll

    CONFIG(release, debug|release) {
        for(dll, DSCC_COPY_DLLS) {
            QMAKE_POST_LINK += copy /Y $$shell_quote($$shell_path($$DSCC_DIR/bin/$$dll)) $$shell_quote($$shell_path($$OUT_PWD/release)) >nul &
        }
    }
    CONFIG(debug, debug|release) {
        for(dll, DSCC_COPY_DLLS) {
            QMAKE_POST_LINK += copy /Y $$shell_quote($$shell_path($$DSCC_DIR/bin/$$dll)) $$shell_quote($$shell_path($$OUT_PWD/debug)) >nul &
        }
    }
}

# Default rules for deployment.
# Note: If qtquickcontrols2.pri is not found, comment out the line below
# include(qtquickcontrols2.pri)
