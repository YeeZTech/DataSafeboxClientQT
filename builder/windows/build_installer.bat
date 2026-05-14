@echo off
setlocal enabledelayedexpansion

rem ===========================================================================
rem build_installer.bat -- Windows one-click build + package script
rem
rem Usage:
rem   builder\windows\build_installer.bat  (from project root)
rem   build_installer.bat          (from this directory)
rem
rem Override any path via environment variable before running:
rem   set QT_VERSION=6.7.3
rem   set QT_BIN=C:\Qt\6.7.3\msvc2022_64\bin
rem   set IFW_BIN=C:\Qt\Tools\QtInstallerFramework\4.10\bin
rem   set VCPKG_DIR=D:\vcpkg
rem   set SENTRY_ROOT_DIR=D:\vcpkg\installed\x64-windows
rem ===========================================================================

rem ------------------------------------------------------------------
rem Configurable paths (env vars take priority over defaults below)
rem ------------------------------------------------------------------
if not defined QT_VERSION  set "QT_VERSION=6.7.3"
if not defined IFW_VERSION set "IFW_VERSION=4.10"

if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    if not defined QT_ARCH       set "QT_ARCH=msvc2022_arm64"
    if not defined VCPKG_TRIPLET set "VCPKG_TRIPLET=arm64-windows"
) else (
    if not defined QT_ARCH       set "QT_ARCH=msvc2022_64"
    if not defined VCPKG_TRIPLET set "VCPKG_TRIPLET=x64-windows"
)

if not defined QT_BIN  set "QT_BIN=C:\Qt\%QT_VERSION%\%QT_ARCH%\bin"
if not defined IFW_BIN set "IFW_BIN=C:\Qt\Tools\QtInstallerFramework\%IFW_VERSION%\bin"

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..\..") do set "PROJECT_ROOT=%%~fi"
set "BUILD_DIR=%PROJECT_ROOT%\release"
set "EXECUTABLE=%BUILD_DIR%\safebox.exe"
set "INSTALLER_DIR=%PROJECT_ROOT%\installer"
set "CONFIG_XML=%INSTALLER_DIR%\config\config.xml"
set "PACKAGES_DIR=%INSTALLER_DIR%\packages"
set "DATA_DIR=%PACKAGES_DIR%\com.datasafebox.client\data"
set "PACKAGE_XML=%PACKAGES_DIR%\com.datasafebox.client\meta\package.xml"
set "ICONS_SRC_DIR=%PROJECT_ROOT%\icons"
set "ICON_SRC=%ICONS_SRC_DIR%\SafeLogo.svg"
set "ICON_SRC_ICO=%ICONS_SRC_DIR%\SafeLogo_256.ico"
set "ICONS_DST=%DATA_DIR%\icons"
set "BINARYCREATOR=%IFW_BIN%\binarycreator.exe"
set "WINDEPLOYQT=%QT_BIN%\windeployqt.exe"
set "QMAKE=%QT_BIN%\qmake.exe"

if not defined VCPKG_DIR       set "VCPKG_DIR=%PROJECT_ROOT%\..\vcpkg"
if not defined SENTRY_ROOT_DIR set "SENTRY_ROOT_DIR=%VCPKG_DIR%\installed\%VCPKG_TRIPLET%"

echo.
echo ==================================================
echo   DatasafeBox Windows Build + Package
echo   Qt      : %QT_BIN%
echo   IFW     : %IFW_BIN%
echo   Sentry  : %SENTRY_ROOT_DIR%
echo   Arch    : %VCPKG_TRIPLET%
echo ==================================================
echo.

rem ==================================================================
rem PRE-FLIGHT CHECK
rem ==================================================================
set "PREFLIGHT_FAIL=0"
echo [CHECK] Scanning build environment...
echo.

call :check_qt
call :check_ifw
call :check_msvc
call :check_sentry
call :check_dscc
call :check_package_xml

if "%PREFLIGHT_FAIL%"=="1" goto :preflight_failed
echo   All checks passed -- starting build.
echo.
goto :start_build

:preflight_failed
echo ==================================================
echo   Environment check FAILED.
echo   Please install the missing tools listed above,
echo   then run this script again.
echo ==================================================
echo.
goto :fail_no_msg

