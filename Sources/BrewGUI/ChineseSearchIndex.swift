import Foundation

public enum SearchCategoryPreset: String, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case essentials = "essentials"
    case screenshot = "screenshot"
    case archive = "archive"
    case media = "media"
    case translate = "translate"
    case productivity = "productivity"
    case dev = "dev"
    case ai = "ai"
    case network = "network"
    case cleanup = "cleanup"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: return tr("全部推荐", "全部推薦", "All")
        case .essentials: return tr("🔥 装机必备", "🔥 裝機必備", "🔥 Essentials")
        case .screenshot: return tr("📸 截图/录屏", "📸 截圖/錄影", "📸 Screenshot")
        case .archive: return tr("📦 解压/归档", "📦 解壓/歸檔", "📦 Archive")
        case .media: return tr("🎬 影音播放", "🎬 影音播放", "🎬 Media")
        case .translate: return tr("🌐 翻译/词典", "🌐 翻譯/詞典", "🌐 Translate")
        case .productivity: return tr("⚡️ 窗口/效率", "⚡️ 視窗/效率", "⚡️ Productivity")
        case .dev: return tr("💻 开发/终端", "💻 開發/終端", "💻 Dev & CLI")
        case .ai: return tr("🤖 AI 工具", "🤖 AI 工具", "🤖 AI Tools")
        case .network: return tr("🚀 网络/代理", "🚀 網路/代理", "🚀 Network")
        case .cleanup: return tr("🧹 清理/系统", "🧹 清理/系統", "🧹 System & Clean")
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "sparkles"
        case .essentials: return "flame.fill"
        case .screenshot: return "camera.viewfinder"
        case .archive: return "archivebox.fill"
        case .media: return "play.tv.fill"
        case .translate: return "character.book.closed.fill"
        case .productivity: return "macwindow.on.rectangle"
        case .dev: return "terminal.fill"
        case .ai: return "brain.head.profile"
        case .network: return "network"
        case .cleanup: return "paintbrush.pointed.fill"
        }
    }
}

public struct ChinesePackageMeta: Sendable {
    public let zhName: String
    public let zhDesc: String
    public let keywords: String
    public let categories: Set<SearchCategoryPreset>

    public init(
        zhName: String,
        zhDesc: String,
        keywords: String,
        categories: Set<SearchCategoryPreset> = []
    ) {
        self.zhName = zhName
        self.zhDesc = zhDesc
        self.keywords = keywords
        self.categories = categories
    }
}

