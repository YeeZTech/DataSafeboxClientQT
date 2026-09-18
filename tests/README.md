# Offline regression tests

The Sentry test compiles the production `SentryBridge.cpp` and the actual Qt
message-handler functions extracted from `main.cpp`. It links the real native SDK
with an in-memory transport, a temporary database, a dummy loopback DSN, and no
Crashpad backend. It cannot send events or emails to Sentry. It does not load
`secrets.env` or the application's startup configuration.

From the repository root, regenerate the build-only routing header before each
test build (Python 3; use `python3` instead of `py` outside Windows):

```powershell
py tests/extract-sentry-routing.py build/sentry-bridge-tests/sentry-routing.generated.h
```

Build in an x64 MSVC developer command prompt, adjusting Qt/SDK paths as needed:

```bat
call "D:\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cd build\sentry-bridge-tests
D:\Qt\6.10.2\msvc2022_64\bin\qmake.exe ..\..\tests\sentry-bridge.pro SENTRY_ROOT_DIR=D:/code/vcpkg/installed/x64-windows
D:\Qt\Tools\QtCreator\bin\jom\jom.exe
set "PATH=D:\Qt\6.10.2\msvc2022_64\bin;D:\code\vcpkg\installed\x64-windows\bin;D:\code\vcpkg\installed\x64-windows\tools\sentry-native;%PATH%"
sentry-bridge-test.exe -o results.txt,txt
type results.txt
```

Coverage: diagnostic breadcrumbs/Logs without Issues or synchronous flush;
critical-event tags, fingerprints, details and concurrent deduplication;
recoverable Qt diagnostics and local logging; known pipeline/plugin routing;
pipeline log throttling; fatal-handler flush and delegation; and synthetic
unhandled events bypassing bridge deduplication. Logs are checked after SDK close,
because this SDK batches them independently of `sentry_flush()`.

Limits: calling the fatal handler directly does not exercise Qt termination.
Synthetic unhandled events do not test native crashes, Crashpad minidumps, or
symbolication. The harness does not initialize DSCC, simulate its database, or
load the full application UI. Those paths require integration/manual validation.

The existing login state tests run separately:

```sh
node --test tests/casdoor-webview.test.cjs
```