rem ==================================================================
rem BUILD STEPS
rem ==================================================================
:start_build

rem --- read version ---
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Select-Xml -Path '%PACKAGE_XML%' -XPath '/Package/Version').Node.InnerText"`) do set "PACKAGE_VERSION=%%i"
if not defined PACKAGE_VERSION (echo [Error] Failed to read version from package.xml & goto :fail)
set "OUTPUT_INSTALLER=%SCRIPT_DIR%safebox_%PACKAGE_VERSION%.exe"
echo [INFO] Version: %PACKAGE_VERSION%
echo [INFO] Output : %OUTPUT_INSTALLER%
echo.

rem --- Step 1/6: MSVC + compile ---
echo [1/6] Initializing MSVC build environment and compiling...

where nmake >nul 2>&1
if not errorlevel 1 goto :do_compile

set "VCVARS_LOG=%TEMP%\vcvars_%RANDOM%.log"
call "%VS_INSTALL_PATH%\VC\Auxiliary\Build\vcvars64.bat" > "%VCVARS_LOG%" 2>&1
del /Q "%VCVARS_LOG%" 2>nul
@echo off

:do_compile
cd /d "%PROJECT_ROOT%"

if exist "%BUILD_DIR%" rd /s /q "%BUILD_DIR%"
if exist "%PROJECT_ROOT%\resources_qmlcache.qrc" del /Q "%PROJECT_ROOT%\resources_qmlcache.qrc"

if not defined DSCC_DIR set "DSCC_DIR=C:/Program Files/DSCC"
"%QMAKE%" datasafebox-qt-client.pro CONFIG+=release CONFIG-=qtquickcompiler SENTRY_ROOT_DIR="%SENTRY_ROOT_DIR:\=/%" DSCC_DIR="%DSCC_DIR%"
if errorlevel 1 goto :fail
nmake release
if errorlevel 1 goto :fail
if not exist "%EXECUTABLE%" (echo [Error] Build succeeded but exe not found: %EXECUTABLE% & goto :fail)
echo [OK] Compile done

rem --- Step 2/6: sentry runtime ---
echo.
echo [2/6] Checking sentry runtime...
set "SENTRY_DLL=%SENTRY_ROOT_DIR%\bin\sentry.dll"
set "CRASHPAD_EXE=%SENTRY_ROOT_DIR%\tools\sentry-native\crashpad_handler.exe"

call :copy_dep "%SENTRY_DLL%"         "sentry.dll not found - crash reporting disabled"
call :copy_dep "%CRASHPAD_EXE%"       "crashpad_handler.exe not found - crash reporting disabled"
for %%D in (zlib1.dll) do call :copy_dep "%SENTRY_ROOT_DIR%\bin\%%D" "%%D not found - crashpad_handler may fail to start"

rem --- Step 3/6: windeployqt ---
echo.
echo [3/6] Running windeployqt...
"%WINDEPLOYQT%" --qmldir "%PROJECT_ROOT%\qml" "%EXECUTABLE%"
if errorlevel 1 goto :fail

rem --- Step 4/6: installer data dir ---
echo.
echo [4/6] Preparing installer data directory...
rem Preserve vc_redist.x64.exe across DATA_DIR rebuild (it is a static asset
rem committed manually, not produced by the build).
set "VC_REDIST_BACKUP=%TEMP%\vc_redist_%RANDOM%.exe"
if exist "%DATA_DIR%\vc_redist.x64.exe" copy /Y "%DATA_DIR%\vc_redist.x64.exe" "%VC_REDIST_BACKUP%" >nul
if exist "%DATA_DIR%" rd /s /q "%DATA_DIR%"
mkdir "%DATA_DIR%"
if exist "%VC_REDIST_BACKUP%" (
    copy /Y "%VC_REDIST_BACKUP%" "%DATA_DIR%\vc_redist.x64.exe" >nul
    del /Q "%VC_REDIST_BACKUP%" 2>nul
)

robocopy "%BUILD_DIR%" "%DATA_DIR%" /E ^
  /XD qmltooling generic ^
  /XF *.obj *.cpp *.h *.res *.qrc Makefile Makefile.Debug Makefile.Release ^
      qsqlpsql.dll qsqlodbc.dll ^
  >nul
if errorlevel 8 goto :fail