public enum ChineseSearchIndex {
    /// Curated dictionary of mainstream macOS Casks & Formulae with Chinese names, descriptions, and category presets
    public static let curated: [String: ChinesePackageMeta] = [
        // MARK: - 截图 / 贴图 / 录屏 (Screenshot & Recording)
        "snipaste": .init(
            zhName: "Snipaste 截图贴图",
            zhDesc: "极简高效的截图、悬浮贴图与取色标注工具",
            keywords: "截图 贴图 截屏 取色 标注 悬浮窗 screenshot pin",
            categories: [.essentials, .screenshot]
        ),
        "shottr": .init(
            zhName: "Shottr 滚动截图",
            zhDesc: "专为 macOS 原生打造的高性能长截图、像素测量与打码工具",
            keywords: "截图 长截图 滚动截图 打码 测量 OCR 截屏 screenshot",
            categories: [.essentials, .screenshot]
        ),
        "pixpin": .init(
            zhName: "PixPin 长截图贴图",
            zhDesc: "集成了长截图、GIF 录屏、OCR 文字识别与贴图的全能截图工具",
            keywords: "截图 长截图 贴图 录屏 OCR 动图 gif screenshot",
            categories: [.screenshot]
        ),
        "flameshot": .init(
            zhName: "Flameshot 开源截图",
            zhDesc: "功能强大的跨平台开源截图与即时标注软件",
            keywords: "截图 开源 截屏 标注 screenshot",
            categories: [.screenshot]
        ),
        "cleanshot": .init(
            zhName: "CleanShot X 截图录屏",
            zhDesc: "macOS 旗舰级截图、滚动长图、背景美化与屏幕录制套件",
            keywords: "截图 录屏 长截图 美化 标注 screenshot screen recorder",
            categories: [.screenshot]
        ),
        "obs": .init(
            zhName: "OBS Studio 录屏直播",
            zhDesc: "开源专业的屏幕录制与高清视频直播推流软件",
            keywords: "录屏 直播 推流 录像 视频录制 screen record stream",
            categories: [.screenshot, .media]
        ),
        "kap": .init(
            zhName: "Kap 开源录屏转 GIF",
            zhDesc: "开源轻量的 macOS 屏幕录制工具，支持导出 GIF/MP4/WebM",
            keywords: "录屏 动图 gif 屏幕录制 screen recorder",
            categories: [.screenshot]
        ),

        // MARK: - 解压 / 归档 (Archive & Compression)
        "maczip": .init(
            zhName: "MacZip (eZip) 解压缩",
            zhDesc: "专为 Mac 设计的免费清爽压缩包预览与解压工具，完美解决中文乱码",
            keywords: "解压 压缩 zip rar 7z 归档 ezip archive",
            categories: [.essentials, .archive]
        ),
        "keka": .init(
            zhName: "Keka 解压缩工具",
            zhDesc: "macOS 老牌全能文件压缩与分卷解压神器，支持 7z/ZIP/RAR/TAR",
            keywords: "解压 压缩 分卷 7z zip rar tar archive",
            categories: [.essentials, .archive]
        ),
        "the-unarchiver": .init(
            zhName: "The Unarchiver 解压",
            zhDesc: "轻量快速的免费多格式归档解压工具，自动识别文件名编码",
            keywords: "解压 压缩包 rar zip 7z unarchiver archive",
            categories: [.archive]
        ),
        "betterzip": .init(
            zhName: "BetterZip 归档管理",
            zhDesc: "支持免解压直接预览和编辑压缩包内部文件的专业归档工具",
            keywords: "解压 压缩 预览 编辑 zip rar 7z archive",
            categories: [.archive]
        ),
        "peazip": .init(
            zhName: "PeaZip 开源解压",
            zhDesc: "免费开源的跨平台文件归档与加密压缩管理器",
            keywords: "解压 压缩 开源 7z zip rar archive",
            categories: [.archive]
        ),
        "sevenzip": .init(
            zhName: "7-Zip 命令行解压",
            zhDesc: "官方 7-Zip 高压缩比命令行归档工具 (7zz)",
            keywords: "解压 压缩 7z zip rar 命令行 archive",
            categories: [.archive, .dev]
        ),
        "p7zip": .init(
            zhName: "p7zip 命令行解压",
            zhDesc: "7-Zip 命令行工具集 POSIX 移植版",
            keywords: "解压 压缩 7z 命令行 archive",
            categories: [.archive, .dev]
        ),
        "unar": .init(
            zhName: "unar 命令行解压",
            zhDesc: "The Unarchiver 同源命令行防乱码解压工具",
            keywords: "解压 乱码 rar zip 命令行 archive",
            categories: [.archive, .dev]
        ),

        // MARK: - 影音播放 / 处理 (Media & Video Players)
        "iina": .init(
            zhName: "IINA 视频播放器",
            zhDesc: "基于 mpv 的现代 macOS 原生全能视频播放器，支持 HDR、倍速与在线字幕",
            keywords: "播放器 视频 电影 影音 mp4 mkv 字幕 弹幕 video media player",
            categories: [.essentials, .media]
        ),
        "vlc": .init(
            zhName: "VLC 媒体播放器",
            zhDesc: "开源跨平台老牌全格式多媒体音视频与流媒体播放器",
            keywords: "播放器 视频 音频 流媒体 电影 vlc media video player",
            categories: [.media]
        ),
        "mpv": .init(
            zhName: "mpv 极客播放器",
            zhDesc: "极简高画质开源命令行与脚本化视频播放器",
            keywords: "播放器 视频 影音 极客 mpv video player",
            categories: [.media]
        ),
        "infuse": .init(
            zhName: "Infuse 影视播放器",
            zhDesc: "支持杜比视界、NAS 挂载与海报墙刮削的苹果生态影音中心",
            keywords: "播放器 电影 NAS 海报墙 杜比 影音 video player",
            categories: [.media]
        ),
        "neteasemusic": .init(
            zhName: "网易云音乐",
            zhDesc: "网易云音乐 macOS 桌面客户端",
            keywords: "音乐 听歌 播放器 歌曲 网易云 music audio",
            categories: [.media]
        ),
        "qqmusic": .init(
            zhName: "QQ 音乐",
            zhDesc: "腾讯 QQ 音乐 macOS 桌面客户端",
            keywords: "音乐 听歌 播放器 歌曲 qq音乐 music",
            categories: [.media]
        ),
        "spotify": .init(
            zhName: "Spotify 音乐流媒体",
            zhDesc: "全球主流正版流媒体音乐与播客平台",
            keywords: "音乐 听歌 播客 流媒体 播放器 music podcast",
            categories: [.media]
        ),
        "yesplaymusic": .init(
            zhName: "YesPlayMusic 高颜值云音乐",
            zhDesc: "开源高颜值的第三方网易云音乐桌面播放器",
            keywords: "音乐 网易云 听歌 播放器 开源 music",
            categories: [.media]
        ),
        "bilibili": .init(
            zhName: "哔哩哔哩 (B站)",
            zhDesc: "哔哩哔哩官方 macOS 桌面客户端，支持弹幕视频与番剧观看",
            keywords: "视频 弹幕 B站 哔哩哔哩 番剧 直播 bilibili",
            categories: [.media]
        ),
        "handbrake": .init(
            zhName: "HandBrake 视频压制转码",
            zhDesc: "免费开源的多格式视频压缩与转码工具",
            keywords: "视频转码 视频压缩 格式转换 mp4 mkv video converter",
            categories: [.media]
        ),
        "ffmpeg": .init(
            zhName: "FFmpeg 音视频处理引擎",
            zhDesc: "行业标准的开源音视频录制、转码、剪辑与流媒体命令行瑞士军刀",
            keywords: "视频转码 音频 剪辑 格式转换 合并 提取音频 ffmpeg media",
            categories: [.essentials, .media, .dev]
        ),
        "yt-dlp": .init(
            zhName: "yt-dlp 在线视频下载",
            zhDesc: "支持 YouTube、B站等上千个网站的强力命令行音视频下载器",
            keywords: "视频下载 youtube b站 下载器 音频下载 downloader",
            categories: [.media, .dev]
        ),
        "downie": .init(
            zhName: "Downie 视频下载器",
            zhDesc: "简单易用的 macOS 网页视频一键嗅探与高清下载工具",
            keywords: "视频下载 网页视频 youtube b站 下载器",
            categories: [.media]
        ),
        "audacity": .init(
            zhName: "Audacity 音频剪辑",
            zhDesc: "开源跨平台的多轨音频录制与降噪编辑软件",
            keywords: "音频 录音 剪辑 降噪 声音编辑 audio editor",
            categories: [.media]
        ),

        // MARK: - 翻译 / 词典 / 输入法 (Translation & Dictionary)
        "bob": .init(
            zhName: "Bob 划词截图翻译",
            zhDesc: "macOS 必备的划词翻译、截图 OCR 翻译与多引擎聚合词典工具",
            keywords: "翻译 划词翻译 截图翻译 词典 OCR 查词 translate dictionary",
            categories: [.essentials, .translate]
        ),
        "easydict": .init(
            zhName: "Easydict 开源划词翻译",
            zhDesc: "开源免费的 macOS 划词翻译与 OCR 词典软件，支持大模型与多翻译源",
            keywords: "翻译 划词翻译 词典 开源 OCR 查词 AI翻译 translate dictionary",
            categories: [.essentials, .translate]
        ),
        "pot": .init(
            zhName: "Pot 跨平台划词翻译",
            zhDesc: "开源跨平台的划词翻译与 OCR 识别软件",
            keywords: "翻译 划词翻译 OCR 词典 开源 translate",
            categories: [.translate]
        ),
        "eudic": .init(
            zhName: "欧路词典 (Eudic)",
            zhDesc: "权威专业的英语学习与扩充词库词典软件，支持生词本同步与划词搜索",
            keywords: "词典 翻译 英语 查词 背单词 欧路 dictionary translate",
            categories: [.translate]
        ),
        "youdaodict": .init(
            zhName: "网易有道词典",
            zhDesc: "有道官方多语种词典与全文翻译客户端",
            keywords: "词典 翻译 有道 英语 查词 dictionary translate",
            categories: [.translate]
        ),
        "deepl": .init(
            zhName: "DeepL 翻译器",
            zhDesc: "以准确自然著称的 AI 神经网络多语言翻译客户端",
            keywords: "翻译 英语 外语 AI翻译 deepl translate",
            categories: [.translate]
        ),
        "squirrel": .init(
            zhName: "鼠须管 (Rime 输入法)",
            zhDesc: "中州韵 Rime 开源高定制化 macOS 本地拼音/双拼/五笔输入法引擎",
            keywords: "输入法 拼音 双拼 五笔 鼠须管 rime ime",
            categories: [.translate, .productivity]
        ),
        "input-source-pro": .init(
            zhName: "Input Source Pro 输入法自动切换",
            zhDesc: "根据不同应用或浏览器网站自动切换中英文输入法并提供光标状态提示",
            keywords: "输入法 中英文切换 状态栏 效率 ime input",
            categories: [.translate, .productivity]
        ),

        // MARK: - 窗口管理 / 效率提升 (Window Management & Productivity)
        "rectangle": .init(
            zhName: "Rectangle 窗口分屏管理",
            zhDesc: "macOS 最受欢迎的开源免费快捷键与拖拽窗口分屏排列工具",
            keywords: "分屏 窗口管理 磁吸 快捷键 效率 window manager",
            categories: [.essentials, .productivity]
        ),
        "alt-tab": .init(
            zhName: "AltTab 窗口预览切换",
            zhDesc: "将 Windows 风格的全窗口缩略图实时预览切换带到 macOS",
            keywords: "窗口切换 预览 分屏 快捷键 效率 window switcher",
            categories: [.essentials, .productivity]
        ),
        "raycast": .init(
            zhName: "Raycast 超级启动器",
            zhDesc: "新一代极速启动器，内置剪贴板历史、窗口分屏、计算器与丰富插件生态",
            keywords: "启动器 效率 剪贴板 分屏 搜索 快捷指令 launcher spotlight",
            categories: [.essentials, .productivity]
        ),
        "alfred": .init(
            zhName: "Alfred 经典效率启动器",
            zhDesc: "macOS 传奇级快速启动、文件检索与 Workflow 自动化工具",
            keywords: "启动器 效率 搜索 工作流 剪贴板 launcher workflow",
            categories: [.productivity]
        ),
        "maccy": .init(
            zhName: "Maccy 轻量剪贴板历史",
            zhDesc: "开源、极速、原生纯键盘操作的 macOS 剪贴板历史记录管理器",
            keywords: "剪贴板 粘贴 复制 历史记录 开源 效率 clipboard",
            categories: [.essentials, .productivity]
        ),
        "paste": .init(
            zhName: "Paste 视觉化剪贴板",
            zhDesc: "底部卡片抽屉式设计的精美多端同步剪贴板管理工具",
            keywords: "剪贴板 复制 粘贴 历史记录 效率 clipboard",
            categories: [.productivity]
        ),
        "ice": .init(
            zhName: "Ice 菜单栏图标折叠管理",
            zhDesc: "专为刘海屏 Mac 打造的开源现代菜单栏图标隐藏与整理工具（Bartender 替代品）",
            keywords: "菜单栏 状态栏 刘海屏 图标隐藏 开源 bartender menubar",
            categories: [.essentials, .productivity]
        ),
        "hiddenbar": .init(
            zhName: "Hidden Bar 菜单栏折叠",
            zhDesc: "极简开源的 macOS 顶部菜单栏图标一键折叠隐藏小工具",
            keywords: "菜单栏 状态栏 图标隐藏 折叠 menubar",
            categories: [.productivity]
        ),
        "bartender": .init(
            zhName: "Bartender 菜单栏管家",
            zhDesc: "功能全面的老牌 macOS 菜单栏图标折叠与自动显示控制工具",
            keywords: "菜单栏 状态栏 图标管理 刘海屏 menubar",
            categories: [.productivity]
        ),
        "betterdisplay": .init(
            zhName: "BetterDisplay 显示器 HiDPI 增强",
            zhDesc: "开启外接显示器原生 HiDPI 缩放、硬件亮度/音量调节与虚拟屏幕神器",
            keywords: "显示器 外接屏 HiDPI 亮度 缩放 分辨率 4K 2K monitor display",
            categories: [.essentials, .productivity]
        ),
        "monitorcontrol": .init(
            zhName: "MonitorControl 外接屏幕亮度音量",
            zhDesc: "开源免费使用键盘直接调节外接显示器硬件亮度与音量的菜单栏工具",
            keywords: "显示器 外接屏 亮度 音量 调节 monitor brightness",
            categories: [.productivity]
        ),
        "mos": .init(
            zhName: "Mos 鼠标平滑滚动",
            zhDesc: "让普通外接鼠标在 Mac 上拥有如触控板般顺滑滚动体验并独立设置滚轮方向",
            keywords: "鼠标 滚轮 平滑滚动 翻转方向 外接鼠标 mouse scroll",
            categories: [.essentials, .productivity]
        ),
        "scroll-reverser": .init(
            zhName: "Scroll Reverser 滚动方向独立控制",
            zhDesc: "单独设置触控板与外接鼠标滚轮的自然/传统滚动方向",
            keywords: "鼠标 触控板 滚轮 方向 滚动 scroll mouse",
            categories: [.productivity]
        ),
        "karabiner-elements": .init(
            zhName: "Karabiner-Elements 键盘改键神器",
            zhDesc: "macOS 最强大的底层键盘按键映射与组合键深度定制工具",
            keywords: "键盘 改键 快捷键 映射 外接键盘 keyboard remap",
            categories: [.productivity]
        ),
        "hammerspoon": .init(
            zhName: "Hammerspoon 桌面自动化",
            zhDesc: "使用 Lua 脚本控制窗口、快捷键、Wi-Fi 与系统事件的极客自动化引擎",
            keywords: "自动化 脚本 快捷键 窗口控制 lua automation",
            categories: [.productivity, .dev]
        ),
        "itsycal": .init(
            zhName: "Itsycal 菜单栏小日历",
            zhDesc: "常驻顶部菜单栏的轻量级弹出月历与日程速览工具",
            keywords: "日历 菜单栏 日期 时间 日程 calendar menubar",
            categories: [.productivity]
        ),
        "caffeine": .init(
            zhName: "Caffeine 防休眠亮屏",
            zhDesc: "一键防止 Mac 进入睡眠或屏幕变暗的菜单栏咖啡杯工具",
            keywords: "防休眠 保持亮屏 不睡眠 咖啡 菜单栏 awake sleep",
            categories: [.productivity]
        ),
        "keepingyouawake": .init(
            zhName: "KeepingYouAwake 防休眠工具",
            zhDesc: "基于系統 caffeinate 的现代开源菜单栏防休眠开关",
            keywords: "防休眠 保持亮屏 不睡眠 菜单栏 awake",
            categories: [.productivity]
        ),
        "localsend": .init(
            zhName: "LocalSend 局域网跨平台互传",
            zhDesc: "开源无广告的局域网极速文件传输工具，打通 Mac、Windows、安卓与 iOS",
            keywords: "文件传输 局域网 隔空投送 互传 安卓 airdrop transfer",
            categories: [.essentials, .productivity, .network]
        ),

        // MARK: - 浏览器 / 办公 / 笔记 / 社交 (Browsers, Office, Notes & IM)
        "google-chrome": .init(
            zhName: "Google Chrome 谷歌浏览器",
            zhDesc: "全球市场占有率最高的极速网页浏览器",
            keywords: "浏览器 谷歌 网页 上网 chrome browser",
            categories: [.essentials]
        ),
        "arc": .init(
            zhName: "Arc 现代创意浏览器",
            zhDesc: "采用侧边垂直标签页、多工作空间与分屏设计的革新性浏览器",
            keywords: "浏览器 侧边栏 网页 效率 arc browser",
            categories: [.productivity]
        ),
        "firefox": .init(
            zhName: "Mozilla Firefox 火狐浏览器",
            zhDesc: "注重隐私保护的开源独立内核网页浏览器",
            keywords: "浏览器 火狐 开源 网页 firefox browser",
            categories: []
        ),
        "microsoft-edge": .init(
            zhName: "Microsoft Edge 微软浏览器",
            zhDesc: "基于 Chromium 内核、支持垂直标签页与跨平台同步的微软浏览器",
            keywords: "浏览器 微软 网页 edge browser",
            categories: []
        ),
        "brave-browser": .init(
            zhName: "Brave 隐私广告拦截浏览器",
            zhDesc: "内置强力广告与追踪器拦截功能的 Chromium 隐私浏览器",
            keywords: "浏览器 广告拦截 隐私 brave browser",
            categories: []
        ),
        "obsidian": .init(
            zhName: "Obsidian 本地双链知识库",
            zhDesc: "基于本地 Markdown 文件的双向链接笔记与个人第二大脑知识管理工具",
            keywords: "笔记 知识库 双链 markdown 文档 写作 note",
            categories: [.essentials, .productivity]
        ),
        "notion": .init(
            zhName: "Notion 全能协作笔记",
            zhDesc: "集文档、知识库、数据库表格与团队项目管理于一体的云端工作台",
            keywords: "笔记 知识库 协作 文档 数据库 notion note",
            categories: [.productivity]
        ),
        "logseq": .init(
            zhName: "Logseq 开源大纲双链笔记",
            zhDesc: "隐私优先的开源本地 Markdown/Org-mode 大纲与双链知识库",
            keywords: "笔记 大纲 双链 知识库 开源 markdown note",
            categories: [.productivity]
        ),
        "typora": .init(
            zhName: "Typora 所见即所得 Markdown",
            zhDesc: "极简优雅的所见即所得 Markdown 文本编辑器与阅读器",
            keywords: "markdown 编辑器 笔记 写作 文档 typora",
            categories: [.productivity]
        ),
        "zotero": .init(
            zhName: "Zotero 学术文献管理",
            zhDesc: "科研必备的开源文献收集、PDF 批注阅读与论文引用管理工具",
            keywords: "文献 论文 学术 PDF 科研 引用笔记 zotero",
            categories: [.productivity]
        ),
        "anki": .init(
            zhName: "Anki 记忆卡片背诵",
            zhDesc: "基于间隔重复算法的开源高效记忆闪卡软件（背单词/考证神器）",
            keywords: "背单词 记忆卡 闪卡 复习 学习 考试 anki",
            categories: [.productivity, .translate]
        ),
        "calibre": .init(
            zhName: "Calibre 电子书管理转换",
            zhDesc: "一站式电子书书库管理、阅读与 EPUB/MOBI/AZW3/PDF 格式转换神器",
            keywords: "电子书 阅读器 格式转换 epub mobi kindle pdf ebook",
            categories: [.productivity]
        ),
        "skim": .init(
            zhName: "Skim 轻量学术 PDF 阅读器",
            zhDesc: "专为学术论文阅读、LaTeX SyncTeX 联动与高亮批注设计的轻量 PDF 阅读器",
            keywords: "PDF 阅读器 论文 批注 latex skim",
            categories: [.productivity]
        ),
        "wechat": .init(
            zhName: "微信 (WeChat)",
            zhDesc: "腾讯微信 macOS 官方桌面客户端",
            keywords: "微信 聊天 社交 通讯 wechat im",
            categories: [.essentials]
        ),
        "qq": .init(
            zhName: "腾讯 QQ",
            zhDesc: "基于全新架构的腾讯 QQ macOS 官方桌面客户端",
            keywords: "QQ 聊天 社交 腾讯 im",
            categories: []
        ),
        "feishu": .init(
            zhName: "飞书 (Feishu)",
            zhDesc: "字节跳动出品的一站式企业即时沟通、视频会议与云文档协作平台",
            keywords: "飞书 办公 协作 会议 文档 聊天 lark feishu",
            categories: [.productivity]
        ),
        "dingtalk": .init(
            zhName: "钉钉 (DingTalk)",
            zhDesc: "企业协同办公、考勤与视频会议客户端",
            keywords: "钉钉 办公 会议 聊天 考勤 dingtalk",
            categories: [.productivity]
        ),
        "tencent-meeting": .init(
            zhName: "腾讯会议",
            zhDesc: "高清流畅的云视频会议与屏幕共享协同软件",
            keywords: "腾讯会议 视频会议 开会 远程 共享屏幕 meeting",
            categories: [.productivity]
        ),
        "telegram": .init(
            zhName: "Telegram 加密即时通讯",
            zhDesc: "极速、安全、支持超大群组与频道的跨平台云端通讯软件",
            keywords: "电报 聊天 通讯 社交 telegram tg",
            categories: []
        ),
        "discord": .init(
            zhName: "Discord 社区语音聊天",
            zhDesc: "面向开发者、AI 社区与游戏玩家的语音频道与即时交流平台",
            keywords: "语音 社区 聊天 频道 discord",
            categories: []
        ),
        "wpsoffice-cn": .init(
            zhName: "WPS Office 中文版",
            zhDesc: "兼容 Word/Excel/PPT 与 PDF 的国产一站式办公套件",
            keywords: "办公 word excel ppt 表格 文档 演示 wps office",
            categories: [.productivity]
        ),
        "libreoffice": .init(
            zhName: "LibreOffice 开源办公套件",
            zhDesc: "免费开源的完整办公软件套装（文档、电子表格、演示文稿）",
            keywords: "办公 开源 word excel ppt 文档 表格 office",
            categories: [.productivity]
        ),
        "bitwarden": .init(
            zhName: "Bitwarden 开源密码管理",
            zhDesc: "安全可靠的开源跨平台密码库与通行密钥管理工具",
            keywords: "密码 密码管理器 密钥 安全 自动填充 password",
            categories: [.essentials, .productivity]
        ),
        "keepassxc": .init(
            zhName: "KeePassXC 本地离线密码库",
            zhDesc: "完全开源、纯本地加密存储的跨平台密码管理软件",
            keywords: "密码 离线密码库 加密 安全 keepass password",
            categories: [.productivity]
        ),
        "1password": .init(
            zhName: "1Password 密码管理器",
            zhDesc: "macOS 与 iOS 生态体验极佳的家庭与团队密码管理工具",
            keywords: "密码 密钥 自动填充 安全 1password",
            categories: [.productivity]
        ),

        // MARK: - 开发工具 / 终端 / 数据库 (Developer Tools & CLI)
        "visual-studio-code": .init(
            zhName: "VS Code 代码编辑器",
            zhDesc: "微软出品、插件生态最丰富的轻量级全能代码编辑器",
            keywords: "代码 编辑器 开发 编程 IDE vscode",
            categories: [.essentials, .dev]
        ),
        "cursor": .init(
            zhName: "Cursor AI 代码编辑器",
            zhDesc: "基于 VS Code 深度集成 AI 代码生成与多文件改写的智能编程 IDE",
            keywords: "AI编程 代码 编辑器 开发 IDE cursor",
            categories: [.dev, .ai]
        ),
        "zed": .init(
            zhName: "Zed 极速 Rust 代码编辑器",
            zhDesc: "采用 Rust 编写、支持 GPU 加速渲染与原生 AI 协作的超高速代码编辑器",
            keywords: "代码 编辑器 极速 rust 开发 zed",
            categories: [.dev]
        ),
        "iterm2": .init(
            zhName: "iTerm2 经典增强终端",
            zhDesc: "macOS 最受欢迎的终端模拟器，支持分屏、搜索、快捷键唤醒与深度配色",
            keywords: "终端 命令行 shell 分屏 ssh iterm2 terminal",
            categories: [.essentials, .dev]
        ),
        "warp": .init(
            zhName: "Warp 现代 AI 智能终端",
            zhDesc: "基于 Rust 构建的模块化输入与内置 AI 命令助手的现代终端",
            keywords: "终端 命令行 AI终端 shell warp terminal",
            categories: [.dev, .ai]
        ),
        "ghostty": .init(
            zhName: "Ghostty 原生极速终端",
            zhDesc: "采用 SwiftUI 原生外框与 GPU 渲染的高性能跨平台终端模拟器",
            keywords: "终端 命令行 极速 原生 ghostty terminal",
            categories: [.dev]
        ),
        "alacritty": .init(
            zhName: "Alacritty GPU 极简终端",
            zhDesc: "基于 OpenGL/Metal 硬件加速的极简跨平台终端模拟器",
            keywords: "终端 命令行 极简 GPU terminal",
            categories: [.dev]
        ),
        "kitty": .init(
            zhName: "kitty GPU 图形化终端",
            zhDesc: "支持终端内高清图片显示、分屏与标签页的高性能 GPU 终端",
            keywords: "终端 命令行 GPU 图片分屏 kitty terminal",
            categories: [.dev]
        ),
        "orbstack": .init(
            zhName: "OrbStack 轻量 Docker 与 Linux 虚拟机",
            zhDesc: "专为 Apple Silicon 优化的超低内存占用、秒级启动的 Docker Desktop 最佳替代品",
            keywords: "docker 容器 虚拟机 linux 开发 orbstack vm",
            categories: [.essentials, .dev]
        ),
        "docker": .init(
            zhName: "Docker Desktop 容器引擎",
            zhDesc: "官方 Docker 容器化应用构建与管理桌面套件",
            keywords: "容器 镜像 虚拟化 开发 docker container",
            categories: [.dev]
        ),
        "utm": .init(
            zhName: "UTM 开源虚拟机",
            zhDesc: "基于 Apple Virtualization 与 QEMU 的免费 macOS/Windows/Linux 虚拟机软件",
            keywords: "虚拟机 windows linux 虚拟化 开源 utm vm",
            categories: [.dev, .cleanup]
        ),
        "parallels": .init(
            zhName: "Parallels Desktop (PD 虚拟机)",
            zhDesc: "macOS 下性能最强、支持无缝融合模式的 Windows 与 Linux 虚拟机",
            keywords: "虚拟机 windows pd 虚拟化 parallels vm",
            categories: [.dev]
        ),
        "postman": .init(
            zhName: "Postman API 调试平台",
            zhDesc: "全功能的 HTTP/REST/GraphQL 接口请求调试与文档协作平台",
            keywords: "API 接口调试 http 请求 测试 postman",
            categories: [.dev]
        ),
        "bruno": .init(
            zhName: "Bruno 开源本地 API 客户端",
            zhDesc: "基于本地纯文本文件、完美支持 Git 版本管理的轻量开源 Postman 替代品",
            keywords: "API 接口调试 开源 http 请求 bruno postman",
            categories: [.dev]
        ),
        "insomnia": .init(
            zhName: "Insomnia 接口调试工具",
            zhDesc: "简洁高效的 REST、GraphQL 与 gRPC 接口开发测试客户端",
            keywords: "API 接口调试 http graphql insomnia",
            categories: [.dev]
        ),
        "tableplus": .init(
            zhName: "TablePlus 原生数据库客户端",
            zhDesc: "极速轻量的 macOS 原生多数据库图形化管理客户端（支持 MySQL/PG/Redis/SQLite）",
            keywords: "数据库 mysql postgresql redis sqlite sql 客户端 database",
            categories: [.dev]
        ),
        "dbeaver-community": .init(
            zhName: "DBeaver 开源全能数据库管理",
            zhDesc: "免费开源的通用数据库管理与 SQL 开发工具，支持几乎所有主流数据库",
            keywords: "数据库 开源 mysql postgresql oracle sqlite sql dbeaver database",
            categories: [.dev]
        ),
        "sequel-ace": .init(
            zhName: "Sequel Ace 免费 MySQL 客户端",
            zhDesc: "macOS 原生开源免费的 MySQL 与 MariaDB 数据库管理工具",
            keywords: "数据库 mysql mariadb 免费开源 sequel",
            categories: [.dev]
        ),
        "another-redis-desktop-manager": .init(
            zhName: "Another Redis Desktop Manager",
            zhDesc: "更快、更稳定、海量键值不卡顿的开源 Redis 可视化桌面客户端",
            keywords: "redis 数据库 缓存 可视化 开源 database",
            categories: [.dev]
        ),
        "fork": .init(
            zhName: "Fork 快速 Git 图形客户端",
            zhDesc: "界面清爽、响应极快的 macOS 原生 Git 版本控制可视化客户端",
            keywords: "git 版本控制 代码提交 分支 图形界面",
            categories: [.dev]
        ),
        "sourcetree": .init(
            zhName: "Sourcetree 免费 Git 客户端",
            zhDesc: "Atlassian 出品的免费 Git 代码仓库可视化管理工具",
            keywords: "git 版本控制 代码仓库 图形界面 sourcetree",
            categories: [.dev]
        ),
        "github": .init(
            zhName: "GitHub Desktop 官方客户端",
            zhDesc: "GitHub 官方出品的零门槛代码同步与分支管理图形工具",
            keywords: "git github 代码仓库 版本控制",
            categories: [.dev]
        ),
        "wireshark-app": .init(
            zhName: "Wireshark 网络抓包分析",
            zhDesc: "全球最权威的开源网络协议数据包捕获与深度分析工具",
            keywords: "抓包 网络分析 协议 tcp http wireshark",
            categories: [.dev, .network]
        ),
        "proxyman": .init(
            zhName: "Proxyman 原生抓包调试",
            zhDesc: "专为 macOS 原生打造的现代化 HTTP/HTTPS 网络抓包、断点与重写调试工具",
            keywords: "抓包 网络调试 https 代理 Charles替代 proxyman",
            categories: [.dev, .network]
        ),
        "charles": .init(
            zhName: "Charles 经典抓包工具",
            zhDesc: "老牌跨平台 HTTP/HTTPS 网络代理与接口抓包分析软件",
            keywords: "抓包 网络调试 https 代理 青花瓷 charles",
            categories: [.dev, .network]
        ),

        // MARK: - 命令行热门 Formula (CLI Formulae)
        "git": .init(
            zhName: "Git 分布式版本控制",
            zhDesc: "现代软件开发必备的最新版本 Git 命令行工具",
            keywords: "git 版本控制 代码 仓库 命令行",
            categories: [.essentials, .dev]
        ),
        "gh": .init(
            zhName: "GitHub CLI (gh) 命令行",
            zhDesc: "在终端中直接管理 GitHub PR、Issue、Release 与仓库的官方命令行工具",
            keywords: "github git 命令行 pr release",
            categories: [.dev]
        ),
        "wget": .init(
            zhName: "GNU Wget 命令行下载器",
            zhDesc: "支持 HTTP/HTTPS/FTP 断点续传与递归镜像下载的经典网络工具",
            keywords: "下载 命令行 网络 断点续传 wget",
            categories: [.dev, .network]
        ),
        "ripgrep": .init(
            zhName: "ripgrep (rg) 极速文本搜索",
            zhDesc: "基于 Rust 编写、自动忽略 gitignore 的超高速代码与文件内容检索工具",
            keywords: "搜索 查找 代码搜索 grep rg 命令行",
            categories: [.essentials, .dev]
        ),
        "fd": .init(
            zhName: "fd 极速文件查找",
            zhDesc: "比传统 find 快数倍、语法直观友好的现代命令行文件名搜索工具",
            keywords: "查找 文件搜索 find 命令行",
            categories: [.dev]
        ),
        "bat": .init(
            zhName: "bat 代码高亮查看器",
            zhDesc: "带有语法高亮、行号与 Git 修改标记的现代 cat 替代品",
            keywords: "查看文件 语法高亮 cat 命令行",
            categories: [.dev]
        ),
        "eza": .init(
            zhName: "eza 现代彩色文件列表",
            zhDesc: "支持文件图标、树状视图与 Git 状态显示的现代 ls 替代品",
            keywords: "文件列表 目录 ls 命令行",
            categories: [.dev]
        ),
        "fzf": .init(
            zhName: "fzf 终端模糊搜索神器",
            zhDesc: "通用交互式命令行模糊查找器，支持历史命令与文件秒级跳转",
            keywords: "模糊搜索 查找 终端 历史命令 fzf",
            categories: [.dev]
        ),
        "jq": .init(
            zhName: "jq 命令行 JSON 处理",
            zhDesc: "轻量灵活的命令行 JSON 格式化、提取与转换工具",
            keywords: "json 格式化 解析 命令行",
            categories: [.dev]
        ),
        "btop": .init(
            zhName: "btop 炫酷终端资源监控",
            zhDesc: "界面极客华丽的终端 CPU、内存、磁盘与网络实时监控面板",
            keywords: "系统监控 任务管理器 cpu 内存 网速 top htop",
            categories: [.dev, .cleanup]
        ),
        "htop": .init(
            zhName: "htop 交互式进程查看器",
            zhDesc: "经典的终端彩色交互式系统进程与负载监控工具",
            keywords: "系统监控 进程 任务管理器 cpu 内存 top",
            categories: [.dev, .cleanup]
        ),
        "tmux": .init(
            zhName: "tmux 终端复用分屏器",
            zhDesc: "支持会话后台保持与多窗格分屏的终端多路复用器",
            keywords: "终端 分屏 会话 后台 ssh tmux",
            categories: [.dev]
        ),
        "neovim": .init(
            zhName: "Neovim (nvim) 现代编辑器",
            zhDesc: "支持 Lua 插件生态与内置 LSP 的高可扩展现代 Vim 文本编辑器",
            keywords: "编辑器 vim nvim 代码 终端",
            categories: [.dev]
        ),
        "node": .init(
            zhName: "Node.js 运行时",
            zhDesc: "基于 Chrome V8 引擎的 JavaScript 服务端运行环境（含 npm）",
            keywords: "前端 javascript js npm 开发 node",
            categories: [.dev]
        ),
        "uv": .init(
            zhName: "uv 极速 Python 包与环境管理",
            zhDesc: "由 Rust 编写、比 pip 快 10-100 倍的新一代 Python 版本与虚拟环境管理器",
            keywords: "python pip 虚拟环境 包管理 uv",
            categories: [.essentials, .dev]
        ),
        "python@3.13": .init(
            zhName: "Python 3.13 编程语言",
            zhDesc: "广泛用于人工智能、数据分析与自动化脚本的 Python 解释器",
            keywords: "python 编程 脚本 AI 开发",
            categories: [.dev]
        ),
        "go": .init(
            zhName: "Go (Golang) 编程语言",
            zhDesc: "Google 开发的简洁高效高并发编译型编程语言工具链",
            keywords: "golang go 编程 后端 开发",
            categories: [.dev]
        ),
        "rustup": .init(
            zhName: "Rustup 工具链管理器",
            zhDesc: "官方 Rust 编程语言编译器 (rustc) 与包管理器 (cargo) 安装维护工具",
            keywords: "rust cargo 编程 编译 开发",
            categories: [.dev]
        ),
        "cmake": .init(
            zhName: "CMake 跨平台构建系统",
            zhDesc: "C/C++ 项目标准的跨平台编译构建配置生成工具",
            keywords: "c++ 编译 构建 cmake 开发",
            categories: [.dev]
        ),
        "mas": .init(
            zhName: "mas (Mac App Store 命令行)",
            zhDesc: "在终端或脚本中搜索、安装与批量更新 Mac App Store 应用的工具",
            keywords: "应用商店 appstore 命令行 更新 mas",
            categories: [.dev, .productivity]
        ),
        "scrcpy": .init(
            zhName: "scrcpy 安卓手机投屏控制",
            zhDesc: "开源超低延迟通过 USB 或无线在 Mac 上高清显示并键鼠控制 Android 手机",
            keywords: "安卓 投屏 手机控制 镜像 adb android",
            categories: [.productivity, .dev]
        ),
        "imagemagick": .init(
            zhName: "ImageMagick 命令行图像处理",
            zhDesc: "支持超过 200 种图片格式的批量缩放、转换、合成与处理工具集",
            keywords: "图片转换 图像处理 批量缩放 格式转换",
            categories: [.media, .dev]
        ),
        "pandoc": .init(
            zhName: "Pandoc 万能文档格式转换",
            zhDesc: "支持 Markdown、Word、PDF、LaTeX、EPUB 等数十种文档格式互转的瑞士军刀",
            keywords: "文档转换 markdown word pdf latex 格式转换",
            categories: [.productivity, .dev]
        ),
        "mysql": .init(
            zhName: "MySQL 数据库服务",
            zhDesc: "广泛使用的开源关系型数据库服务端（支持通过后台服务一键启停）",
            keywords: "数据库 sql 后台服务 server mysql",
            categories: [.dev]
        ),
        "postgresql@17": .init(
            zhName: "PostgreSQL 17 数据库服务",
            zhDesc: "功能强大的企业级开源对象关系型数据库服务端",
            keywords: "数据库 pg sql 后台服务 postgresql",
            categories: [.dev]
        ),
        "redis": .init(
            zhName: "Redis 内存缓存数据库",
            zhDesc: "高性能开源内存键值数据库与消息中间件（支持后台服务管理）",
            keywords: "数据库 缓存 键值 后台服务 redis",
            categories: [.dev]
        ),
        "nginx": .init(
            zhName: "Nginx 高性能 Web 服务器",
            zhDesc: "轻量高并发的 HTTP Web 服务器与反向代理服务",
            keywords: "服务器 反向代理 web http 后台服务 nginx",
            categories: [.dev, .network]
        ),
        "syncthing": .init(
            zhName: "Syncthing 开源去中心化文件同步",
            zhDesc: "无需云端中转、点对点加密的多设备文件夹实时自动同步服务",
            keywords: "同步 备份 文件同步 局域网 开源 syncthing",
            categories: [.productivity, .network]
        ),

        // MARK: - AI 与大模型工具 (AI & LLM)
        "chatgpt": .init(
            zhName: "ChatGPT 官方桌面客户端",
            zhDesc: "OpenAI 官方 macOS 原生客户端，支持快捷键呼出、截图提问与高级语音",
            keywords: "AI 人工智能 聊天 大模型 openai chatgpt",
            categories: [.essentials, .ai]
        ),
        "claude": .init(
            zhName: "Claude 官方桌面客户端",
            zhDesc: "Anthropic Claude 官方 macOS 桌面应用，擅长代码编写与长文档分析",
            keywords: "AI 人工智能 编程 大模型 anthropic claude",
            categories: [.ai]
        ),
        "ollama-app": .init(
            zhName: "Ollama 本地大模型运行框架",
            zhDesc: "在 Mac Apple Silicon 上一键下载并离线运行 DeepSeek/Qwen/Llama 等开源大模型",
            keywords: "AI 本地大模型 离线模型 deepseek qwen llama ollama",
            categories: [.essentials, .ai, .dev]
        ),
        "ollama": .init(
            zhName: "Ollama 命令行大模型服务",
            zhDesc: "本地运行与管理开源大语言模型的命令行与后台 API 服务",
            keywords: "AI 本地大模型 deepseek qwen llama 后台服务 ollama",
            categories: [.ai, .dev]
        ),
        "lm-studio": .init(
            zhName: "LM Studio 本地大模型可视化工作台",
            zhDesc: "图形化搜索、下载并在本地运行 GGUF/MLX 格式开源大模型的桌面软件",
            keywords: "AI 本地大模型 离线 聊天 mlx gguf lmstudio",
            categories: [.ai]
        ),
        "cherry-studio": .init(
            zhName: "Cherry Studio 多模型 AI 客户端",
            zhDesc: "支持聚合 DeepSeek/OpenAI/Claude/本地 Ollama、知识库与智能体的全能桌面客户端",
            keywords: "AI 大模型 客户端 知识库 deepseek 翻译 cherry",
            categories: [.essentials, .ai]
        ),
        "chatbox": .init(
            zhName: "Chatbox 跨平台 AI 客户端",
            zhDesc: "简洁易用的多 API 模型接入与本地对话管理桌面客户端",
            keywords: "AI 大模型 聊天 客户端 api chatbox",
            categories: [.ai]
        ),
        "jan": .init(
            zhName: "Jan 开源离线 AI 助手",
            zhDesc: "100% 本地离线运行的开源 ChatGPT 替代桌面应用",
            keywords: "AI 离线 本地大模型 开源 jan",
            categories: [.ai]
        ),

        // MARK: - 网络 / 代理 / 下载 / 云盘 (Network, Proxy & Downloaders)
        "clash-verge-rev": .init(
            zhName: "Clash Verge Rev 网络代理客户端",
            zhDesc: "基于 Mihomo (Clash Meta) 内核、界面现代流畅的跨平台规则代理工具",
            keywords: "代理 网络 科学上网 节点 翻墙 clash mihomo proxy",
            categories: [.essentials, .network]
        ),
        "flclash": .init(
            zhName: "FlClash 多平台代理客户端",
            zhDesc: "基于 ClashMeta 内核、Material You 设计的无广告轻量代理客户端",
            keywords: "代理 网络 科学上网 节点 clash proxy",
            categories: [.network]
        ),
        "mihomo-party": .init(
            zhName: "Mihomo Party 代理客户端",
            zhDesc: "基于 Mihomo 内核、支持覆写订阅与TUN模式的现代图形客户端",
            keywords: "代理 网络 科学上网 clash mihomo proxy",
            categories: [.network]
        ),
        "v2rayu": .init(
            zhName: "V2rayU 菜单栏代理工具",
            zhDesc: "基于 v2ray/xray 核心的 macOS 菜单栏网络代理工具",
            keywords: "代理 网络 科学上网 v2ray xray proxy",
            categories: [.network]
        ),
        "tailscale": .init(
            zhName: "Tailscale 异地组网虚拟局域网",
            zhDesc: "基于 WireGuard 零配置打通异地电脑、NAS 与服务器的虚拟局域网神器",
            keywords: "内网穿透 异地组网 虚拟局域网 远程访问 vpn wireguard",
            categories: [.network, .dev]
        ),
        "zerotier-one": .init(
            zhName: "ZeroTier 虚拟局域网组网",
            zhDesc: "老牌跨平台 P2P 异地组网与内网穿透客户端",
            keywords: "内网穿透 异地组网 虚拟局域网 远程 vpn",
            categories: [.network]
        ),
        "motrix": .init(
            zhName: "Motrix 全能开源下载器",
            zhDesc: "基于 aria2 的高颜值开源全能下载工具，支持 HTTP/FTP/BT/磁力链接多线程下载",
            keywords: "下载器 磁力 BT 种子 多线程 百度网盘 aria2 downloader",
            categories: [.essentials, .network]
        ),
        "qbittorrent": .init(
            zhName: "qBittorrent 开源 BT 下载器",
            zhDesc: "干净无广告、功能强大的开源 BitTorrent 种子与磁力链接下载客户端",
            keywords: "下载器 BT 种子 磁力 开源 torrent",
            categories: [.network]
        ),
        "transmission": .init(
            zhName: "Transmission 原生极简 BT 下载",
            zhDesc: "专为 macOS 原生设计、资源占用极低的开源 BT 种子下载工具",
            keywords: "下载器 BT 种子 磁力 轻量 torrent",
            categories: [.network]
        ),
        "aria2": .init(
            zhName: "aria2 命令行多线程下载引擎",
            zhDesc: "超轻量多协议多来源命令行高速下载工具（支持 HTTP/BT/磁力）",
            keywords: "下载器 多线程 命令行 磁力 BT aria2",
            categories: [.network, .dev]
        ),
        "cyberduck": .init(
            zhName: "Cyberduck 远程文件传输小黄鸭",
            zhDesc: "开源免费的 FTP、SFTP、WebDAV、S3 与云存储图形化文件传输客户端",
            keywords: "ftp sftp ssh webdav 服务器传输 云存储 小黄鸭",
            categories: [.network, .dev]
        ),
        "transmit": .init(
            zhName: "Transmit 专业文件传输工具",
            zhDesc: "macOS 标杆级双栏 FTP/SFTP/S3 服务器文件同步与挂载客户端",
            keywords: "ftp sftp ssh 服务器 文件传输",
            categories: [.network, .dev]
        ),
        "baidunetdisk": .init(
            zhName: "百度网盘",
            zhDesc: "百度网盘 macOS 官方桌面客户端",
            keywords: "网盘 云盘 百度 下载 备份",
            categories: [.network]
        ),

        // MARK: - 系统清理 / 硬件监控 / 设计建模 (System Cleanup, Hardware & Design)
        "pearcleaner": .init(
            zhName: "Pearcleaner 开源应用彻底卸载",
            zhDesc: "颜值与实力兼备的开源免费 macOS 应用卸载与残留清理工具",
            keywords: "卸载 清理 残留 垃圾清理 开源 appcleaner替代",
            categories: [.essentials, .cleanup]
        ),
        "appcleaner": .init(
            zhName: "AppCleaner 轻量应用卸载器",
            zhDesc: "经典小巧的免费应用拖拽卸载工具，自动查找关联配置文件一并清除",
            keywords: "卸载 清理 软件卸载 残留 appcleaner",
            categories: [.essentials, .cleanup]
        ),
        "onyx": .init(
            zhName: "OnyX 系统深度维护与清理",
            zhDesc: "老牌免费的 macOS 系统级缓存清理、索引重建与隐藏参数调整工具",
            keywords: "清理 系统维护 缓存 修复 onyx",
            categories: [.cleanup]
        ),
        "omnidisksweeper": .init(
            zhName: "OmniDiskSweeper 磁盘大文件扫描",
            zhDesc: "免费快速的分栏式磁盘空间占用排行扫描与大文件清理工具",
            keywords: "磁盘清理 空间不足 大文件 扫描 存储分析",
            categories: [.cleanup]
        ),
        "grandperspective": .init(
            zhName: "GrandPerspective 磁盘空间热力图",
            zhDesc: "以可视化色块矩形图直观展示硬盘大文件分布的开源空间分析工具",
            keywords: "磁盘空间 大文件 可视化 清理 存储分析",
            categories: [.cleanup]
        ),
        "stats": .init(
            zhName: "Stats 开源菜单栏系统监控",
            zhDesc: "免费开源的菜单栏硬件实时监控工具（CPU、内存、网速、电池、温度与风扇控制）",
            keywords: "系统监控 状态栏 菜单栏 网速 CPU 内存 温度 风扇 istat替代",
            categories: [.essentials, .cleanup, .productivity]
        ),
        "coconutbattery": .init(
            zhName: "coconutBattery 电池健康检测",
            zhDesc: "查看 MacBook 与连接 iPhone/iPad 电池循环次数、设计容量与真实健康度",
            keywords: "电池 健康度 循环次数 硬件检测 battery",
            categories: [.cleanup]
        ),
        "macs-fan-control": .init(
            zhName: "Macs Fan Control 风扇转速与温度控制",
            zhDesc: "实时监控各硬件传感器温度并自定义风扇转速曲线的散热辅助工具",
            keywords: "风扇 散热 温度 降温 硬件监控",
            categories: [.cleanup]
        ),
        "blender": .init(
            zhName: "Blender 开源 3D 建模动画套件",
            zhDesc: "开源免费的全流程三维建模、雕刻、骨骼动画、渲染与视频合成软件",
            keywords: "3D 建模 渲染 动画 设计 开源 blender",
            categories: []
        ),
        "bambu-studio": .init(
            zhName: "Bambu Studio 拓竹 3D 打印切片",
            zhDesc: "拓竹官方出品的高性能多色 3D 打印机模型切片与远程控制软件",
            keywords: "3D打印 切片 拓竹 模型 bambu",
            categories: []
        ),
        "orca-slicer": .init(
            zhName: "OrcaSlicer 开源 3D 打印切片",
            zhDesc: "支持多品牌高速 3D 打印机的开源进阶模型切片软件",
            keywords: "3D打印 切片 开源 模型 slicer",
            categories: []
        ),
        "figma": .init(
            zhName: "Figma 界面设计与原型协作",
            zhDesc: "主流 UI/UX 界面设计、交互原型与团队实时协作桌面客户端",
            keywords: "设计 UI 原型 界面 矢量 figma",
            categories: []
        ),
        "ogdesign-eagle": .init(
            zhName: "Eagle 设计师素材图片管理",
            zhDesc: "设计师必备的本地灵感图片、视频、字体与设计源文件分类检索管理神器",
            keywords: "素材管理 图片管理 设计 灵感 图库 eagle",
            categories: []
        ),
        "gimp": .init(
            zhName: "GIMP 开源图像编辑 (PS 替代)",
            zhDesc: "免费开源的专业位图图像合成、修图与照片处理软件",
            keywords: "修图 图片编辑 PS替代 图像 开源 gimp",
            categories: []
        ),
        "inkscape": .init(
            zhName: "Inkscape 开源矢量图形设计",
            zhDesc: "免费开源的专业 SVG 矢量插画与排版设计软件（Illustrator 替代品）",
            keywords: "矢量图 SVG 插画 设计 AI替代 开源 inkscape",
            categories: []
        ),
        "krita": .init(
            zhName: "Krita 开源数字绘画板绘",
            zhDesc: "专为概念草图、插画、漫画与手绘动画打造的免费开源数字绘画软件",
            keywords: "绘画 板绘 插画 手绘 设计 开源 krita",
            categories: []
        )
    ]

