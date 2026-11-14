# BrewGUI

<p align="center">
  <img src="ref/icon_option_c.png" alt="BrewGUI Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>专为 macOS 设计的极简、轻量、高可控 Homebrew 原生图形客户端</strong>
</p>

<p align="center">
  <b>简体中文</b> · <a href="README_EN.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/cfqbridge/BrewGUI/releases"><img src="https://img.shields.io/badge/Release-v2.3.261114-blue.svg" alt="Release Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon-black.svg" alt="Platform"></a>
  <a href="#"><img src="https://img.shields.io/badge/Swift-6.0%20%7C%20Native%20AppKit%20%2B%20SwiftUI-orange.svg" alt="Swift"></a>
  <a href="#"><img src="https://img.shields.io/badge/i18n-简体中文%20%7C%20繁體中文%20%7C%20English-teal.svg" alt="i18n"></a>
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

### 2. 🔍 中文场景搜索与本机应用智能接管 (Adopt)
- **内置中文别名与 11 大场景分类检索**：内置 170+ 主流 Mac 软件中文名/简介词典与全量英文 `desc` 自动中文功能标签映射，支持直接输入“截图”、“解压”、“播放器”、“翻译”、“终端”毫秒级检索（预计算索引特征与 $O(1)$ 状态字典映射，打字检索耗时 `< 1ms`），并提供「🔥 装机必备」、「📸 截图/录屏」、「📦 解压/归档」、「🎬 影音播放」、「🤖 AI 工具」等一键分类筛选。
- **第三方 Tap 仓库自动索引**：自动扫描本机已添加的第三方 Tap（`/opt/homebrew/Library/Taps/...`）中的 Formula 与 Cask（如 `chen08209/tap/flclash`）并入全量搜索与批量安装索引，增删 Tap 后自动重建缓存。
- **已禁用 / 已弃用包智能识别与引导**：自动解析全量索引中的 `disable_args` 与 `deprecate_args`（如未通过 macOS Gatekeeper 公证或上游停更的软件包），醒目标注红色「已禁用」/ 黄色「已弃用」标签及可读原因，拦截无效报错安装并直接引导官网下载或官方替代包。
- **本机应用接管图文避坑指南与 4 类风险识别**：自动扫描 `/Applications`，智能识别并标记 **App Store 渠道应用**、**生产力/老插件版本敏感应用**、**厂商内建更新更快的国内应用** 及 **同名撞库版本异常应用**，支持一键忽略全部不推荐项。
- **版本比对与一键升级覆盖**：当本地应用版本落后于 Cask 最新版时，支持一键 `brew install --cask --force` 覆盖升级，彻底解决旧版残留与认领脱节问题。

### 3. 📦 已安装包管理与真实版本校验
- **多维度版本透视与贪婪更新 (`--greedy`)**：直观展示顶层安装包 (`leaves`)、全量依赖树、版本锁定状态 (`pin/unpin`)；内置 `含自更新 (--greedy)` 开关，支持一键检测并升级带 `auto_updates true` 或 `:latest` 的桌面软件（自动过滤已从 `/Applications` 删除的孤儿记录与本机已自更新到最新版的软件）。
- **真实磁盘版本校验**：自动校验本地应用 `Info.plist` 真实版本与 Homebrew 账面记录，杜绝“账面已更新、磁盘仍是旧版本”。
- **单应用一键解除隔离拦截**：已安装 Cask 行内置盾牌按钮（`xattr -dr com.apple.quarantine`），一键修复开源软件或第三方 Tap 应用双击报“已损坏 / 无法验证开发者”的 Gatekeeper 拦截弹窗。
- **容错彻底卸载 (`--zap`)**：Cask 卸载支持普通卸载与 `--zap` 深度清理；当 `--zap` 遇到 macOS 完全磁盘访问权限受限路径（如 `sharedfilelist`）中断时，自动回退执行强制卸载清除 Caskroom 备份并安全清理其余用户目录残留，杜绝半卸载死锁。

### 4. 🧹 四合一进阶清理与系统维护 (Cache / `:zap` Leftovers / Services / Doctor)
- **缓存文件与孤儿依赖清理**：直观展示 `~/Library/Caches/Homebrew/downloads` 缓存占用明细、一键 `brew cleanup --prune=all` 与 `brew autoremove` 孤儿依赖清理。
- **已卸载软件残留深度清理 (`:zap` Leftovers)**：交叉比对 Homebrew Cask `:zap` 规则与本机 `/Applications` `CFBundleIdentifier`，精准揪出早已拖入废纸篓但遗留在 `~/Library` 下的孤儿配置与缓存目录，支持一键安全移至废纸篓。
- **后台守护服务管理 (`brew services`)**：可视化查看、启动、停止、重启 MySQL、Redis、PostgreSQL、Nginx、Ollama 等后台服务并定位 `launchd` plist。
- **环境健康体检与 Tap 源管理 (`brew doctor` & `brew tap`)**：图形化一键运行 `brew doctor` 诊断潜在冲突，支持第三方软件源 (`user/repo`) 可视化添加与移除（支持粘贴 `brew tap` 整行命令或 GitHub 链接自动清洗）。

