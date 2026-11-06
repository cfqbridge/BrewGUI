# BrewGUI 视觉设计资产与选型结论

本文档归档 BrewGUI 界面、图标与 DMG 安装包视觉设计选型结论。

## 1. 应用图标选型 (AppIcon)
- **选定资产**: `ref/icon_option_c.png`
- **设计特征**:
  - 采用 macOS Big Sur / Sonoma 原生圆角矩形曲率规范与微阴影外框；
  - 核心元素为「猫爪 + 啤酒金黄泡沫与清爽气泡」，契合 Homebrew 酿造意象与轻松友好的交互基调；
  - 通过 `scripts/bundle_app.sh` 配合 macOS 原生 `sips` 与 `iconutil` 自动构建输出 16x16 至 1024x1024 全尺寸 `AppIcon.icns`，同时用于 DMG 卷宗图标 `.VolumeIcon.icns`。

## 2. DMG 安装包背景选型 (DMG Background)
- **选定资产**: `ref/dmg_bg_option_c.png`
- **设计特征**:
  - 宽幅尺寸设计，去除了固定版本号文字，作为通用长效背景；
  - 视觉中包含拖拽安装引导（`BrewGUI.app` 图标拖向 `/Applications` 替身），适配浅色与深色视觉；
  - 通过 `scripts/bundle_app.sh` 配合 `sips` 与 `tiffutil -cathidpicheck` 合成 `@1x` (660x420) 与 `@2x` (1320x840) 的 Retina 高清多分辨率 `.background/background.tiff` 隐藏背景。