    /// English functional phrase -> Chinese tags mapping for automatic indexing of all 16,500+ packages
    private static let englishKeywordRules: [(phrases: [String], zhTag: String, category: SearchCategoryPreset?)] = [
        (["screenshot", "screen capture", "screen-capture", "screen recording", "screen recorder", "screencast"], "截图 录屏 截屏", .screenshot),
        (["archive", "unarchiver", "decompressor", "compression", "file archiver", "zip", "7-zip", "rar"], "解压 压缩 归档", .archive),
        (["media player", "video player", "multimedia player", "audio player", "music player", "streaming media"], "播放器 视频 音乐 影音", .media),
        (["video converter", "video transcoder", "video editor", "audio editor", "subtitle"], "视频转码 剪辑 字幕 音视频", .media),
        (["translate", "translator", "translation", "dictionary", "ocr"], "翻译 词典 查词 OCR", .translate),
        (["input method", "rime", "pinyin"], "输入法 拼音", .translate),
        (["window manager", "window management", "window switcher", "tiling window"], "窗口管理 分屏 窗口切换", .productivity),
        (["clipboard", "pasteboard"], "剪贴板 复制粘贴 历史记录", .productivity),
        (["menu bar", "menubar", "status bar"], "菜单栏 状态栏工具", .productivity),
        (["password manager", "password vault", "passkey"], "密码管理 密钥 安全", .productivity),
        (["markdown", "note-taking", "knowledge base", "second brain"], "笔记 知识库 Markdown 文档", .productivity),
        (["pdf reader", "pdf viewer", "e-book", "ebook", "epub"], "PDF 阅读器 电子书", .productivity),
        (["terminal emulator", "shell", "command-line"], "终端 命令行 Shell", .dev),
        (["code editor", "source code editor", "ide ", "integrated development"], "代码编辑器 开发 IDE 编程", .dev),
        (["database", "mysql", "postgresql", "sqlite", "redis", "mongodb", "sql client"], "数据库 SQL 客户端", .dev),
        (["container", "virtual machine", "virtualization", "docker", "kubernetes"], "容器 虚拟机 虚拟化", .dev),
        (["git client", "version control"], "Git 版本控制 代码仓库", .dev),
        (["api client", "http client", "graphql", "packet analyzer", "network debugging"], "API调试 抓包 网络分析", .dev),
        (["large language model", "llm", "chatgpt", "openai", "claude", "ai assistant", "artificial intelligence", "machine learning"], "AI 大模型 人工智能", .ai),
        (["proxy", "vpn", "shadowsocks", "clash", "v2ray", "wireguard", "mesh network"], "代理 网络 VPN 异地组网", .network),
        (["download manager", "bittorrent", "torrent", "ftp client", "sftp"], "下载器 BT 磁力 文件传输", .network),
        (["uninstaller", "disk space", "disk usage", "system cleaner", "system monitor", "hardware monitor", "battery", "fan control"], "卸载 清理 磁盘空间 系统监控", .cleanup)
    ]