if exist "%DATA_DIR%\translations\qtwebengine_locales" (
    for %%f in ("%DATA_DIR%\translations\qtwebengine_locales\*.pak") do (
        if /I not "%%~nf"=="zh-CN" if /I not "%%~nf"=="en-US" del /Q "%%f"
    )
)
if exist "%DATA_DIR%\translations" (
    for %%f in ("%DATA_DIR%\translations\qt_*.qm") do (
        if /I not "%%~nf"=="qt_zh_CN" del /Q "%%f"
    )
)

rem --- Strip files that are definitively not needed ---
echo [4b] Stripping unnecessary files...

rem WebEngine DevTools pak -- only used when DevTools is explicitly enabled in code.
rem Never needed in production builds (saves ~9 MB).
if exist "%DATA_DIR%\resources\qtwebengine_devtools_resources.pak" del /Q "%DATA_DIR%\resources\qtwebengine_devtools_resources.pak"

rem Qt Quick Controls 2 unused style modules.
rem main.cpp calls QQuickStyle::setStyle("Basic") unconditionally, so Qt will
rem never load any of these. Safe to remove.
if exist "%DATA_DIR%\Qt6QuickControls2Fusion.dll"             del /Q "%DATA_DIR%\Qt6QuickControls2Fusion.dll"
if exist "%DATA_DIR%\Qt6QuickControls2FusionStyleImpl.dll"    del /Q "%DATA_DIR%\Qt6QuickControls2FusionStyleImpl.dll"
if exist "%DATA_DIR%\Qt6QuickControls2Imagine.dll"            del /Q "%DATA_DIR%\Qt6QuickControls2Imagine.dll"
if exist "%DATA_DIR%\Qt6QuickControls2ImagineStyleImpl.dll"   del /Q "%DATA_DIR%\Qt6QuickControls2ImagineStyleImpl.dll"
if exist "%DATA_DIR%\Qt6QuickControls2Material.dll"           del /Q "%DATA_DIR%\Qt6QuickControls2Material.dll"
if exist "%DATA_DIR%\Qt6QuickControls2MaterialStyleImpl.dll"  del /Q "%DATA_DIR%\Qt6QuickControls2MaterialStyleImpl.dll"
if exist "%DATA_DIR%\Qt6QuickControls2Universal.dll"          del /Q "%DATA_DIR%\Qt6QuickControls2Universal.dll"
if exist "%DATA_DIR%\Qt6QuickControls2UniversalStyleImpl.dll" del /Q "%DATA_DIR%\Qt6QuickControls2UniversalStyleImpl.dll"
if exist "%DATA_DIR%\Qt6QuickControls2WindowsStyleImpl.dll"   del /Q "%DATA_DIR%\Qt6QuickControls2WindowsStyleImpl.dll"
if exist "%DATA_DIR%\qml\QtQuick\Controls\Fusion"    rd /s /q "%DATA_DIR%\qml\QtQuick\Controls\Fusion"
if exist "%DATA_DIR%\qml\QtQuick\Controls\Imagine"   rd /s /q "%DATA_DIR%\qml\QtQuick\Controls\Imagine"
if exist "%DATA_DIR%\qml\QtQuick\Controls\Material"  rd /s /q "%DATA_DIR%\qml\QtQuick\Controls\Material"
if exist "%DATA_DIR%\qml\QtQuick\Controls\Universal" rd /s /q "%DATA_DIR%\qml\QtQuick\Controls\Universal"
if exist "%DATA_DIR%\qml\QtQuick\Controls\Windows"   rd /s /q "%DATA_DIR%\qml\QtQuick\Controls\Windows"
if exist "%DATA_DIR%\qml\QtQuick\NativeStyle"        rd /s /q "%DATA_DIR%\qml\QtQuick\NativeStyle"

rem Serial port -- no serial port code anywhere in the project.
if exist "%DATA_DIR%\Qt6SerialPort.dll" del /Q "%DATA_DIR%\Qt6SerialPort.dll"

rem Mimer SQL driver -- project only uses SQLite.
if exist "%DATA_DIR%\sqldrivers\qsqlmimer.dll" del /Q "%DATA_DIR%\sqldrivers\qsqlmimer.dll"