### 5. ⚡️ 批量安装、标准 `Brewfile` 与环境快速迁移
- **自由粘贴与 `Brewfile` 导入解析**：支持直接粘贴长串包名、`brew install` 脚本或导入标准 `Brewfile`，实时解析 `tap` / `brew` / `cask` 状态并提供缺失第三方 Tap 一键补齐。
- **下载体积并发预检**：支持异步并发探测待安装包体积，支持大包提醒与轻量包（`<100MB`）优先安装。
- **混合安装编排**：Formula 自动合并单条命令一次性解析公共依赖，Cask 逐个独立入队下载安装，互不阻塞，支持随时单包跳过。
- **双模式导出本机环境（CLI 指令 & 标准 `Brewfile`）**：支持一键将当前机器所有顶层包导出为命令行脚本或保存为标准 `Brewfile` 文件，换机恢复一键搞定。

### 6. 📊 实时下载监控与任务管控
- **透明进度监控**：突破非 TTY 管道限制，实时监控底层下载流量增长，直观呈现文件名、下载百分比与实时网速（KB/s、MB/s）。
- **任务灵活控制**：支持「停止全部」、「跳过当前包 (Skip)」以及失败单项「一键重试」。

### 7. 🌐 多语言国际化与应用内免拦截自更新 (v1.6)
- **三语实时热切换**：原生内置 **简体中文 (`zh-Hans`) / 繁體中文 (`zh-Hant`) / English (`en`)**，默认智能跟随 macOS 系统语言，支持在主窗口侧边栏底部或菜单栏面板一键切换、零延迟生效（无需重启应用）。
- **应用内 SHA256 校验与一键热更新**：自动比对 GitHub Releases 最新 `version.json`（自带国内加速镜像自动回退），发现新版时一键后台下载 DMG、严格校验 SHA256、静默挂载覆盖并自动清除隔离属性 (`xattr -cr`)，告别手动打开网页与 Gatekeeper 重复弹窗。

---

## 💻 系统要求

- **操作系统**: macOS 14.0 (Sonoma) 或更高版本
- **硬件架构**: Apple Silicon (M1/M2/M3/M4 系列芯片)
- **依赖环境**: 系统已安装 [Homebrew](https://brew.sh/)（核心命令行工具：[Homebrew/brew](https://github.com/Homebrew/brew)，软件源仓库：[homebrew-core](https://github.com/Homebrew/homebrew-core) 与 [homebrew-cask](https://github.com/Homebrew/homebrew-cask)；默认路径 `/opt/homebrew`；若未安装，BrewGUI 内置免终端图形化一键安装向导，支持中科大/清华国内加速源自动部署）

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
├── readme.md                   # 中文项目文档（默认）
├── README_EN.md                # 英文项目文档 (English Documentation)
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
    ├── dmg_bg_option_c.png     # DMG 视网膜安装背景图
    └── dmg_DS_Store            # DMG 窗口布局与背景绑定模板 (供 GitHub Actions 使用)
```

---

## 🔗 关联项目与致谢

BrewGUI 是构建在庞大而优秀的 Homebrew 生态之上的图形客户端工具。由衷感谢 Homebrew 维护团队与全球开源贡献者的持续付出：

- **官方网站**: [https://brew.sh/](https://brew.sh/)
- **Homebrew Core CLI 源码**: [Homebrew/brew](https://github.com/Homebrew/brew) — macOS（及 Linux）不可或缺的包管理器核心命令行工具。
- **Homebrew Formulae 核心软件仓库**: [Homebrew/homebrew-core](https://github.com/Homebrew/homebrew-core) — 汇集上万个开源命令行工具与依赖库。
- **Homebrew Casks 桌面应用仓库**: [Homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask) — 汇集数千款主流 macOS 桌面应用程序。

---

## 📄 开源许可与使用须知

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 许可协议开源。

### 商业限制补充说明
- 本项目严禁任何个人或组织在未经原作者书面授权的情况下，将本软件或其衍生版本闭源打包、上架商业应用商店、进行付费售卖或植入商业广告牟利。
- 欢迎个人免费使用、参与功能开发与提交 Pull Request。
