# BeeCount-UI

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)
![Architecture](https://img.shields.io/badge/Architecture-Non--Intrusive%20UI-blue)
![Upstream](https://img.shields.io/badge/Upstream-TNT--Likely%2FBeeCount-green)
![License](https://img.shields.io/badge/License-BeeCount%20License-orange)

**基于 [蜜蜂记账 (BeeCount)](https://github.com/TNT-Likely/BeeCount) 的现代 UI/UX 重构发行版**

</div>

---

## 项目概述

**BeeCount-UI** 是针对开源个人财务管理应用 [BeeCount](https://github.com/TNT-Likely/BeeCount) 开发的独立用户界面重构版本。本项目完整继承了上游版本稳定的数据内核、离线优先存储机制、多端同步引擎（BeeCount Cloud / iCloud / Supabase / WebDAV / S3）以及 AI 智能记账能力，并在此基础上构建了一套全新的现代化视觉规范与交互系统（Origin Design System）。

### 上游致谢与合规声明

- 本项目核心业务逻辑、数据模型、同步协议及人工智能识别能力均来源于上游项目 **[TNT-Likely/BeeCount](https://github.com/TNT-Likely/BeeCount)**，谨此向原作者 [@TNT-Likely](https://github.com/TNT-Likely) 及所有上游贡献者致以诚挚谢意。
- 本项目严格遵循原项目根目录 [LICENSE](LICENSE) 许可协议进行非商业开源分发，完整保留原始版权声明与协议约束。

---

## 界面预览

以下截图均采集自 Android 真机运行环境（基于最新代码编译）：

<div align="center">
  <table>
    <tr>
      <td align="center"><b>首页明细流</b></td>
      <td align="center"><b>洞察与环形统计</b></td>
      <td align="center"><b>半屏记账键盘</b></td>
      <td align="center"><b>深色模式</b></td>
      <td align="center"><b>周期账单管理</b></td>
    </tr>
    <tr>
      <td align="center"><img src="docs/screenshots/01_home_screen.png" alt="首页明细" width="180" /></td>
      <td align="center"><img src="docs/screenshots/02_insight_chart.png" alt="洞察分析" width="180" /></td>
      <td align="center"><img src="docs/screenshots/03_add_transaction.png" alt="记账键盘" width="180" /></td>
      <td align="center"><img src="docs/screenshots/04_dark_mode.png" alt="深色模式" width="180" /></td>
      <td align="center"><img src="docs/screenshots/05_recurring_transaction.png" alt="周期账单" width="180" /></td>
    </tr>
  </table>
</div>

---

## 重构特性与体验升级

### 1. 全局视觉与个性化
- **全局色彩随设置动态变化**：切换应用主题色后，全应用的按钮、卡片、图表与高亮状态均会实时跟随变化，提供高度统一的个性化视觉体验。
- **悬浮胶囊导航与卡片化布局**：采用分体式悬浮胶囊底部导航栏与统一大圆角卡片容器，界面信息层级更清晰，单手握持操作更顺手。
- **统一滚轮选择器与弹窗规范**：重新梳理全应用的日期、时间、周期滚轮选择器与提示弹窗，保证跨页面的交互手势与视觉反馈高度一致。

### 2. 记账与记录体验
- **半屏底部抽屉统一记账入口**：将新建、编辑与复制账单统一为底部半屏抽屉，无需跳转全屏页面即可单手完成整笔记录。
- **内置计算器键盘与连续记账**：配备紧凑型加减计算器键盘与“再记一笔”按钮，支持在输入金额时直接计算并连续记录多笔账单。
- **二级分类行间就地展开**：支持二级分类图标显示与行间直接展开，选类无需切换界面，再次点击已选子分类即可回退父分类。
- **默认账户联动与智能记忆**：新增账户偏好设置可预设默认收支账户，并自动记忆上次所选的分类与账户，减少重复点选操作。
- **快捷标签与平稳备注输入**：支持快捷标签与交易标记快速点选，填写备注时界面保持平稳不跟随输入法整体抬高或误弹键盘。
- **加号快捷手势与扇形菜单**：右下角加号支持双击与长按快捷手势（可在设置中自由开关），可快速呼出扇形菜单直达不同记账方式。
- **流光语音记账唤醒界面**：重塑语音记账为底部光弧与悬浮文字微岛形式，实时语音识别反馈更加直观纯净。

### 3. 明细流水与搜索管理
- **流水月份吸顶与长按删除**：明细列表支持上滑时月份标题自动吸顶固定，并支持长按单条账单快速删除，长列表浏览与清理更高效。
- **明细资产色彩区分开关**：新增资产颜色显示开关，开启后明细条目可根据现金、银行卡等账户类型渲染对应色彩标识。
- **首页同步状态微圆点**：首页大标题旁增设极简同步状态小圆点，帮助用户随时感知当前处于离线还是云端已同步状态。
- **高效多选与搜索批量整理**：重新设计多选批量操作与搜索结果全选功能，便于一次性集中归类、迁移或清理多笔历史账单。

### 4. 洞察与统计分析
- **多周期与三胶囊快速筛选**：报表顶部支持周报、月报、年报、自定义周期与支出/收入/结余独立胶囊切换，查账维度切换更加流畅。
- **多色环形占比图与折线标注**：升级分类占比图表为多色环形图并附带百分比折线标注，二级分类默认按金额降序排列，消费结构一目了然。
- **全局货币符号显示开关**：支持在设置中自由控制是否展示货币符号，满足不同用户对账单数字简洁度的偏好。

### 5. 资产、预算与自动化
- **资产余额聚焦与隐藏账户独立管理**：资产详情卡片聚焦展示当前实时余额与净资产趋势，已隐藏账户迁移至菜单独立页面集中管理。
- **预算管理与分类下钻**：优化总预算与分类预算设置交互，支持从预算总览直接下钻查看对应分类的消费明细。
- **周期账单与自动化入口**：整合周期记账与记账提醒至独立自动化设置页，周期账单采用上下分层卡片展示规则与一键启停开关。
- **双击返回防误触开关**：在设置中新增双击退出防误触开关，防止在浏览或记账过程中误触返回键直接退出应用。

### 6. 非侵入式工程架构（Zero-Conflict Architecture）
为确保能够持续且低成本地合并上游核心功能与安全补丁，本项目采用严格的代码隔离策略：
- **目录完全隔离**：所有重构页面、基础组件、样式表及视图状态均独立存放于 `lib/custom_ui/` 目录下：
  - `lib/custom_ui/pages/`：29 个独立重构页面实现（覆盖首页、洞察、资产、日历、预算、AI 对话、周期记账、分类与标签管理等模块）。
  - `lib/custom_ui/widgets/`：40 余个标准封装组件（包含 `OriginScaffold`、`OriginBottomNavBar`、`OriginDialog`、`OriginBottomSheet`、`OriginCard`、`OriginHeroCard`、`OriginKeypad`、`OriginAnalyticsPie` 等），确保全应用交互与视觉表达高度统一。
  - `lib/custom_ui/styles/` & `providers/`：独立的主题样式定义与视图级状态适配层。
- **业务逻辑复用**：界面层通过 Riverpod 直接订阅上游 `lib/providers/` 暴露的状态与数据流，不修改 `lib/data/`（数据库模型）、`lib/cloud/`（同步协议）及 `lib/pages/` 原生文件，实现与上游源码的最小表面积耦合。

---

## 本地构建与运行

### 环境要求
- Flutter SDK: `3.27+`
- Dart SDK: 与对应 Flutter 版本匹配
- Android Studio / Xcode（用于对应平台编译打包）

### 常用指令

```bash
# 1. 克隆仓库并切换至 UI 重构分支
git clone -b custom-ui-v4 https://github.com/chenjindongchn/BeeCount-UI.git
cd BeeCount-UI

# 2. 获取依赖
flutter pub get

# 3. 运行开发版（Dev Flavor）
flutter run --flavor dev

# 4. 构建 Android 发布版 APK
flutter build apk --flavor prod --release
```

> 注：若本地 Gradle 版本检查提示兼容性拦截，可在构建命令后附加 `--android-skip-build-dependency-validation` 参数跳过验证。

---

## 开源协议

本项目基于上游 **BeeCount 软件许可协议（[LICENSE](LICENSE) / [LICENSE_EN](LICENSE_EN)）** 开源发布：

- **个人使用、学习研究、非营利组织内部使用及开源贡献**：完全免费。
- **衍生源码要求**：基于本软件的修改版本必须公开源代码，且不得移除原版权声明与作者标识。
- **商业使用**：任何商业产品集成、付费服务或营利性用途，均须联系原著作者获取书面商业授权，详见 [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md)。
