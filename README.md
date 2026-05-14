# 数据安全柜 Qt 客户端

数据安全柜客户端是基于 Qt Quick/QML 构建的跨平台桌面应用，提供安全域、数据安全实例、文件导入导出、加密授权、消息中心、账号状态提醒、版本更新和 Casdoor 登录等客户端能力。

## 技术栈

- Qt 6.7.3
- Qt Quick / QML
- Qt Quick Controls 2
- Qt WebEngine
- qmake
- C++17
- vcpkg
- Sentry Native
- DSCC 动态库

## 目录结构

```text
.
├── src/                    # C++ 应用入口、配置、核心能力和服务桥接
│   ├── main.cpp
│   ├── app/                # 应用级基础设施
│   ├── config/             # 运行时服务配置
│   ├── core/               # 本地路径、文件等核心工具
│   └── services/           # Casdoor、更新、Sentry、DSCC、欠费状态等服务
├── qml/                    # Qt Quick 页面、弹窗、组件和 QML 单例
├── resources/              # Qt 资源清单和平台资源文件
│   └── windows/
├── icons/                  # 应用图标与界面 SVG 图标
├── installer/              # Qt Installer Framework 配置
├── builder/                # 跨平台构建与打包脚本
│   ├── windows/            # Windows 安装包脚本
│   ├── macos/              # macOS 打包脚本、Info.plist 和权限配置
│   └── linux/              # Linux AppImage 脚本和 desktop 文件
├── docs/                   # 构建和维护文档
├── datasafebox-qt-client.pro
└── vcpkg.json
```

## 本地开发

使用 Qt Creator 打开根目录下的 `datasafebox-qt-client.pro`。

主要源码入口：

- C++ 入口：`src/main.cpp`
- QML 入口：`qml/main.qml`
- 应用配置：`src/config/AppConfig.h`
- 资源清单：`resources/resources.qrc`

`resources/resources.qrc` 通过 alias 保持运行时资源路径稳定，应用仍从 `qrc:/main.qml` 加载界面，图标仍通过 `qrc:/icons/...` 或相对 `icons/...` 使用。

## 依赖说明

- Qt：建议使用 Qt 6.7.3，并安装 WebEngine、Quick Controls 2 等桌面组件。
- Sentry Native：通过 vcpkg 安装，qmake 参数或环境变量 `SENTRY_ROOT_DIR` 指向安装目录。
- DSCC：Windows 下通过 `DSCC_DIR` 指向 DSCC SDK/运行时目录。
- Casdoor、后端 API、Soketi、Sentry DSN、官网和客服地址统一在 `src/config/AppConfig.h` 中管理。

更详细的 Windows 本地编译配置见 [docs/INSTALL_GUIDE.md](docs/INSTALL_GUIDE.md)。

## 开源许可

本仓库自有源码以 `LGPL-3.0-or-later` 开源，版权主体为北京熠智科技有限公司。完整授权说明见 [LICENSE](LICENSE)，GNU LGPLv3/GPLv3 正文见 [LICENSES](LICENSES)。

项目基于 Qt Quick/QML 构建。使用和分发 Qt 运行时、QML 模块、插件、Qt WebEngine/Chromium 组件时，应同时遵守 Qt 开源许可和对应第三方组件许可。Sentry Native、DSCC SDK/运行时及其依赖的许可说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。发布安装包时应随附本项目许可文件和第三方声明。

## 构建与打包

- Windows：运行 `builder\windows\build_installer.bat`
- macOS：运行 `builder/macos/build_dmg.sh`
- Linux：运行 `builder/linux/build_appimage.sh`

CI 配置位于 `.github/workflows/build.yml`，会在主分支、PR 和 `v*` 标签上触发多平台构建与发布流程。
