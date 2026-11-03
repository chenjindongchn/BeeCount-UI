# 定制改动与上游排查登记表（CUSTOM_MODIFICATIONS.md）

> **重要说明**：
> 本文件记录所有对原项目既有代码（除 `lib/custom_ui/` 纯增量代码之外）的必要微小修改。
> 当从原作者仓库执行 `git pull upstream main` 及 `git rebase` 遇到冲突时，**优先查阅本手册进行秒级核对与排查**。

---

## 一、软件名称定制（“蜜蜂记账” -> “记账蓝盒”）

- **修改日期**：2026-10-31
- **修改范围**：移动端桌面安装显示名称、小组件显示名、隐私权限提示文案、UI 自定义品牌常量。
- **核心原则坚守**：
  - **保留底层包名**：严格保留 `pubspec.yaml` 中的 `name: beecount` 及 Android/iOS 的 `com.tntlikely.beecount` 包名，不破坏上游导包依赖、数据存储路径及组件通信。

### 1. 涉及的原生与配置文件清单

| 平台 | 文件路径 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **Android** | `android/app/src/main/res/values/strings.xml` | `app_name` 与 `app_name_test` 均统一为 `记账蓝盒`（去除“测试版”后缀） | 若上游更新该文件，保留 `<string name="app_name">记账蓝盒</string>` 与 `<string name="app_name_test">记账蓝盒</string>` |
| **iOS** | `ios/Runner/zh-Hans.lproj/InfoPlist.strings` | `CFBundleDisplayName` 与 `CFBundleName` 替换为 `记账蓝盒` | 保留两行名字为 `记账蓝盒` |
| **iOS** | `ios/Flutter/Debug.xcconfig` | `APP_DISPLAY_NAME=记账蓝盒` | 保留该环境变量定义 |
| **iOS** | `ios/Flutter/Release.xcconfig` | `APP_DISPLAY_NAME=记账蓝盒` | 保留该环境变量定义 |
| **iOS** | `ios/Runner/Info.plist` | 隐私权限描述中的“蜜蜂记账”变更为“记账蓝盒” | 若上游新增权限，同步文案即可 |
| **iOS** | `ios/BeeCountWidget/BeeCountWidget.swift` | 小组件预览与配置名称替换为“记账蓝盒” | 保留小组件展示名为“记账蓝盒” |

---

### 2. 代码行级 Diff 备查

#### (1) Android: `android/app/src/main/res/values/strings.xml`
```xml
<<<< 上游原版:
    <string name="app_name">蜜蜂记账</string>
    <string name="app_name_test">蜜蜂记账测试版</string>
==== 本地定制:
    <string name="app_name">记账蓝盒</string>
    <string name="app_name_test">记账蓝盒</string>
>>>>
```

#### (2) iOS: `ios/Runner/zh-Hans.lproj/InfoPlist.strings`
```strings
<<<< 上游原版:
"CFBundleDisplayName" = "蜜蜂记账";
"CFBundleName" = "蜜蜂记账";
==== 本地定制:
"CFBundleDisplayName" = "记账蓝盒";
"CFBundleName" = "记账蓝盒";
>>>>
```

#### (3) iOS: `ios/Flutter/Debug.xcconfig` 与 `Release.xcconfig`
```properties
<<<< 上游原版:
APP_DISPLAY_NAME=蜜蜂记账测试版 (Debug) / 蜜蜂记账 (Release)
==== 本地定制:
APP_DISPLAY_NAME=记账蓝盒 (Debug 与 Release 均统一)
>>>>
```

#### (4) iOS: `ios/Runner/Info.plist`
```xml
<<<< 上游原版:
<string>蜜蜂记账需要访问您的照片库，以便导入或分享账单数据文件</string>
<string>蜜蜂记账需要保存文件到您的照片库</string>
<string>蜜蜂记账需要使用相机拍摄支付凭证进行OCR识别</string>
<string>蜜蜂记账需要使用麦克风进行语音记账</string>
<string>蜜蜂记账使用Face ID进行应用解锁</string>
==== 本地定制:
<string>记账蓝盒需要访问您的照片库，以便导入或分享账单数据文件</string>
<string>记账蓝盒需要保存文件到您的照片库</string>
<string>记账蓝盒需要使用相机拍摄支付凭证进行OCR识别</string>
<string>记账蓝盒需要使用麦克风进行语音记账</string>
<string>记账蓝盒使用Face ID进行应用解锁</string>
>>>>
```

---

## 二、应用内 UI 物理隔离配置（`lib/custom_ui/`）

在 `lib/custom_ui/styles/origin_tokens.dart` 中统一定义品牌常量：

```dart
/// 定制应用与品牌信息（物理隔离存放于 custom_ui，零上游冲突）
class OriginAppInfo {
  OriginAppInfo._();

  /// 软件正式名称
  static const String appName = '记账蓝盒';

  /// 软件测试版名称
  static const String appNameTest = '记账蓝盒测试版';

  /// 软件英文代号
  static const String appNameEn = 'BeeCount';
}
```

* **使用方式**：在所有自定义页面中直接使用 `OriginAppInfo.appName`。
* **上游影响**：原作者仓库完全没有 `lib/custom_ui/` 目录，100% 免疫上游合并冲突。

### 2. 全局主题挂载点（`lib/main.dart`）

为让上游既有界面的原生弹窗与开关零修改即可自动享受 OriginUI 30dp 大圆角与主题色开关样式，在 `lib/main.dart` 极简注入 `applyOriginTheme`：

```dart
<<<< 上游原版:
        theme: applyBeeCardTheme(theme),
        darkTheme:
            applyBeeCardTheme(BeeTheme.darkTheme(platform: platform).copyWith(
          colorScheme: BeeTheme.darkTheme(platform: platform)
              .colorScheme
              .copyWith(primary: primary),
          primaryColor: primary,
        )),
==== 本地定制:
        theme: applyOriginTheme(applyBeeCardTheme(theme), primary: primary, isDark: false),
        darkTheme: applyOriginTheme(
          applyBeeCardTheme(BeeTheme.darkTheme(platform: platform).copyWith(
            colorScheme: BeeTheme.darkTheme(platform: platform)
                .colorScheme
                .copyWith(primary: primary),
            primaryColor: primary,
          )),
          primary: primary,
          isDark: true,
        ),
>>>>
```

* **冲突排查指引**：若上游更新 `MaterialApp` 构建，只需保持外层包裹 `applyOriginTheme(..., primary: primary, isDark: ...)` 即可。

### 3. 冷启动与启动页极简挂载点（`lib/main.dart`）

为彻底解决冷启动时原生桌面图标（新蓝盒 Logo）与 Flutter 启屏页（原版黄色小蜜蜂与 1.2 秒飞线）视觉脱节及双重动画叠加大慢启动问题，在 `lib/main.dart` 挂载 `CustomSplashPage`：

```dart
<<<< 上游原版:
import 'pages/auth/splash_page.dart';
import 'pages/main/home/bindings/home_startup_gate.dart';
...
  Widget _getHomePage(AppInitState initState, WidgetRef ref) {
    if (ref.watch(welcomeCheckProvider).isLoading) return const SplashPage();
    ...
    if (initState != AppInitState.ready) {
      return const AppStartupGate(child: SizedBox.shrink());
    }
    ...
    return const HomeStartupGate(child: BeeApp());
  }
==== 本地定制:
import 'custom_ui/pages/custom_splash_page.dart';
...
  Widget _getHomePage(AppInitState initState, WidgetRef ref) {
    if (ref.watch(welcomeCheckProvider).isLoading) return const CustomSplashPage();
    ...
    if (initState != AppInitState.ready) {
      return const CustomAppStartupGate(child: SizedBox.shrink());
    }
    ...
    return const CustomHomeStartupGate(child: BeeApp());
  }
>>>>
```

* **冲突排查指引**：若上游更新 `_getHomePage` 入口逻辑，仅需将 `SplashPage`、`AppStartupGate`、`HomeStartupGate` 保持指向 `custom_ui/pages/custom_splash_page.dart` 中的定制类即可，业务逻辑 100% 沿用。

### 4. 全局基础组件库适配（`packages/beecount_ui`）

为使原作者在所有设置与表单页面中广泛调用的开关行（`BeeToggleRow`）与弹窗（`BeeDialog`）自动呈现蓝河工具箱 1:1 的 OriginUI 样式：

#### (1) `packages/beecount_ui/lib/src/form_components.dart`
将 `BeeToggleRow` 中原先用 `Transform.scale` 缩放并强制写死样式的原生 `Switch`，替换为真正的 `OriginSwitch`：
```dart
<<<< 上游原版:
                          SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                  child: Transform.scale(
                                      scale: scale,
                                      child: Switch(...))))
==== 本地定制:
                          OriginSwitch(
                            value: value,
                            onChanged: onChanged,
                          )
>>>>
```

