# BrewGUI

<p align="center">
  <img src="ref/icon_option_c.png" alt="BrewGUI Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>专为 macOS 设计的极简、轻量、高可控 Homebrew 原生图形客户端</strong>
</p>

<p align="center">
  <a href="https://github.com/cfqbridge/BrewGUI/releases"><img src="https://img.shields.io/badge/Release-v1.5.261105-blue.svg" alt="Release Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon-black.svg" alt="Platform"></a>
  <a href="#"><img src="https://img.shields.io/badge/Swift-6.0%20%7C%20Native%20AppKit%20%2B%20SwiftUI-orange.svg" alt="Swift"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-green.svg" alt="License"></a>
</p>

---

## 🌟 为什么选择 BrewGUI？

Homebrew 是 macOS 上无可替代的包管理神器，但在日常使用中经常让人困扰：
- 命令行升级应用毫无进度反馈，几十上百兆的安装包常常让人怀疑是否“假死”？
- 本地历史遗留了大量重复应用，与 Homebrew Cask 账面割裂，甚至版本严重脱节？
- 磁盘空间动辄告急，几十 GB 的下载缓存与孤儿依赖深藏在系统深处难于清理？
- 批量换机或重装系统时，命令一条条敲繁琐且耗时？

**BrewGUI** 专为解决这些痛点而生。基于原生 Swift 6 + SwiftUI + AppKit 开发，不依赖 Electron，极轻量、毫秒级响应，在提供直观图形化体验的同时，严谨保留 Homebrew 纯正原生逻辑。

---

## ✨ 核心特性

### 1. 🪟 原生双交互形态（桌面主窗口 + 菜单栏常驻）
- **左键直达，右键面板**：单击顶部菜单栏图标即刻唤醒主窗口；右键单击呼出自适应高度的快捷面板，一览待更新列表与一键静默更新。
- **开机静默常驻**：支持开机静默驻留菜单栏（主窗口关闭时自动隐藏 Dock 图标，内存占用极低）。
- **后台自动巡检**：支持 12 小时 / 72 小时周期后台自动检查更新，新版提示红点轻量提醒，绝不打扰工作流。

### 2. 🔍 智能搜索与本机应用接管 (Adopt)
- **毫秒级全量检索**：深度整合 Formula 命令行工具与 Cask 图形应用索引。
- **智能识别本土已装应用**：自动扫描 `/Applications`，智能识别 App Store 渠道与 iOS 包装应用。
- **版本比对与一键升级覆盖**：当本地应用版本落后于 Cask 最新版时，支持一键 `brew reinstall --cask --force` 覆盖升级，彻底解决旧版残留与认领脱节问题。

### 3. 📦 已安装包管理与真实版本校验
- **多维度版本透视**：直观展示顶层安装包 (`leaves`)、全量依赖树、版本锁定状态 (`pin/unpin`)。
- **真实磁盘版本校验**：自动校验本地应用 `Info.plist` 真实版本与 Homebrew 账面记录，杜绝“账面已更新、磁盘仍是旧版本”。
- **安全彻底卸载**：Cask 应用卸载支持普通卸载与 `--zap`（一键同步清理缓存与配置残留）。

### 4. 🧹 清理与维护 (Cleanup & Autoremove)
- **缓存文件深度透视**：直观展示 `~/Library/Caches/Homebrew/downloads` 缓存占用明细与单个安装包删除。
- **孤儿依赖清理 (`autoremove`)**：自动探测并一键清除不再被任何软件依赖的冗余包。
- **一键瘦身**：一键调用 `brew cleanup --prune=all`，瞬间释放数 GB 至数十 GB 磁盘空间。

### 5. ⚡️ 批量安装与环境快速迁移
- **自由粘贴解析**：支持直接粘贴长串包名或整段 `brew install` 脚本，实时解析状态。
- **下载体积并发预检**：支持异步并发探测待安装包体积，支持大包提醒与轻量包（`<100MB`）优先安装。
- **混合安装编排**：Formula 自动合并单条命令一次性解析公共依赖，Cask 逐个独立入队下载安装，互不阻塞，支持随时单包跳过。
- **一键导出本机环境**：支持一键将当前机器所有顶层包导出为命令清单，换机恢复一键搞定。

### 6. 📊 实时下载监控与任务管控
- **透明进度监控**：突破非 TTY 管道限制，实时监控底层下载流量增长，直观呈现文件名、下载百分比与实时网速（KB/s、MB/s）。
- **任务灵活控制**：支持「停止全部」、「跳过当前包 (Skip)」以及失败单项「一键重试」。

---

## 💻 系统要求

- **操作系统**: macOS 14.0 (Sonoma) 或更高版本
- **硬件架构**: Apple Silicon (M1/M2/M3/M4 系列芯片)
- **依赖环境**: 系统已安装 [Homebrew](https://brew.sh/)（默认路径 `/opt/homebrew`）

---

## 🚀 下载与安装

### 方式一：下载 DMG 安装包（推荐）
1. 前往 [Releases 页面](https://github.com/cfqbridge/BrewGUI/releases) 下载最新的 `BrewGUI.dmg`。
2. 双击打开 DMG，将 `BrewGUI.app` 拖入 `Applications` 文件夹。
3. 首次启动时：
   - 若系统弹出安全拦截提示（未通过开发者证书公证），请在「系统设置」->「隐私与安全性」中点击「仍要打开」；
   - 启动后若弹出「App 管理」权限申请，请点击允许，以便 BrewGUI 能够正常帮您管理 `/Applications` 下的第三方应用。

### 方式二：从源码编译构建
本机只需安装 macOS Command Line Tools，无需庞大的完整 Xcode：

```zsh
# 1. 克隆代码仓库
git clone https://github.com/cfqbridge/BrewGUI.git
cd BrewGUI

# 2. 编译并组装 .app 与 .dmg
./scripts/bundle_app.sh

# 3. 启动应用
open dist/BrewGUI.app
```

---

## 🛠️ 项目工程结构

```text
├── Package.swift               # SPM 项目定义
├── Sources/
│   ├── App/                    # 应用入口、菜单栏控制器与窗口策略
│   ├── Models/                 # 数据结构定义 (Entry, Task, CacheItem 等)
│   ├── Services/               # Homebrew 交互、目录扫描与网络探测服务
│   ├── Store/                  # 响应式中心状态机 (@MainActor BrewStore)
│   └── Views/                  # 原生 SwiftUI 视图组件
├── scripts/
│   └── bundle_app.sh           # 自动化编译、签名与 DMG 封装脚本
└── ref/
    ├── DESIGN_SUMMARY.md       # 视觉选型与设计归档说明
    ├── icon_option_c.png       # 应用高清原生图标源文件
    └── dmg_bg_option_c.png     # DMG 视网膜安装背景图
```

---

## 📄 开源许可与使用须知

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 许可协议开源。

### 商业限制补充说明
- 本项目严禁任何个人或组织在未经原作者书面授权的情况下，将本软件或其衍生版本闭源打包、上架商业应用商店、进行付费售卖或植入商业广告牟利。
- 欢迎个人免费使用、参与功能开发与提交 Pull Request。
