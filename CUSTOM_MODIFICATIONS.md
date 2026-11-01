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

## 八、全软件日期与时间选择组件（OriginUI 统一桥接与深度改造）

- **改造日期**：2026-11-01
- **第一性原理与设计初衷**：
  原作者在全工程中（包括记账全屏页 `AmountEditorSheet`、日历打卡页 `CalendarPage`、账单搜索过滤 `TransactionSearchFilter` 等）均通过 `wheel_date_picker.dart`、`wheel_time_picker.dart` 和 `detail_period_controls.dart` 统一分发弹窗。
  为了在不破坏上游任何业务逻辑的前提下，彻底消除原版黄色粗糙滚轮及 Flutter 原生 Material 表盘时钟，让全软件**所有新老记账与统计入口 100% 统一为 vivo OriginOS 风格**：
  1. 在 `lib/custom_ui/widgets/` 建立自研套件（`OriginWheelPicker`、`OriginDatePicker`、`OriginTimePicker`、`OriginDateTimePicker`、`OriginPeriodPicker`）；
  2. 将 3 个上游基础适配器函数极简桥接至 OriginUI，保持入参出参 100% 一致。

### 1. 修改文件清单与冲突排查指引

| 序号 | 所在源码位置 | 修改内容 | 冲突排查指引 |
| :--- | :--- | :--- | :--- |
| **01** | `lib/pages/shared/pickers/wheel_date_picker.dart` | `showWheelDatePicker` 转发至 `showOriginDatePicker`；`showWheelDateTimePicker` 转发至一体化 `showOriginDateTimePicker` | 若上游更新该文件，保留对 `showOriginDatePicker` 和 `showOriginDateTimePicker` 的极简调用即可 |
| **02** | `lib/pages/shared/pickers/wheel_time_picker.dart` | `showWheelTimePicker` 转发至 `showOriginTimePicker` | 保留转发调用即可 |
| **03** | `lib/pages/shared/resources/widgets/detail_period_controls.dart` | `showResourcePeriodPicker` 转发至 `showOriginPeriodPicker` | 保留转发调用即可 |
| **04** | `lib/pages/transaction/recurring/bindings/recurring_editor_pickers.dart` | `showRecurringEditorDatePicker` 转发至 `showOriginDatePicker` | 保留转发调用即可 |
| **05** | `lib/pages/settings/reminder_settings_page.dart` | `_time()` 时间设置调用 `showOriginTimePicker` | 保留调用即可 |