    public static func meta(for token: String) -> ChinesePackageMeta? {
        curated[token.lowercased()]
    }

    /// Returns a concise Chinese title or functional tag badge for display in SearchCatalogRow
    public static func displayBadge(for entry: CatalogEntry) -> String? {
        guard let m = curated[entry.name.lowercased()] else { return nil }
        // If displayName already contains Chinese characters, skip redundant badge
        if entry.displayName.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return nil
        }
        var concise = m.zhName
        for prefix in [entry.displayName, entry.name] where !prefix.isEmpty {
            if concise.lowercased().hasPrefix(prefix.lowercased() + " ") {
                concise = String(concise.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return concise.isEmpty ? m.zhName : concise
    }

    /// Returns a localized description: in Chinese UI mode, prepends the curated Chinese description or inferred Chinese tags so non-English users immediately understand the package.
    public static func localizedDescription(for entry: CatalogEntry) -> String {
        guard AppLanguage.current.resolved != .en else {
            return entry.desc
        }
        // If entry.desc already contains Chinese characters, return it directly without duplicating
        let hasChineseInDesc = (entry.desc.range(of: "\\p{Han}", options: .regularExpression) != nil)
        if let m = curated[entry.name.lowercased()] {
            if entry.desc.isEmpty || hasChineseInDesc {
                return m.zhDesc
            }
            return "\(m.zhDesc) · \(entry.desc)"
        }
        if hasChineseInDesc {
            return entry.desc
        }
        let tags = inferredChineseTags(for: entry)
        if !tags.isEmpty {
            let prefix = "[\(tags.joined(separator: " / "))] "
            return prefix + entry.desc
        }
        return entry.desc
    }

    public static func inferredChineseTags(for entry: CatalogEntry) -> [String] {
        let haystack = "\(entry.name) \(entry.displayName) \(entry.desc)".lowercased()
        var matched: [String] = []
        for rule in englishKeywordRules {
            if rule.phrases.contains(where: { haystack.contains($0) }) {
                if let firstWord = rule.zhTag.split(separator: " ").first {
                    matched.append(String(firstWord))
                }
                if matched.count >= 2 { break }
            }
        }
        return matched
    }

    /// Checks whether a CatalogEntry belongs to the given category preset
    public static func matchesCategory(_ entry: CatalogEntry, category: SearchCategoryPreset) -> Bool {
        guard category != .all else { return true }
        let lowerName = entry.name.lowercased()
        if let m = curated[lowerName], m.categories.contains(category) {
            return true
        }
        if category == .essentials {
            return false
        }
        let haystack = "\(lowerName) \(entry.displayName.lowercased()) \(entry.desc.lowercased())"
        for rule in englishKeywordRules where rule.category == category {
            if rule.phrases.contains(where: { haystack.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Returns a priority score if `entry` matches the Chinese/English query (`nil` if no match).
    /// Lower rank number = higher priority:
    /// 0 = exact name/displayName/zhName match
    /// 1 = curated package prefix or Chinese keyword match
    /// 2 = name/displayName prefix match
    /// 3 = name/displayName contains match
    /// 4 = English desc or inferred Chinese tag match
    public static func matchRank(for entry: CatalogEntry, queryLower: String) -> Int? {
        let nameLower = entry.name.lowercased()
        let displayLower = entry.displayName.lowercased()
        let descLower = entry.desc.lowercased()
        let curatedMeta = curated[nameLower]

        if nameLower == queryLower || displayLower == queryLower {
            return 0
        }
        if let m = curatedMeta {
            let zhNameLower = m.zhName.lowercased()
            if zhNameLower == queryLower {
                return 0
            }
            if zhNameLower.contains(queryLower) || m.keywords.lowercased().contains(queryLower) || m.zhDesc.lowercased().contains(queryLower) {
                return 1
            }
        }
        if nameLower.hasPrefix(queryLower) || displayLower.hasPrefix(queryLower) {
            return 2
        }
        if nameLower.contains(queryLower) || displayLower.contains(queryLower) {
            return 3
        }
        if descLower.contains(queryLower) {
            return 4
        }

        // Check inferred Chinese functional rules (so searching "截图", "解压", "播放器", "翻译", "终端", "数据库", "代理", "卸载" also finds uncurated packages whose English description matches!)
        let haystack = "\(nameLower) \(displayLower) \(descLower)"
        for rule in englishKeywordRules {
            if rule.zhTag.lowercased().contains(queryLower) {
                if rule.phrases.contains(where: { haystack.contains($0) }) {
                    return 4
                }
            }
        }

        return nil
    }
}
