# 数据安全柜控制台客户端 — 编译说明

## 环境要求

- Windows 10/11 x64
- Qt 6.7.3（MSVC 2022 64-bit 工具链）
- Visual Studio 2022（含 MSVC 编译器）
- Sentry Native SDK（用于崩溃上报）

---

## 外部依赖库

| qmake 参数 | 说明 | 典型路径示例 |
|-----------|------|------------|
| `SENTRY_ROOT_DIR` | Sentry Native（via vcpkg） | `C:/vcpkg/installed/x64-windows` |

库头文件和 `.lib` 文件需按以下结构存放：

```
<ROOT_DIR>/
  include/   ← 头文件
  lib/       ← .lib 链接库
  bin/       ← .dll 运行时库
```

---

## 在 Qt Creator 中配置编译参数

1. 打开 Qt Creator，加载 `datasafebox-qt-client.pro`
2. 进入 **Projects → Build Settings → Build Steps → qmake**
3. 在 **Additional arguments** 中填入（替换为实际路径）：

```
SENTRY_ROOT_DIR=C:/vcpkg/installed/x64-windows
```

另需在项目根目录准备 `secrets.env`（复制 `.env.example` 填入真实值），缺失时 qmake 会报错。

也可通过系统环境变量设置 `SENTRY_ROOT_DIR`（同名），Qt Creator 重启后自动读取。

---

## 运行时 DLL 配置

应用运行时需要能找到以下 DLL：

- `sentry.dll`（Sentry Native）

**方法：** 在 Qt Creator 中进入 **Projects → Run → Run Environment**，
将 Sentry bin 路径添加到 `PATH` 变量头部：

```
C:/vcpkg/installed/x64-windows/bin
```

（替换为实际路径）

---

## 应用配置

所有运行时服务地址统一在 `src/config/AppConfig.h` 中管理：

- 后端 API 地址
- Casdoor SSO 配置
- Soketi WebSocket 配置
- Sentry DSN
- 官网 / 客服 URL

测试/正式两套配置同时编译进二进制，运行时在登录页右上角的下拉框选择环境（切换后应用自动重启生效），不再需要分环境出包。

---


## 编译步骤

1. 配置好上述 qmake 参数
2. 在 Qt Creator 中选择 `Desktop Qt 6.7.3 MSVC2022 64bit` Kit
3. 点击 **Build** 或按 `Ctrl+B`

---

## 打包安装包

编译完成（Release 模式）后，运行：

```bat
builder\windows\build_installer.bat
```

脚本内开头有两个路径需根据机器情况调整：

```bat
set "QT_BIN=C:\Qt\6.7.3\msvc2022_64\bin"
set "IFW_BIN=C:\Qt\Tools\QtInstallerFramework\4.10\bin"
```