rem Obscure image format plugins not used by the app or WebEngine.
if exist "%DATA_DIR%\imageformats\qicns.dll" del /Q "%DATA_DIR%\imageformats\qicns.dll"
if exist "%DATA_DIR%\imageformats\qwbmp.dll" del /Q "%DATA_DIR%\imageformats\qwbmp.dll"
if exist "%DATA_DIR%\imageformats\qtga.dll"  del /Q "%DATA_DIR%\imageformats\qtga.dll"

echo [OK] Strip done

rem NOTE: The following files are kept intentionally even though windeployqt
rem included them conservatively. Remove only after confirming they are truly
rem unused in your deployment environment:
rem   opengl32sw.dll          -- needed for VMs / Remote Desktop / no-GPU machines
rem   Qt6Pdf.dll              -- WebEngine may reference it for in-browser PDF
rem   Qt6Positioning.dll      -- WebEngine Geolocation API dependency
rem   Qt6VirtualKeyboard.dll  -- kept (windeployqt determined it may be needed)
rem   dxcompiler.dll, dxil.dll -- required by Qt RHI D3D12 backend

rem --- Step 5/6: icons ---
echo.
echo [5/6] Configuring additional files...

if exist "%ICON_SRC%" (
    if not exist "%ICONS_DST%" mkdir "%ICONS_DST%"
    copy /Y "%ICON_SRC%" "%ICONS_DST%\" >nul
)
if exist "%ICON_SRC_ICO%" (
    if not exist "%ICONS_DST%" mkdir "%ICONS_DST%"
    copy /Y "%ICON_SRC_ICO%" "%ICONS_DST%\" >nul
)

rem --- Step 6/6: build installer ---
echo.
echo [6/6] Building installer package...
pushd "%PROJECT_ROOT%"
"%BINARYCREATOR%" -c "%CONFIG_XML%" -p "%PACKAGES_DIR%" "%OUTPUT_INSTALLER%"
set "BC_ERROR=%errorlevel%"
popd
if not "%BC_ERROR%"=="0" goto :fail

echo.
echo ==================================================
echo   Build complete!
echo   Output: %OUTPUT_INSTALLER%
echo ==================================================
echo.
pause
exit /b 0

:fail
echo.
echo [Error] Build failed. See messages above.
echo.
:fail_no_msg
pause
exit /b 1

rem ==================================================================
rem SUBROUTINES
rem ==================================================================

rem :copy_dep <src_path> <warning_msg>
rem   Copies a file to BUILD_DIR if it exists; warns otherwise.
:copy_dep
set "_src=%~1"
set "_warn=%~2"
for %%F in ("%_src%") do set "_fname=%%~nxF"
if exist "%_src%" (
    copy /Y "%_src%" "%BUILD_DIR%\" >nul
    echo [OK] %_fname% copied from vcpkg
) else if not exist "%BUILD_DIR%\%_fname%" (
    echo [Warning] %_warn%
) else (
    echo [OK] %_fname% already in release/
)
exit /b 0

rem ==================================================================
rem SUBROUTINES -- pre-flight checks
rem ==================================================================

:check_qt
if exist "%QMAKE%" (
    echo   [OK]      Qt %QT_VERSION% found
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] Qt %QT_VERSION% ^(%QT_ARCH%^)
    echo             Expected : %QMAKE%
    echo             Fix:
    echo               Download Qt Online Installer:
    echo               https://www.qt.io/download-qt-installer
    echo               Select: Qt - Qt %QT_VERSION% - MSVC 2022 64-bit
    echo               Or set env var:  set QT_BIN=C:\Qt\%QT_VERSION%\msvc2022_64\bin
    echo.
)
if exist "%WINDEPLOYQT%" (
    echo   [OK]      windeployqt found
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] windeployqt.exe
    echo             Expected : %WINDEPLOYQT%
    echo             Fix: Same Qt installation includes windeployqt.
    echo.
)
exit /b 0

:check_ifw
if exist "%BINARYCREATOR%" (
    echo   [OK]      Qt Installer Framework %IFW_VERSION% found
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] Qt Installer Framework %IFW_VERSION%
    echo             Expected : %BINARYCREATOR%
    echo             Fix:
    echo               In Qt Online Installer, select:
    echo               Qt - Developer and Designer Tools -
    echo                 Qt Installer Framework %IFW_VERSION%
    echo               Or set env var:  set IFW_BIN=C:\Qt\Tools\QtInstallerFramework\%IFW_VERSION%\bin
    echo.
)
exit /b 0

