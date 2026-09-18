QT += core gui testlib
CONFIG += console testcase c++17 release
CONFIG -= app_bundle debug_and_release
win32: CONFIG -= depend_includepath
TARGET = sentry-bridge-test

isEmpty(SENTRY_ROOT_DIR): SENTRY_ROOT_DIR = $$(SENTRY_ROOT_DIR)
isEmpty(SENTRY_ROOT_DIR): error("Set SENTRY_ROOT_DIR to the sentry-native installation root")
INCLUDEPATH += ../src/services $$SENTRY_ROOT_DIR/include
SOURCES += sentry-bridge.test.cpp ../src/services/SentryBridge.cpp
HEADERS += ../src/services/SentryBridge.h
LIBS += -L$$SENTRY_ROOT_DIR/lib -lsentry
win32: LIBS += -lpsapi
linux: LIBS += -lcurl
