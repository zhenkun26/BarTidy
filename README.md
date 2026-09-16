# BarTidy

仓库：<https://github.com/zhenkun26/BarTidy>

macOS 菜单栏收纳盒。悬停展开，移开收回；没放进盒子的图标一直留在菜单栏。

这是基于开源项目 [Thaw](https://github.com/thaw-app/Thaw) 的二次开发，给自己用。Thaw 能力很全，但默认会把后台图标几乎全收进去，高频 App 每次都要点好几下。BarTidy 只改这一段工作流，其余仍走 Thaw。

> 自用项目。会不定期把 Thaw 的上游更新合进来，但**不太会处理 Issue / PR**。有问题更适合去 [Thaw](https://github.com/thaw-app/Thaw/issues) 看上游是否已经修了。

## 许可证

**GNU GPLv3**，见 [LICENSE](LICENSE)。

Thaw（以及它的上游 [Ice](https://github.com/jordanbaird/Ice)）使用 GPL-3.0。衍生作品必须继续 GPL，**不能改成 MIT**。如果只想用 MIT 的菜单栏工具，请看别的项目，不要把这份代码按 MIT 再分发。

想支持原作者，请给 [Thaw](https://github.com/thaw-app/Thaw) 和 [Ice](https://github.com/jordanbaird/Ice) star，或通过 Thaw 的 [GitHub Sponsors](https://github.com/sponsors/stonerl) 赞助。

## 和 Thaw 不一样的地方

BarTidy 没有重写 Thaw 的布局引擎。改的是默认策略和收纳盒交互。

### 1. 收纳是自己选的，不是默认全收

| | Thaw | BarTidy |
|---|---|---|
| 新出现的菜单栏图标 | 默认进 Hidden | 默认留在 Visible（常驻区） |
| 刘海屏 overflow | 默认开启：空间不够就把常驻区图标再塞进 Hidden | 默认关闭：没被你收纳的图标不会被自动挤走 |
| 常驻区个数 | 容易被 overflow / 新图标规则掏空 | 不限个数，等于「你没拖进盒子的那些」 |

要收某个后台：打开 **Settings → Menu Bar Layout**，把它拖进 Hidden。留在 Visible 的就是常驻，点一下就能用。

### 2. 收纳盒：悬停展开，移开收回

Thaw 的「Show on hover」默认关，打开后也是悬停**菜单栏空白处**才展开，而且走 Thaw Bar 时要等大约 15 秒才收回。

BarTidy：

- 默认打开悬停展开，并默认用 Thaw Bar（图标下方那一条）当收纳盒
- 悬停的是菜单栏上的 **BarTidy 图标**，不是空白区域
- 鼠标还在图标或弹出条上就保持展开
- 移开之后按悬停延迟（默认约 0.2 秒）收回，而不是 15 秒
- 点图标仍然可以手动开关

高频图标放常驻区（一次点击）。偶尔才用的放盒子里（悬停再点）。

### 3. 应用身份

| | Thaw | BarTidy |
|---|---|---|
| 显示名 | Thaw | BarTidy |
| Bundle ID | `com.stonerl.Thaw` | `dev.zhenkun.BarTidy` |
| 设置 / 布局 | Thaw 自己的 defaults | 独立 defaults，不和官方 Thaw 抢同一套布局 |
| Sparkle 更新 | 官方 appcast | 已关掉自动检查，避免把官方 Thaw 更新装到这个 fork 上 |
| URI | `thaw://…` | `thaw://…` 和 `bartidy://…` 都能用 |

Swift 模块名仍是 `Thaw`，源码目录也还叫 `Thaw/`，方便跟上游 diff / rebase。

### 没改的

- 三区模型（Visible / Hidden / Always Hidden）、拖拽排版、搜索、快捷键、Profile、Triggers、外观、Zen mode
- Accessibility / Screen Recording 权限模型
- 嵌入的 XPC 服务名（仍是 `com.stonerl.Thaw.MenuBarItemService` 等）
- GPL-3.0 和 Ice / Thaw 的版权声明

## 使用

1. 先退出已经在跑的官方 **Thaw**，不要两个一起管菜单栏。
2. 用 Xcode 打开本仓库，scheme 选 `Thaw`（产物是 `BarTidy.app`），运行。
3. 第一次启动会走 Thaw 的权限引导，需要辅助功能权限才能移动图标。
4. 在 **Menu Bar Layout** 里只把要收的图标拖进 Hidden。
5. 鼠标悬停菜单栏上的 BarTidy 图标，盒子展开；移开自动收回。

系统要求与 Thaw 相同：macOS 26+。

## 用 Xcode 打开并运行

1. 打开 **Xcode**。欢迎页选 **Open Existing Project…**（不要 Create New Project）。
2. 选中本仓库里的 `Thaw.xcodeproj`，打开。路径一般是 `~/GitHub/BarTidy/Thaw.xcodeproj`。
3. 窗口顶部中间的 scheme 选 **Thaw**，右边设备选 **My Mac**。
4. 先退出已经在跑的官方 Thaw。
5. 点左上角 ▶，或按 `⌘R`。第一次会编译一两分钟，然后菜单栏出现 BarTidy 图标。
6. 系统弹出辅助功能权限时，打开 **系统设置 → 隐私与安全性 → 辅助功能**，勾选 BarTidy。

产物是 `BarTidy.app`。以后要再打开：Xcode 欢迎页会列出这个项目，或用 Finder 双击 `Thaw.xcodeproj`。

## 跟着 Thaw 更新

上游：<https://github.com/thaw-app/Thaw>，默认跟 `development`。

合入时优先保留 BarTidy 这几处，不要被上游默认值盖回去：

- `Thaw/Utilities/Defaults.swift`：`newItemsSection`、`showOnHover`、`useIceBar`、`enableMenuBarItemOverflow`、`globalDisplayConfiguration`
- `Thaw/Events/HIDEventManager.swift`：悬停收纳盒 / 移开收回
- 本 README、显示名、`dev.zhenkun.BarTidy` bundle ID、关掉的 Sparkle 检查

冲突时以「opt-in 收纳 + 悬停盒子」为准。

## 构建

```sh
xcodebuild -scheme Thaw -configuration Debug -destination 'platform=macOS' build
```

本地调试已是 ad-hoc 签名。正式分发需要你自己的开发者账号和公证；本仓库不为这个做发布流水线。

## 致谢

- [Jordan Baird / Ice](https://github.com/jordanbaird/Ice)
- [Toni Förster / Thaw](https://github.com/thaw-app/Thaw)