:check_msvc
where nmake >nul 2>&1
if not errorlevel 1 (echo   [OK]      MSVC nmake already in PATH & exit /b 0)
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "!VSWHERE!" goto :check_msvc_scan
set "PREFLIGHT_FAIL=1"
echo   [MISSING] Visual Studio 2022 with C++ workload
echo             Fix:
echo               1. Download Visual Studio 2022 Community at:
echo                  https://visualstudio.microsoft.com/vs/
echo               2. In the installer select workload:
echo                  Desktop development with C++
echo               Or run this script from the VS 2022 x64 Native Tools prompt
echo.
exit /b 0
:check_msvc_scan
for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL_PATH=%%i"
if defined VS_INSTALL_PATH goto :check_msvc_ok
set "PREFLIGHT_FAIL=1"
echo   [MISSING] MSVC C++ compiler tools
echo             Visual Studio found but C++ workload is missing.
echo             Fix: Open Visual Studio Installer - Modify - add:
echo             Desktop development with C++
echo.
exit /b 0
:check_msvc_ok
echo   [OK]      Visual Studio found at: !VS_INSTALL_PATH!
exit /b 0

:check_sentry
set "SENTRY_H=%SENTRY_ROOT_DIR%\include\sentry.h"
if exist "%SENTRY_H%" goto :check_sentry_found
set "PREFLIGHT_FAIL=1"
echo   [MISSING] sentry-native via vcpkg
echo             Expected : %SENTRY_H%
echo             Fix:
echo               1. Clone vcpkg:
echo                  git clone https://github.com/microsoft/vcpkg.git ..\vcpkg
echo                  ..\vcpkg\bootstrap-vcpkg.bat -disableMetrics
echo               2. Install sentry-native:
echo                  vcpkg install sentry-native --triplet %VCPKG_TRIPLET%
echo               Or set env var: set SENTRY_ROOT_DIR=D:\vcpkg\installed\%VCPKG_TRIPLET%
echo.
exit /b 0
:check_sentry_found
echo   [OK]      sentry-native found
if not exist "%SENTRY_ROOT_DIR%\bin\sentry.dll" (
    echo   [WARN]    sentry.dll missing - crash reporting will be disabled
    echo             Fix: vcpkg install sentry-native --triplet %VCPKG_TRIPLET%
    echo.
) else (
    echo   [OK]      sentry.dll found
)
if not exist "%SENTRY_ROOT_DIR%\tools\sentry-native\crashpad_handler.exe" (
    echo   [WARN]    crashpad_handler.exe missing - crash reporting will be disabled
    echo.
) else (
    echo   [OK]      crashpad_handler.exe found
)
exit /b 0

:check_dscc
if not defined DSCC_DIR set "DSCC_DIR=C:\Program Files\DSCC"
if exist "%DSCC_DIR%\bin\dscc_core.dll" (
    echo   [OK]      DSCC found at %DSCC_DIR%
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] DSCC runtime library
    echo             Expected : %DSCC_DIR%\bin\dscc_core.dll
    echo             Fix: Install DSCC to default path or set env var:
    echo               set DSCC_DIR=C:\Program Files\DSCC
    echo.
)
if exist "%DATA_DIR%\..\vc_redist.x64.exe" (
    echo   [OK]      vc_redist.x64.exe found in installer data
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] vc_redist.x64.exe in installer data dir
    echo             Expected : %PACKAGES_DIR%\com.datasafebox.client\data\vc_redist.x64.exe
    echo             Fix: Download VC++ 2015-2022 x64 Runtime and place it there:
    echo               https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo             Without it, target machines lacking VC++ Runtime will fail to start.
    echo.
)
exit /b 0

:check_package_xml
if exist "%PACKAGE_XML%" (
    echo   [OK]      package.xml found
) else (
    set "PREFLIGHT_FAIL=1"
    echo   [MISSING] %PACKAGE_XML%
    echo             This file is required for version and installer metadata.
    echo             Ensure you have the full project source checked out.
    echo.
)
exit /b 0