#### (2) `packages/beecount_ui/lib/src/dialogs.dart`
将 `BeeDialog` 卡片圆角升级为 30dp，实心胶囊按钮升级为 46dp 高度与 23dp 圆角，暗黑底色采用 OriginOS 真值 `#1E1E1E`。

#### (3) `packages/beecount_ui/lib/beecount_ui.dart`
导出 `export 'src/origin_switch.dart';`，供全项目基础与业务组件统一复用。

### 4. 业务组件库与页面适配（`packages/beecount_business_ui` & `lib/pages/`）

为使账单标记、自动记账规则、云备份设置与 S3 高级配置中的开关无死角覆盖为 OriginUI：

#### (1) `packages/beecount_business_ui/lib/src/automation/recurring_bill.dart`
将 `BeeRecurringBillCard` 中的 `Switch` 替换为 `OriginSwitch`。

#### (2) `packages/beecount_business_ui/lib/src/recording/recording_fields.dart`
将 `RecordingFlagsForm` 中的 `SwitchListTile` 替换为响应整行点击并使用 `OriginSwitch` 的表单行。

#### (3) `packages/beecount_business_ui/lib/src/cloud_data/cloud_backup.dart`
将 `BeeCloudBackupPreference` 中的 `SwitchListTile` 替换为响应整行点击并使用 `OriginSwitch` 的组件行。

#### (4) `lib/pages/cloud/configuration/bindings/cloud_configuration_controls.dart`
将 S3 配置表单第 2122 行的 SSL 开关 `SwitchListTile` 替换为带 `OriginSwitch` 的行。

* **冲突排查指引**：若上游更新上述文件，只需按极简 Diff 保持使用 `OriginSwitch` 即可。

---

## 三、上游更新与变基冲突 10 秒排查手册

当未来原作者发布新版本并执行平滑变基时：

```bash
git checkout main
git pull upstream main
git push origin main
git checkout custom-ui-v4
git rebase main
```

如果 Git 提示在原生配置文件（如 `strings.xml` 或 `Info.plist`）出现冲突：

1. **查看冲突文件**：运行 `git status`，定位冲突文件。
2. **查阅本手册**：对照本手册中的【代码行级 Diff 备查】，将对应行的软件名称保留为 `记账蓝盒`。
3. **标记解决并继续**：
   ```bash
   git add <冲突文件>
   git rebase --continue
   ```
4. 如果发生任何意外，可随时使用 `git rebase --abort` 安全撤销。

---

## 四、通用操作二次确认弹窗（OriginOS 风格化第一轮改造记录）

