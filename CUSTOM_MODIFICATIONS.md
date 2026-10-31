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