- **改造日期**：2026-10-31
- **第一性原则落地**：
  全软件共有 14 个核心业务入口用于执行通用二次确认操作。全部入口底层均通过 `showBeeConfirm(...)`（或 `showOriginConfirmDialog(...)`）调度。
  为贯彻 `AGENTS.md`“**NO DIRECT MODIFICATIONS TO lib/pages/**”的铁律，本次改造在 UI 基础库 `packages/beecount_ui/lib/src/dialogs.dart` 中单点升级 `showBeeConfirm` 与 `BeeDialog` 的底层渲染：
  - **304.0dp** 严格锁定标准卡片宽度（vivo vigour 官方真值）；
  - **30.0dp** 外框大圆角（`vigour_layout_corner_Radius`）；
  - **贴底悬浮位置**：`Alignment.bottomCenter`，底部保留系统导航小白条安全边距（`bottom = 28dp + safeAreaBottom`）；
  - **自底部平滑滑入动效**：`SlideTransition(begin: Offset(0, 0.28), end: Offset.zero)` + `Cubic(0.28, 0.85, 0.36, 1.0)` 弹簧贝塞尔曲线，伴随 `HapticFeedback.lightImpact()` 轻触振动反馈，彻底摒弃原地缩放；
  - **46.0dp 高度 / 23.0dp 圆角** 竖排双实心胶囊操作按钮（主操作在上实心填充主题色/危险赤红，次操作在下实心中性灰色胶囊，各占一行，垂直间距 12dp）；
  - **16sp SemiBold 居中大标题** 与 **14sp Regular 严格靠左对齐正文说明**（对齐 vivo 原厂 `DialogContentMessageTextView` 机制，行高 1.5）；
  - 独立滚动区限制（maxHeight 360dp，保证字数较多时按钮绝不被挤出）；
  - 日间纯白 `#FFFFFF` / 夜间纯深黑 `#1E1E1E` 纯净实底（日间 30% alpha / 夜间 60% alpha 沉浸式蒙层）。

### 1. 本轮 14 个通用确认弹窗覆盖清单与验收指引

| 序号 | 所在源码位置 | 触发业务场景与功能 | 触发操作与验收指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/pages/custom_account_detail_page.dart:231` | **隐藏账户二次确认**（若有关联自动记账则特别警示） | 进入账户详情页 -> 点击右上角“两个点” -> 选择「隐藏账户」 |
| **02** | `lib/custom_ui/pages/custom_account_detail_page.dart:266` | **删除账户确认**（统计并提示关联合计交易笔数，危险红色确认态） | 进入账户详情页 -> 点击右上角“两个点” -> 选择「删除账户」 |
| **03** | `lib/pages/main/ledgers/bindings/ledger_actions.dart:278` | **删除账本二次确认**（危险红色确认态） | 首页右上角切换账本 -> 账本管理列表 -> 点击删除账本 |
| **04** | `lib/pages/main/ledgers/bindings/ledger_actions.dart:960` | **清空账本所有交易确认**（危险红色确认态） | 账本管理 -> 账本更多菜单 -> 选择「清空账本交易」 |
| **05** | `lib/pages/category/editor/bindings/category_edit_actions.dart:280` | **删除分类及关联条目确认**（危险红色确认态） | 我的 -> 分类管理 -> 点击某分类进入编辑 -> 点击底部删除分类 |
| **06** | `lib/pages/category/migration/bindings/category_migration_actions.dart:82` | **分类数据迁移合并确认** | 我的 -> 分类管理 -> 分类合并/迁移 -> 确认合并执行 |
| **07** | `lib/pages/tag/manage/bindings/tag_library_actions.dart:36,54,148` | **删除标签 / 批量清理未关联标签确认** | 我的 -> 标签管理 -> 单个删除或右上角菜单批量清理未用标签 |
| **08** | `lib/pages/tag/tag_detail_page.dart:66` | **标签详情页移除标签确认** | 标签详情页面 -> 点击右上角或底部删除标签 |
| **09** | `lib/pages/transaction/search_page.dart:184` | **账单批量搜索与筛选结果批量删除确认** | 洞察或明细页点击搜索 -> 勾选批量模式 -> 勾选条目后点击批量删除 |
| **10** | `lib/pages/transaction/transaction_editor_page.dart:361` | **记账页面返回时放弃修改确认** | 进入记账抽屉/页面 -> 输入金额或备注后直接左滑返回或按返回键 |
| **11** | `lib/pages/account/edit/bindings/account_edit_actions.dart:482,527` | **账户编辑重置或放弃未保存变更确认** | 资产页 -> 点击右上角“两个点” -> 新增账户 -> 输入信息后点返回 |
| **12** | `lib/pages/ai/chat/bindings/ai_chat_controls.dart:957,1253` | **清空 AI 对话历史 / 重置会话确认** | 明细/洞察右上角进入 AI 助手 -> 更多菜单 -> 清空当前会话 |
| **13** | `lib/pages/attachment/widgets/attachment_viewer.dart:220` | **删除账单附件图片确认** | 记账详情页查看收据大图 -> 点击右上角垃圾桶删除图片 |
| **14** | `lib/custom_ui/pages/custom_analytics_page.dart:99` | **重新计算外币汇率确认** | 洞察页面 -> 遇到多币种重新汇率校准操作 |

### 2. 冲突排查指引

若未来上游更新 `packages/beecount_ui/lib/src/dialogs.dart`：
- 保留 `showBeeConfirm` 中使用的 `_OriginBeeConfirmDialogWidget` 和 `showGeneralDialog` 动效实现；
- 业务页面（`lib/pages/`）无需任何同步操作，依旧调用 `showBeeConfirm`，永不发生合并冲突。

---

## 五、自定义表单与多选功能弹窗（OriginOS 风格化第二轮改造记录）

- **改造日期**：2026-10-31
- **第一性原则与 0 侵入**：
  第二批覆盖全软件中基于 `showBeeDialog` 与 `BeeDialog` 的 12 个核心自定义表单、多选操作与业务提示弹窗。
  遵循 `AGENTS.md`“**NO DIRECT MODIFICATIONS TO lib/pages/**”铁律，所有改动均在 UI 基础库 `packages/beecount_ui/lib/src/dialogs.dart` 及 `lib/custom_ui/widgets/origin_dialog.dart` 中单点完成，零侵入上游业务层。
- **四大核心规范真值 100% 对齐**：
  1. **【位置与贴底悬浮】**：全量锁定 `Alignment.bottomCenter`，底边距为系统手势导航条高度 + 28dp（`bottom = 28dp + safeAreaBottom`），卡片锁定官方 304dp 标准宽度与 30dp 大圆角，日白 `#FFFFFF` / 夜黑 `#1E1E1E` 纯净实底（30%/60% 沉浸遮罩）；
  2. **【入场动效】**：统一由 `showGeneralDialog` 驱动，采用 **从屏幕底部平滑上升滑入（Slide up from bottom）**：`SlideTransition(begin: Offset(0, 0.28), end: Offset.zero)`，配合 `Cubic(0.28, 0.85, 0.36, 1.0)` 弹簧曲线（260ms），伴随 `HapticFeedback.lightImpact()` 触感振动反馈，彻底终结原地缩放；
  3. **【正文对齐】**：标题 16sp SemiBold 居中排版；正文说明与内容区域严格 **靠左排版（`TextAlign.start` / `Alignment.centerLeft`）**，行高 1.5，限高 360dp 并内建 `BouncingScrollPhysics` 独立弹性滚动；
  4. **【按钮上下竖排一按钮一行】**：彻底摒弃左右横排 `Row` 布局，操作按钮统一采用上下竖排（`Column`），每个按钮独占一整行（高度 46.0dp，圆角 23.0dp，纵向间距 12dp）。内建智能主次排序（若原数组是 `[取消, 删除]` 或 `[取消, 确定]`，自动对齐为 **主操作在上实心胶囊、次操作在下中性灰胶囊**）。

### 1. 本轮 12 个自定义表单与多选功能弹窗覆盖清单与验收指引

| 序号 | 所在源码位置 | 触发业务场景与功能 | 触发操作与验收指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/pages/main/ledgers/bindings/ledger_actions.dart:98` | **账本选项操作弹窗**（编辑账本、预算管理、清空交易等动作列表） | 明细页右上角切换账本 -> 账本管理列表中长按或点击账本项弹出 |
| **02** | `lib/pages/main/ledgers/bindings/ledger_actions.dart:219` | **远程账本更多操作弹窗**（下载到本地、删除远程账本选项） | 明细页右上角切换账本 -> 远程账本卡片点击「更多」图标 |
| **03** | `lib/pages/main/ledgers/bindings/ledger_actions.dart:970,980` | **账本操作错误与完成提示弹窗**（正文靠左，单胶囊按钮居底独占一行） | 账本管理中执行备份、恢复或同步遇到异常/提示时触发 |
| **04** | `lib/pages/category/manage/bindings/category_management_actions.dart:34` | **分类快捷管理工具弹窗**（拖拽提示、分享、新增、导入、清理未用分类） | 我的 -> 分类管理 -> 点击右上角「设置/更多」快捷工具图标 |
| **05** | `lib/pages/category/editor/bindings/category_edit_actions.dart:80` | **分类操作校验提示弹窗**（分类重名或未填名称提示） | 我的 -> 分类管理 -> 新增或编辑分类 -> 输入已存在名称保存触发提示 |
| **06** | `lib/pages/category/migration/bindings/category_migration_actions.dart:57` | **分类迁移不可用拦截弹窗**（原分类与目标分类相同时的提示） | 我的 -> 分类管理 -> 点击合并/迁移 -> 目标选择相同分类时提示 |
| **07** | `lib/pages/account/overview/bindings/assets_card_actions.dart:165` | **资产概览账户搜索弹窗**（搜索框与各账户列表平滑滚动筛选） | 资产页面 -> 顶部资产卡片右上角点击「搜索」按钮唤起 |
| **08** | `lib/pages/account/edit/bindings/account_edit_actions.dart:620` | **账户编辑信息提示弹窗**（保存校验或业务提示） | 资产页右上角两点菜单 -> 新增账户 -> 校验或操作提示 |
| **09** | `lib/pages/budget/editor/bindings/budget_editor_actions.dart:143` | **预算删除二次确认弹窗**（竖排：上方危险赤红「删除」，下方中性灰「取消」） | 洞察或预算列表 -> 点击某预算条目进入编辑 -> 底部点击「删除预算」 |
| **10** | `lib/pages/transaction/recurring/bindings/recurring_editor_actions.dart:335,477` | **周期记账规则弹窗**（①关联账户多选列表单选；②规则删除竖排确认） | 我的 -> 周期记账 -> 点击新建或编辑规则：①点击账户行选账户；②点击底部删除规则 |
| **11** | `lib/pages/tag/manage/bindings/tag_library_actions.dart:108` | **标签导入模式选择弹窗**（合并导入 / 覆盖导入两项图文说明与靠左排版） | 我的 -> 标签管理 -> 右上角菜单 -> 导入标签配置 YAML 时触发 |
| **12** | `lib/pages/transaction/recording/bindings/amount_editor_sheet.dart:513` | **外币记账自定义汇率输入弹窗**（数值校验输入框与居底胶囊按钮） | 首页点记账「+」-> 切换为外币账户 -> 金额键盘上方点击汇率标签修改 |

### 2. 冲突排查指引

若未来上游更新 `packages/beecount_ui/lib/src/dialogs.dart`：
- 保留 `BeeDialog` 的贴底悬浮结构、`_sortOriginActions` 智能排序与 `_OriginActionCapsule` 满宽胶囊渲染；
- 保留 `showBeeDialog` 中使用的 `showGeneralDialog` 自底升起动画配置；
- 上游任何新业务弹窗均可自动继承 OriginUI 贴底悬浮、自底上升、靠左排版及竖排胶囊按钮规范。

---

## 六、云同步、备份与迁移弹窗（OriginOS 风格化第三轮改造记录）

- **改造日期**：2026-10-31
- **第一性原理与架构落地**：
  第三批覆盖云同步、WebDAV/自建云设置、多设备协同、差异同步预览、数据导入与备份恢复等 7 大核心业务场景。
  此类弹窗多在业务代码中直接调用 `showDialog(builder: (_) => BeeDialog(...))` 或 `AppDialog._show(...)`。
  本次改造通过在 `BeeDialog` 内部内建自底平滑升起动效（`TweenAnimationBuilder` + `Cubic(0.28, 0.85, 0.36, 1.0)` 弹簧贝塞尔曲线，自底部偏移 60dp 升起渐显），并强化按钮智能排序与全类型胶囊支持：
  1. **零改动业务代码**：`lib/pages/cloud/`、`lib/pages/settings/`、`lib/pages/data/` 零代码变动，彻底杜绝 Git Rebase 冲突；
  2. **动效完全统一**：无论通过 `showBeeDialog` 还是原生 `showDialog` 唤起，弹窗一律由屏幕底端平滑升起浮入；
  3. **排版严格靠左**：多设备向导、数据预览、配置内容等全部严格靠左对齐（`TextAlign.start`），限高 360dp 并内建独立弹性回弹滚动；
  4. **按钮上下竖排**：双按钮自动排序（主操作在上、取消在下），独占整行（高 46dp，圆角 23dp，纵向间距 12dp）。

### 1. 本轮 7 大云同步与数据迁移场景清单与验收指引

| 序号 | 所在源码位置 | 触发业务场景与功能 | 触发操作与验收指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/pages/cloud/configuration/bindings/cloud_configuration_controls.dart` | **云端配置与连通性测试弹窗**（多设备指南、Supabase/WebDAV/S3 帮助、连通性测试结果） | 设置 -> 云同步设置 -> 点击多设备同步说明或点击「测试连接」 |
| **02** | `lib/pages/cloud/sync_preview_dialog.dart:18` | **云端数据双向冲突差异对比预览弹窗**（本地与云端新增、修改、删除条目多选同步） | 云同步中发生双向变动冲突时触发差异预览确认 |
| **03** | `lib/pages/cloud/shared/bindings/cloud_shared_member_list.dart:137,215` | **共享账本成员移除与退出确认弹窗**（移除协作者二次确认、退出共享账本二次确认） | 账本详情 -> 共享成员列表 -> 点击某成员选择「移除」或点击「退出共享账本」 |
| **04** | `lib/pages/data/import/bindings/import_confirm_controls.dart:365,415` | **账单导入映射与后台进度弹窗**（币种与账户映射核对预览弹窗、后台导入进度展示） | 设置 -> 数据导入 -> 选取微信/支付宝 CSV 账单解析后弹出的账户币种预览 |
| **05** | `lib/pages/settings/configuration/bindings/config_transfer_actions.dart:53` | **恢复备份全库覆盖确认与 YAML 导出预览**（导出 YAML 内容查看复制、恢复覆盖警告） | 设置 -> 配置备份与恢复 -> 导出配置预览或从文件恢复配置 |
| **06** | `lib/pages/settings/logs/bindings/maintenance_logs.dart:77` | **清空本地运行调试日志确认弹窗**（清空日志二次确认，确定在上、取消在下） | 设置 -> 维护与日志 -> 调试日志列表 -> 点击右上角垃圾桶清空日志 |
| **07** | `lib/pages/settings/appearance/bindings/appearance_dialogs.dart:16,44` | **外观模式与备注历史偏好设置弹窗**（深色/浅色/跟随系统列表单选、备注排序与上限配置） | 设置 -> 个性化与外观 -> 点击外观模式单选或备注历史偏好设置 |

---

## 七、系统服务、更新与权限弹窗（OriginOS 风格化第四轮改造记录）

- **改造日期**：2026-10-31
- **第一性原理与全局主题穿透**：
  第四批覆盖应用自动更新、镜像源切换、无障碍智能记账授权、系统通知与电池优化白名单、用户资料昵称编辑等 5 大系统级场景。
  针对其中极少数直接调用的原生 `AlertDialog`（如更新下载提示与 GitHub 兜底）：
  本次改造在 `lib/custom_ui/styles/origin_tokens.dart` 的 `applyOriginTheme` 中向全局 `ThemeData.dialogTheme` 注入了 OriginOS 规范真值：
  - `alignment: Alignment.bottomCenter`：全局锁定贴底悬浮；
  - `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))`：全局锁定 30dp 大圆角；
  - `insetPadding: EdgeInsets.only(left: 28.0, right: 28.0, bottom: 28.0)`：贴底安全避让手势横条；
  - `actionsPadding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 20.0)`：对齐胶囊按钮外边距；
  - `backgroundColor: dialogBg` 与 `surfaceTintColor: Colors.transparent`：杜绝任何 M3 杂色蒙层。

### 1. 本轮 5 大系统服务与更新权限场景清单与验收指引

| 序号 | 所在源码位置 | 触发业务场景与功能 | 触发操作与验收指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/services/update/update_dialogs.dart:42,147,162,204` | **版本更新提示与下载失败兜底弹窗**（新版本发布日志展示、确认下载、前往 GitHub Releases） | 我的 -> 关于 -> 检查新版本（或模拟网络异常触发兜底弹窗） |
| **02** | `lib/services/update/update_dialogs.dart:270` | **切换 GitHub / Gitee 加速镜像源弹窗**（镜像测速与切换镜像源单选列表） | 关于页面 -> 更新设置 -> 点击切换下载镜像源 |
| **03** | `lib/pages/settings/smart_billing/bindings/smart_billing_dialogs.dart:16,35` | **智能记账无障碍辅助授权引导与语音触发模式弹窗**（智能识别说明、语音触发模式单选） | 设置 -> 智能记账 -> 开启自动识别引导说明或修改语音记账触发方式 |
| **04** | `lib/pages/settings/reminders/bindings/reminder_diagnostics.dart:56,100` | **通知栏记账提醒与电池优化权限指引弹窗**（电池优化白名单引导、通知渠道状态诊断说明） | 设置 -> 记账提醒 -> 点击「电池优化状态」或「通知渠道诊断」 |
| **05** | `lib/pages/main/mine/widgets/mine_profile.dart:52,122` | **修改用户昵称与头像更换途径选择弹窗**（我的主页修改昵称输入框、头像选取来源单选列表） | 我的 -> 点击顶部个人信息卡片 -> 弹出编辑菜单 -> 修改昵称或更换头像 |

### 2. 冲突排查指引

若未来上游更新系统或服务弹窗：
- 所有通过 `BeeDialog`、`AppDialog` 唤起的弹窗自动获得自底平滑升起、贴底悬浮、靠左排版及竖排胶囊按钮；
- 所有原生 `AlertDialog` 均由全局 `applyOriginTheme` 注入贴底悬浮和 30dp 圆角；
- 0 处直接修改 `lib/pages/` 业务代码，随时可安全执行 `git pull upstream main` 和 `git rebase`。

---

## 八、全软件日期与时间选择组件（vivo OriginOS 原厂规范 100% 对齐与深度改造）

- **改造日期**：2026-11-01
- **第一性原理与设计依据**：
  直接对标连接设备从 vivo 官方钱包应用（`com.vivo.wallet`）反编译提取的原厂规范文档（`OriginUI/docs/25-date-and-time-picker.md`）及配套截图真值（`wallet_datepicker_popup.png`、`wallet_datepicker_year_select.png`、`wallet_timepicker_popup.png`、`wallet_bill_edit.png`）：
  1. **记账面板胶囊入口（wallet_bill_edit）**：
     记账抽屉中将原本杂交的一体化时间拆为独立的【日期胶囊】（如 `今天` / `11-01`）与【时间胶囊】（如 `17:11`），点击分别呼出真正的原厂日历弹窗和原厂时间滚轮弹窗。
  2. **日期选择器弹窗（wallet_datepicker_popup & wallet_datepicker_year_select）**：
     - 居中 20sp Bold 大标题（`2026年11月1日 周日`）；
     - 年月导航栏：左侧带下拉倒三角的 `2026年11月 ▾`（点击平滑展开/收起年月双滚轮），右侧 `<` 和 `>` 切月按钮；
     - 星期表头（`日 一 二 三 四 五 六`）与 7 列日历表格，选中态为直径 36dp 实心强调色高亮圆盘；
     - 原厂核心交互“浏览态与选定态解耦”：切月不改选定日期，点击具体单元格才更新；
     - 底部竖排双胶囊：主操作【确定】在上方（主题色实底白字），次操作【取消】在下方（浅灰底深字）。
  3. **时间选择器弹窗（wallet_timepicker_popup）**：
     - 居中 22sp Bold 大标题实时显示选定时间（如 `17:11`）；
     - 双列滚轮高 200dp、单项高 40dp、选中项 22sp~24sp Bold；
     - 原厂核心细节“单位固定，纯数字翻滚”：选中行右侧固定静态“时”、“分”单位，仅纯数字翻滚；
     - 底部竖排双胶囊按钮与 28dp 圆角卡片。
  4. **桥接与零上游冲突**：
     - `showWheelDatePicker`、`showWheelDateTimePicker`、`showWheelTimePicker` 全面桥接至 OriginUI，保持调用方零业务修改。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/pages/shared/pickers/wheel_date_picker.dart` | `showWheelDatePicker` 转发至 `showOriginDatePicker`；`showWheelDateTimePicker` 按原厂两步转发 | 若上游更新该文件，保留极简桥接即可 |
| **02** | `lib/pages/shared/pickers/wheel_time_picker.dart` | `showWheelTimePicker` 转发至 `showOriginTimePicker` | 保留转发调用即可 |
| **03** | `lib/pages/shared/resources/widgets/detail_period_controls.dart` | `showResourcePeriodPicker` 转发至 `showOriginPeriodPicker` | 保留转发调用即可 |
| **04** | `lib/pages/transaction/recurring/bindings/recurring_editor_pickers.dart` | `showRecurringEditorDatePicker` 转发至 `showOriginDatePicker` | 保留转发调用即可 |
| **05** | `lib/pages/settings/reminder_settings_page.dart` | `_time()` 时间设置调用 `showOriginTimePicker` | 保留调用即可 |
| **06** | `lib/custom_ui/pages/custom_transaction_sheet.dart` | 拆分为独立日期与时间胶囊，分别呼出原厂日历与时间弹窗 | 定制目录纯增量代码 |
| **07** | `lib/custom_ui/widgets/origin_date_picker.dart` | 原厂日历网格、展开双滚轮、纯滚轮模式与标准 OriginDialog 弹窗 | 定制目录纯增量代码 |
| **08** | `lib/custom_ui/widgets/origin_time_picker.dart` | 原厂 22sp 大标题、纯数字滚轮+固定单位与标准 OriginDialog 弹窗 | 定制目录纯增量代码 |
| **09** | `lib/custom_ui/widgets/origin_wheel_picker.dart` | 单位固定右侧静止、阻尼震动反馈与平滑渐隐滚轮 | 定制目录纯增量代码 |

---

## 九、AI 智能记账助手（vivo OriginOS / 蓝心小V 风格深度重构）

- **改造日期**：2026-11-02
- **第一性原理与设计依据**：
  直接对标连接真机提取的 vivo 蓝心小V（`com.vivo.ai.copilot`）最新原厂交互与视觉真值（历史对话流 & 新对话向导）：
  1. **Borderless 去卡片化通透对话**：
     - AI 助手回答去除多层厚重白框包裹，文字直接平铺于页面背景，行距宽阔（1.65），左下角配备微型胶囊操作条（复制/删除）；
     - 用户发言使用主题色 18dp 大圆角活力胶囊，右对齐白字。
  2. **蓝心小V标志性悬浮大胶囊输入 Dock（Floating Pill Dock）**：
     - 悬浮于手势条上方，两侧 16dp 留白，完全半圆弧（26dp 圆角）；
     - 集成左侧相机/识图快捷按钮（支持拍照记账与相册导入）、中间自适应多行输入框、右侧智能流转操作（发送/停止/语音）；
     - Dock 上方集成单行横滑追问与常用指令药丸群。
  3. **空会话向导看板（OriginAiEmptyState）**：
     - 仿蓝心小V大字号浅色柔和问候标语（“智能记账，找小助手”）；
     - 当前账本月度财务概览微药丸；
     - 带金色闪烁星标 `✨` 的通透圆角建议卡片（支持一键点发）。
  4. **记账结果卡片（OriginBillCard）**：
     - 14dp 圆角、0.5dp 发丝描边、大字号金额、账本徽标与分类圆形色块图标；
     - 底部集成 30dp 紧凑胶囊按钮（撤销、编辑明细、更换账本），撤销状态自动呈现删除线与优雅置灰。
  5. **严格零上游冲突挂载**：
     - 100% 物理隔离于 `lib/custom_ui/pages/custom_ai_chat_page.dart` 及 `lib/custom_ui/widgets/ai/`；
     - 仅在入口文件（`lib/app.dart`、`custom_home_page.dart`、`custom_analytics_page.dart`）替换 1 行路由指向。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/app.dart` | `AppLinkAction.aiChat` 路由指向 `CustomAIChatPage` | 若上游更新该路由，保留指向 `CustomAIChatPage` 即可 |
| **02** | `lib/custom_ui/pages/custom_home_page.dart` | 首页右上角/卡片 AI 入口指向 `CustomAIChatPage` | 定制目录纯增量代码 |
| **03** | `lib/custom_ui/pages/custom_analytics_page.dart` | 报表页 AI 顾问入口指向 `CustomAIChatPage` | 定制目录纯增量代码 |
| **04** | `lib/custom_ui/pages/custom_ai_chat_page.dart` | 蓝心小V风格 AI 记账对话主页面 | 定制目录纯增量代码 |
| **05** | `lib/custom_ui/widgets/ai/origin_ai_input_dock.dart` | 蓝心小V标志性悬浮胶囊输入 Dock | 定制目录纯增量代码 |
| **06** | `lib/custom_ui/widgets/ai/origin_ai_empty_state.dart` | 蓝心小V向导与金色 ✨ 建议卡片组件 | 定制目录纯增量代码 |
| **07** | `lib/custom_ui/widgets/ai/origin_bill_card.dart` | 14dp 圆角 Origin 记账结果卡片 | 定制目录纯增量代码 |
| **08** | `lib/custom_ui/widgets/ai/origin_ai_message_bubble.dart` | 通透 Borderless 消息气泡组件 | 定制目录纯增量代码 |
| **09** | `lib/custom_ui/pages/custom_ai_settings_page.dart` | OriginOS 风格 AI 助手设置页面（权限、记忆、深度、模型服务商） | 定制目录纯增量代码 |

---

## 十、主界面加号手势增强与扇形快捷菜单错位修复

- **改造日期**：2026-11-02
- **第一性原理与设计依据**：
  1. **右下角悬浮加号几何原点矫正**：
     - 原版 `BeeQuickAddFan` 内部针对居中按钮设计并通过 `safeOrigin` 强行限制横坐标，导致加号在右下角时原点严重错位；
     - 全新封装 `OriginQuickAddFan`，原点 100% 锚定加号按钮真实几何中心，原加号顺滑旋转 45° 变叉号。
  2. **极简紧凑纯图标扇形交互**：
     - 去除顶部大块提示文字和各选项文字标签，纯保留 42dp 精致小圆动作图标（相机、相册、语音）；
     - 展开半径紧凑收紧至约 64dp，呈左上方扇形展开，符合大拇指自然张合，滑动切换灵敏自如。
  3. **加号手势增强（加号增强开关）**：
     - 在「我的」页面「货币符号」上方新增「加号增强」开关，支持本地持久化；
     - 开启后：主页加号按钮单击依然打开记账抽屉，双击快捷调用相机拍照记账，长按直接触发语音记账；
     - 关闭时：单击保持零延迟立即打开记账，长按展开微型扇形快捷菜单。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/providers/plus_button_enhancement_provider.dart` | 加号增强状态 Provider 与本地持久化 | 定制目录纯增量代码 |
| **02** | `lib/custom_ui/widgets/origin_quick_add_fan.dart` | 紧凑型纯图标扇形快捷菜单组件 | 定制目录纯增量代码 |
| **03** | `lib/custom_ui/widgets/origin_bottom_nav_bar.dart` | 底部导航栏加号按钮单击/双击/长按分流与手势检测 | 定制目录纯增量代码 |
| **04** | `lib/custom_ui/pages/custom_mine_page.dart` | 「我的」页面在货币符号上方新增「加号增强」设置项 | 定制目录纯增量代码 |
| **05** | `lib/app.dart` | 主入口加号手势事件挂载与 SpeedDialOverlay 适配 | 极小侵入式挂载 |
| **06** | `test/custom_ui/plus_button_enhancement_test.dart` | 加号增强与扇形菜单专项验收测试套件 | 定制目录纯增量代码 |

---

## 十一、语音记账唤醒层：Gemini 纯净底部光弧 + 浮空环境文字

- **改造日期**：2026-11-02
- **设计**：彻底去除生硬的悬浮胶囊微岛与内部线条。底部升起纯净的 Gemini 四色（#4285F4 / #9B72CB / #D96570 / #F4B400）流动半圆光弧，光弧随说话振幅升高并伴随浮游星尘粒子；光弧核心黄金区域浮空呈现大字号状态与识别文字（未说话时提示“请开始说话...”，说话后逐字打字机浮现转写文本，成功转为清爽翡翠绿）。按住说话模式支持轻量触控手势，自动检测模式说完自动记账，点击空白处取消。
- **提示与文案**：全部复用上游 `showBeeToast` 与 l10n 文案，不新增任何硬编码字符串。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/widgets/voice/origin_voice_session.dart` | 语音会话纯逻辑控制器（与上游私有录音状态机对齐的副本） | 定制目录纯增量代码，**见下方同步说明** |
| **02** | `lib/custom_ui/widgets/voice/gemini_glow_arc.dart` | 底部流动半圆光弧 + 星尘粒子 | 定制目录纯增量代码 |
| **03** | `lib/custom_ui/widgets/voice/origin_voice_overlay.dart` | 纯净光弧唤醒层装配、浮空文本排版与进退场动画 | 定制目录纯增量代码 |
| **04** | `test/custom_ui/voice_overlay_test.dart` | 唤醒层纯净底部光弧组件测试 | 定制目录纯增量代码 |
| **05** | `lib/utils/voice_billing_helper.dart` | ① 新增 1 行 import；② `showDialog` 改为 `showGeneralDialog`；③ 用 `pageBuilder` 挂载 `OriginVoiceOverlay`。上游 `_VoiceRecordingDialog` 类保持原样未改动 | 冲突时保留上游其余改动，仅重新套用这 3 处 |

### 2. Diff 备查（`lib/utils/voice_billing_helper.dart`）
```dart
<<<< 上游原版:
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _VoiceRecordingDialog(
==== 本地定制:
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        barrierLabel: 'OriginVoiceAssistant',
        pageBuilder: (dialogContext, _, __) => OriginVoiceOverlay(
>>>>
```

### 3. ⚠️ 逻辑副本同步说明（每次 rebase 后必做）
上游的录音、静音检测和 AI 调用逻辑写在私有类 `_VoiceRecordingDialogState` 中，没有 Provider 可以复用，因此 `origin_voice_session.dart` 保留了一份逐项对齐的副本。
这份副本**不会产生 Git 冲突，但也不会自动跟上上游的修改**。

- 对齐基线：上游 commit `ce01d69dacb954c1e014a6065fd0378f10521ed8`
- 检查命令：
  ```bash
  git diff ce01d69d HEAD -- lib/utils/voice_billing_helper.dart
  ```
- 如果输出中出现 `_VoiceRecordingDialogState` 的变化（如阈值、守卫、调用顺序、新增提示），请同步到 `origin_voice_session.dart`，并把上面的基线更新为新的 commit。UI 文件无需改动。

---

## 十二、锁定币种（单币种纯净极简模式）

- **改造日期**：2026-11-02
- **第一性原理与设计依据**：
  为不使用多币种的用户提供纯粹、清爽的单币种记账体验：
  1. **设置页「货币与汇率」分组改造**：
     - 在「主币种」正下方新增「锁定币种」开关（`OriginSwitch`，由 `currencyLockedProvider` 驱动，本地持久化）；
     - 开启后：全软件隐藏货币符号（`¥`、`$`、`元`）、币种切换胶囊与多币种折算行；
     - 同分组下的「汇率管理」入口在开启后自动隐藏；
     - 「外观与偏好」分组下的「货币符号」开关自动联动隐藏。
  2. **记账与业务流程收敛**：
     - 记账抽屉隐藏金额左侧币种下拉选择胶囊与汇率折算行，强制使用账本基准币，不触发公网汇率拉取；
     - 账户新建与编辑表单隐藏「币种」选择行，新建账户自动锁定为账本币种；
     - 账本新建与编辑弹窗隐藏「本位币」设置行，新建账本自动继承全局主币种；
     - 账户快捷设置隐藏「汇率管理」入口，账户选择列表移除币种代码前缀（如 `CNY · 活期存款` 净化为 `活期存款`）；
     - 资产看板、首页看板、报表看板隐藏货币单位与符号；
     - 搜索筛选隐藏原币/账本金额切换组；
     - 交易列表与 AI 记账卡片纯净展示金额数字，不含币种符号或折算副标题。
  3. **严格零上游冲突物理隔离**：
     - 业务状态管理与全部 UI 修改 100% 收敛在 `lib/custom_ui/` 目录下；
     - 对原作者文件的唯一修改仅为 `lib/utils/format_money.dart` 中的 `globalCurrencyLocked` 全局变量注入。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/utils/format_money.dart` | 声明 `globalCurrencyLocked` 并在 `formatDisplayAmount` 中加入锁定短路 | 若上游更新该文件，保留该变量与三目判断即可 |
| **02** | `lib/custom_ui/providers/amount_format_provider.dart` | 新增 `currencyLockedProvider` 与 SharedPreferences 持久化 | 定制目录纯增量代码 |
| **03** | `lib/custom_ui/pages/custom_mine_page.dart` | 「主币种」下方挂载「锁定币种」开关，锁定时隐藏「汇率管理」与「货币符号」| 定制目录纯增量代码 |
| **04** | `lib/custom_ui/pages/custom_transaction_sheet.dart` | 锁定时隐藏金额左侧选币胶囊、外币折算行，转账模式卡片隐藏币种标签，禁用汇率拉取 | 定制目录纯增量代码 |
| **05** | `lib/custom_ui/pages/custom_account_edit_page.dart` | 锁定时隐藏账户币种选择行与初始余额货币符号 | 定制目录纯增量代码 |
| **06** | `lib/custom_ui/pages/custom_ledgers_page.dart` | 锁定时隐藏新建/编辑账本弹窗中的本位币选择行 | 定制目录纯增量代码 |
| **07** | `lib/custom_ui/pages/custom_accounts_page.dart` | 锁定时隐藏资产看板单位与账户卡片货币符号 | 定制目录纯增量代码 |
| **08** | `lib/custom_ui/pages/custom_account_detail_page.dart` | 锁定时隐藏账户详情页货币符号、多币种折算行与币种代码指标 | 定制目录纯增量代码 |
| **09** | `lib/custom_ui/pages/custom_hidden_accounts_page.dart` | 锁定时隐藏隐藏账户列表中的货币符号 | 定制目录纯增量代码 |
| **10** | `lib/custom_ui/widgets/origin_dialog.dart` | 锁定时快捷菜单隐藏「汇率管理」，账户选择列表隐藏币种代码前缀 | 定制目录纯增量代码 |
| **11** | `lib/custom_ui/widgets/origin_bottom_sheet.dart` | 锁定时快捷菜单隐藏「汇率管理」，账户选择列表隐藏币种代码前缀 | 定制目录纯增量代码 |
| **12** | `lib/custom_ui/pages/custom_home_page.dart` | 锁定时首页收支看板隐藏货币单位与符号 | 定制目录纯增量代码 |
| **13** | `lib/custom_ui/widgets/custom_transaction_tile.dart` | 锁定时交易列表条目抑制币种符号与外币折算副标题 | 定制目录纯增量代码 |
| **14** | `lib/custom_ui/pages/custom_net_worth_trend_page.dart` | 锁定时净资产趋势隐藏货币单位与多币种折算注记 | 定制目录纯增量代码 |
| **15** | `lib/custom_ui/widgets/origin_analytics_content.dart` | 锁定时洞察看板隐藏货币单位与符号，趋势图隐藏单位 | 定制目录纯增量代码 |
| **16** | `lib/custom_ui/pages/custom_budget_page.dart` | 锁定时预算看板与列表隐藏货币符号 | 定制目录纯增量代码 |
| **17** | `lib/custom_ui/pages/custom_budget_edit_page.dart` | 锁定时预算添加与编辑表单隐藏货币符号 | 定制目录纯增量代码 |
| **18** | `lib/custom_ui/widgets/origin_search_filter_sheet.dart` | 锁定时搜索筛选弹窗隐藏原币/账本金额切换组 | 定制目录纯增量代码 |
| **19** | `lib/custom_ui/widgets/custom_search_results.dart` | 锁定时搜索结果摘要与列表隐藏货币符号 | 定制目录纯增量代码 |
| **20** | `lib/custom_ui/widgets/ai/origin_bill_card.dart` | 锁定时 AI 记账卡片纯净展示金额数字，不含币种符号 | 定制目录纯增量代码 |
| **21** | `lib/custom_ui/pages/custom_category_detail_page.dart` | 锁定时隐藏货币符号、币种代码与多币种提示条 | 定制目录纯增量代码 |
| **22** | `lib/custom_ui/widgets/custom_tag_detail_sections.dart` | 锁定时隐藏货币符号与多币种提示条 | 定制目录纯增量代码 |
| **23** | `test/custom_ui/currency_locked_test.dart` | 锁定币种开关状态流、持久化与金额格式化专项验收测试套件 | 定制目录纯增量代码 |

### 2. Diff 备查（`lib/utils/format_money.dart`）
```dart
<<<< 上游原版:
/// 全局货币符号显示开关（默认 false：不显示 ¥ / $ 等货币符号；开启为 true：显示货币符号）
bool globalShowCurrencySymbol = false;

/// Shared by App bindings and AmountText. Currency selection, locale and
/// compact preference are resolved by the host; presentation packages only
/// receive the final display text.
String formatDisplayAmount(double value,
    {String? currencyCode,
    bool? showCurrency,
    bool useCompactFormat = false,
    bool isChineseLocale = true,
    bool signed = true,
    int decimals = 2,
    bool? useThousandSeparator}) {
  final shouldShowCurrency = showCurrency ?? globalShowCurrencySymbol;
==== 本地定制:
/// 全局货币符号显示开关（默认 false：不显示 ¥ / $ 等货币符号；开启为 true：显示货币符号）
bool globalShowCurrencySymbol = false;

/// 全局锁定币种开关（默认 false：未锁定；开启为 true：强制隐藏全软件货币符号与多币种标记）
bool globalCurrencyLocked = false;

/// Shared by App bindings and AmountText. Currency selection, locale and
/// compact preference are resolved by the host; presentation packages only
/// receive the final display text.
String formatDisplayAmount(double value,
    {String? currencyCode,
    bool? showCurrency,
    bool useCompactFormat = false,
    bool isChineseLocale = true,
    bool signed = true,
    int decimals = 2,
    bool? useThousandSeparator}) {
  final shouldShowCurrency = globalCurrencyLocked ? false : (showCurrency ?? globalShowCurrencySymbol);
>>>>
```

---

## 六、冷启动速度极致优化与后台任务错峰调度

- **修改日期**：2026-11-03
- **优化原则**：遵循第一性原理（冷启动核心目标为以百毫秒级速度让用户看到首屏并能交互），消除非必要阻塞与并发争抢。
- **改动收敛控制**：核心非增量改动仅在 `lib/main.dart`（挂载接触面），主要定制逻辑集中在 `lib/custom_ui/pages/custom_splash_page.dart`，100% 保持上游平滑可 Rebase。

### 1. 涉及文件清单与架构角色

| 序号 | 文件路径 | 架构角色 | 变更性质 | 冲突排查与维护指引 |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `lib/main.dart` | 入口挂载点 | 极小侵入（仅 3 处调度优化） | 若上游更新 `main.dart`，核对 `unawaited(_initializeAppMode)`、`_runDeferredBackgroundTasks` 阶梯延迟与 `_updateWidgetOnStart` 延时 |
| **02** | `lib/app.dart` | 主路由/Tab 挂载点 | 极小侵入（仅 4 行代码：Tab 按需懒加载） | 若上游更新 `lib/app.dart`，保留 `_activatedTabs` 集合并在 `IndexedStack` 中按需装载页面 |
| **03** | `lib/custom_ui/pages/custom_splash_page.dart` | 定制启动页与预加载 Provider | 定制目录纯增量代码 | 引入流水优先极速放行通道，Rebase 零冲突 |
| **04** | `test/widgets/custom_splash_page_test.dart` | 自动化测试套件 | 测试代码 | 运行 `flutter test test/widgets/custom_splash_page_test.dart` 保证无回归 |

---

### 2. 代码行级 Diff 备查

#### (1) `lib/main.dart`: `main()` 内部 `_initializeAppMode` 改为非阻塞异步调用
```dart
<<<< 上游原版 / 优化前:
  // 初始化应用模式（从 SharedPreferences 读取并设置到 appModeProvider）
  await _initializeAppMode(container);
==== 本地定制 / 优化后:
  // 初始化应用模式（从 SharedPreferences 异步读取，不阻塞首帧挂载）
  unawaited(_initializeAppMode(container));
>>>>
```

#### (2) `lib/main.dart`: `_runDeferredBackgroundTasks` 引入三阶段阶梯式错峰调度
```dart
<<<< 上游原版 / 优化前:
Future<void> _runDeferredBackgroundTasks(ProviderContainer container) async {
  // 初始化时区
  try {
    NotificationFactory.initializeTimeZone();
  ...
==== 本地定制 / 优化后:
Future<void> _runDeferredBackgroundTasks(ProviderContainer container) async {
  // 错峰阶段一：延后 2.5 秒，让首屏挂载、关键帧渲染与进场动画彻底完成并稳定
  await Future.delayed(const Duration(milliseconds: 2500));
  ...
  // 错峰阶段二：延后至 5 秒后，再注册小组件回调、恢复截图监听与图片分享
  await Future.delayed(const Duration(milliseconds: 2500));
  ...
  // 错峰阶段三：延后至 8 秒后，再执行一次性磁盘孤立文件 GC
  await Future.delayed(const Duration(seconds: 3));
  await _runOrphanFileGcOnce(container);
>>>>
```

#### (3) `lib/main.dart`: `_updateWidgetOnStart` 小组件渲染避开首屏交互期
```dart
<<<< 上游原版 / 优化前:
  void _updateWidgetOnStart(ProviderContainer container) async {
    try {
      // 延后 1.5 秒执行
      await Future.delayed(const Duration(milliseconds: 1500));
==== 本地定制 / 优化后:
  void _updateWidgetOnStart(ProviderContainer container) async {
    try {
      // 延后 4 秒执行，优先让首屏关键帧与用户首次浏览操作完成，避免主线程发生离屏截图与 SQLite 争抢
      await Future.delayed(const Duration(seconds: 4));
>>>>
```

#### (4) `lib/main.dart`: `_initializeAppMode` 消除冷启动多余的 SharedPreferences 磁盘持久化
```dart
<<<< 上游原版 / 优化前:
    await container.read(appModeProvider.notifier).switchMode(mode);
==== 本地定制 / 优化后:
    final currentMode = container.read(appModeProvider);
    if (currentMode != mode) {
      container.read(appModeProvider.notifier).state = mode;
    }
>>>>
```

#### (5) `lib/app.dart`: Tab 页面按需懒加载（Lazy Load Tabs，消除启动瞬时 4 页面并发建树与查库）
```dart
<<<< 上游原版 / 优化前:
class _BeeAppState extends ConsumerState<BeeApp> ... {
  final _pages = const [ ... ];
  ...
  body: IndexedStack(
    index: idx,
    children: [
      for (var i = 0; i < _pages.length; i++)
        TickerMode(enabled: i == idx, child: _pages[i]),
    ],
  ),
==== 本地定制 / 优化后:
class _BeeAppState extends ConsumerState<BeeApp> ... {
  final _pages = const [ ... ];
  // 仅在首次被访问时才实例化挂载对应 Tab
  final Set<int> _activatedTabs = {0};
  ...
  final idx = ref.watch(bottomTabIndexProvider);
  _activatedTabs.add(idx);
  ...
  body: IndexedStack(
    index: idx,
    children: [
      for (var i = 0; i < _pages.length; i++)
        TickerMode(
          enabled: i == idx,
          child: _activatedTabs.contains(i)
              ? _pages[i]
              : const SizedBox.shrink(),
        ),
    ],
  ),
>>>>
#### (6) 原生启动屏消除纯白闪屏（Android `launch_background.xml` 与 iOS `LaunchImage`）
```xml
<<<< 上游原版 / 优化前:
<!-- Android launch_background.xml: bitmap 被注释，仅留白背景 -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <!-- <item>
        <bitmap android:gravity="center" android:src="@mipmap/launch_image" />
    </item> -->
</layer-list>
==== 本地定制 / 优化后:
<!-- Android launch_background.xml: 激活居中蓝盒 Logo，点击第 0 毫秒即展示品牌画面 -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <item android:width="88dp" android:height="88dp" android:gravity="center">
        <bitmap android:gravity="center" android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
<!-- iOS LaunchImage: 用蓝盒 Logo 替换原版 68 字节的 1x1 纯透明空图片 -->
>>>>
```

---

### 3. 后续上游更新（Git Rebase）标准操作指南

当原作者（`upstream/main`）更新了代码，需要合入到定制分支时，请严格按以下步骤操作：

#### 步骤 1：拉取上游最新提交并 Rebase
```bash
# 1. 确保工作区干净，切换到 main 分支同步上游
git checkout main
git pull upstream main
git push origin main

# 2. 切换到定制分支并进行变基
git checkout custom-ui-v4
git rebase main
```

#### 步骤 2：若遇到 `lib/main.dart` 冲突的秒级处理方案
因为所有 UI 代码都在 `lib/custom_ui/`，**99% 的文件会自动通过**。若 `lib/main.dart` 提示冲突：
1. 打开 `lib/main.dart`，寻找 `<<<<<<< HEAD` 冲突块；
2. **黄金原则**：
   - 保留上游新增加的业务 Provider 或路由配置；
   - 将模式加载保持为 `unawaited(_initializeAppMode(container));`；
   - 保持后台任务 `_runDeferredBackgroundTasks` 里的分步 `await Future.delayed` 延时（2.5s / 2.5s / 3s）；
   - 保持 `_updateWidgetOnStart` 延时为 `const Duration(seconds: 4)`；
   - 保持 `home: _getHomePage(initState, ref)` 挂载到 `CustomAppStartupGate` 与 `CustomHomeStartupGate`。
3. 解决冲突后执行：
   ```bash
   git add lib/main.dart
   git rebase --continue
   ```

#### 步骤 3：验证与回归检查
合入完成后，运行以下三道检查确保安全：
```bash
# 1. 语法与静态检查
flutter analyze

# 2. 启动与核心测试用例
flutter test test/widgets/custom_splash_page_test.dart

# 3. 编译运行验证
flutter run -d macos  # 或 -d chrome / 连接真机
```

---

## 七、全局明细显示规范统一（资产、分类、标签、搜索与首页明细彻底对齐）

- **修改日期**：2026-11-03
- **优化原则**：
  - 遵循第一性原理：交易流水核心四要素（支出名称、备注、金额、银行卡）在全应用所有场景下具有唯一且统一的呈现语义。
  - 单一真实来源（SSOT）：以 `OriginTransactionItem` 为全局唯一流水条目渲染引擎，彻底移除对上游旧版 `TransactionListItem` 的依赖。
  - 零侵入保证：改造完全收敛在 `lib/custom_ui/` 内部，上游核心文件零接触，保证 Pull / Rebase 零冲突。

### 1. 涉及文件清单与架构角色

| 序号 | 文件路径 | 架构角色 | 变更性质 | 维护与对齐指引 |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/widgets/origin_transaction_item.dart` | 全局统一明细条目渲染引擎 | 增量能力增强 | 增强 `transferDirection`（资产单卡流向正负号与颜色判断）、`isSelectionMode`/`isSelected`（批量模式复选框），并自动联动全局 `hideAmountsProvider` |
| **02** | `lib/custom_ui/widgets/custom_transaction_tile.dart` | 通用流水数据适配层 | 重构统一 | 彻底解耦上游旧版 `TransactionListItem`，直接消费 `OriginTransactionItem`，使消费此组件的二级流水全部继承明细规范 |
| **03** | `lib/custom_ui/pages/custom_account_detail_page.dart` | 资产管理详情页 | UI排版优化 | 移除多余内边距（贴合 16dp 规范），引入优雅的跨日小分组标签与动态分割线缩进（跨日全宽，日内 56dp） |
| **04** | 关联受益页面（`CustomCategoryDetailPage`、`CustomTagDetailSections`、`CustomSearchResults`） | 二级流水页面 | 自然统一 | 经由 `CustomTransactionTileBinding` 一并实现支出名称、备注、金额、银行卡与账户色彩的全局统一 |

---

## 八、收支颜色方案全局联动与统一接入（跟随设置动态变化）

- **修改日期**：2026-11-03
- **优化原则**：
  - 第一性原理：金融流水数字的红绿语义必须严格忠于用户的个人习惯与设置选择（红涨绿跌 vs 绿涨红跌）。
  - 单一真实来源（SSOT）：在 `OriginTokens` 中封装 `incomeColor` 与 `expenseColor` 解析方法，集中读取 `incomeExpenseColorSchemeProvider`。
  - 全场景一致性：不仅是单笔流水条目，包括首页吸顶月度看板、日小计、搜索汇总、AI 记账账单卡片与资产差额调整，全部接入统一的收支配色体系。

### 1. 涉及文件清单与架构角色

| 序号 | 文件路径 | 架构角色 | 变更性质 | 维护与对齐指引 |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/styles/origin_tokens.dart` | 色彩系统 Token | 核心支持 | 新增 `incomeColor`、`expenseColor`、`resolveIncomeColor` 与 `resolveExpenseColor`，适配暗黑/亮色与用户设置 |
| **02** | `lib/custom_ui/widgets/origin_transaction_item.dart` | 流水条目组件 | 动态色彩接入 | 金额由原先的写死黑色与橙色，改为实时解析用户收支颜色方案；单卡转账流向同步跟随 |
| **03** | `lib/custom_ui/pages/custom_home_page.dart` | 首页看板 | 动态色彩接入 | 吸顶月份统计栏中的支出和收入数字接入动态色彩 |
| **04** | `lib/custom_ui/widgets/origin_transaction_feed.dart` | 首页流水流 | 动态色彩接入 | 每日头部小计（`支... 收...`）按收支配色高亮展示 |
| **05** | `lib/custom_ui/widgets/custom_search_results.dart` | 搜索流水与汇总 | 动态色彩接入 | 修复搜索结果顶部卡片写死 Red/Green 导致模式反转的隐患，接入动态配色 |
| **06** | `lib/custom_ui/pages/custom_account_edit_page.dart` | 资产编辑页 | 动态色彩接入 | 账户余额调整产生的差额数字根据收支配色动态着色 |
| **07** | `lib/custom_ui/widgets/ai/origin_bill_card.dart` | AI 账单卡片 | 动态色彩接入 | AI 记账生成的卡片金额颜色动态跟随收支配色方案 |

---

## 九、局域网自建服务离线记账卡顿根治（Local-First 本地优先与网络超时韧性）

- **修改日期**：2026-11-03
- **问题根因**：自建局域网服务端用户在离家/断开 Wi-Fi 情况下，本地 Access Token 过期后记账，主流程被 `TxAuthorService` 中的 `currentUser` 阻塞，触发串行网络刷新与重登，且底层 HTTP 缺乏超时机制，导致死等操作系统 60~75 秒 TCP 握手超时。
- **优化原则**：
  - 第一性原理（Local-First）：记账本质是本地 SQLite 插入，必须 0 毫秒秒级落库，绝不能被任何远端鉴权或网络副作用阻塞。
  - 纯本地只读：以本地已持久化 Session 中的 `currentUserId` 替代网络连网鉴权。
  - 网络韧性（Resilience）：为底层 HTTP 通信补齐超时时限，防止局域网断网时无限挂起。

### 1. 涉及文件清单与架构角色

| 序号 | 文件路径 | 架构角色 | 变更性质 | 维护与对齐指引 |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `lib/services/data/tx_author_service.dart` | 交易作者回填服务 | 纯本地化改造 | 移除阻塞主事务的 `currentUser` 异步远程鉴权，改为纯本地内存读取 `cloud.currentUserId` |
| **02** | `packages/flutter_cloud_sync/lib/src/providers/beecount_cloud_provider.dart` | 云同步通信 Provider | 稳定性增强 | 暴露 `currentUserId` 同步只读属性，并为所有 HTTP 请求配置合理的超时控制（5~60秒） |

---

## 十、全应用空状态（Empty State）规范统一与操作层级收敛

- **修改日期**：2026-11-03
- **问题根因**：
  1. **位置高低不一（有的偏上、有的偏下）**：
     - 标签页（`CustomTagManagePage`）等将空状态置于 `ListView` 中，失去垂直高度约束，退化为贴顶偏上；
     - 资产页（`CustomAccountsPage`）由于顶部大标题栏（84dp+）与底部浮动导航栏（80dp+）的双重挤压，普通 `Center` 未做视口避让与黄金中心补偿，导致视觉偏下坠底；
  2. **交互层级混乱与按钮多重冲突**：
     - 标签管理页同时在空状态中间展示“生成默认标签”，右上角菜单内存在“添加标签”与“生成默认标签”，底部又常驻“新增标签”胶囊大按钮，三处操作冲突重叠，提示语“点击右上角添加标签”与底部按钮矛盾。
- **优化原则**：
  - **组件化沉淀（SSOT）**：新建 `OriginEmptyState` 作为全局标准空状态组件（80dp 圆形浅色底座 + 40dp 线性图标 + 16sp SemiBold 标题 + 13sp 辅助说明），全系统统一视觉语言；
  - **黄金视觉居中**：通过 `LayoutBuilder` 与视口计算，根据页面结构自适应避让底部导航栏（`bottomSpacing`）并施加黄金视觉偏置（`visualOffset`），使空状态稳居人眼视线舒适区；
  - **操作层级清晰**：
    - 主操作：保留底部唯一的常驻置底主按钮（如“新增标签”、“新建分类”）；
    - 扩展功能：收纳“生成默认标签”、“分享”、“导入”至右上角更多菜单（`OriginMoreButton`），剔除重复添加入口；
    - 空状态中间只做轻量、精致的引导，杜绝冗余重复按钮。

### 1. 涉及文件清单与架构角色

| 序号 | 文件路径 | 架构角色 | 变更性质 | 维护与对齐指引 |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `lib/custom_ui/widgets/origin_empty_state.dart` | 全局标准空状态组件 | 新增核心组件 | vivo OriginOS 质感圆形底座、标题排版与自适应视口居中引擎 |
| **02** | `lib/custom_ui/pages/custom_tag_manage_page.dart` | 标签管理页面 | 体验与交互收敛 | 移除右上角与底部重复的“添加标签”，将“生成默认标签”置于右上角首位；空状态居中且不再堆砌重复按钮 |
| **03** | `lib/custom_ui/pages/custom_accounts_page.dart` | 资产总览管理页面 | 居中与组件统一 | 替换原手写 Column，增加底栏 96dp 避让与视觉向上修正，彻底消除“偏下”坠底问题 |
| **04** | `lib/custom_ui/pages/custom_category_manage_page.dart` | 分类管理页面 | 居中与去重 | 分类为空时采用 `OriginEmptyState` 居中展示，移除顶部 `BeeStatus` 内嵌的重复“新建分类”按钮 |
| **05** | `lib/custom_ui/pages/custom_ledgers_page.dart` | 账本管理页面 | 视觉规范升级 | 替换简陋居左单行文本，统一为带图标与提示引导的居中空状态 |
| **06** | `lib/custom_ui/pages/custom_hidden_accounts_page.dart` | 已隐藏账户页面 | 规范统一 | 替换页面内手写居中 Column，接入 `OriginEmptyState` |
| **07** | `lib/custom_ui/pages/custom_budget_page.dart` | 预算管理页面 | 规范沉淀统一 | 接入统一 `OriginEmptyState`，保持代码简洁统一 |
| **08** | `lib/custom_ui/pages/custom_calendar_page.dart` | 日历页面 | 紧凑型规范统一 | 当日无交易时接入紧凑型 `OriginEmptyState` |
| **09** | `lib/custom_ui/widgets/custom_search_results.dart` | 搜索流水组件 | 规范统一 | 搜索无结果时接入统一 `OriginEmptyState` |





