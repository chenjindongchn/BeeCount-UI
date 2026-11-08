# AutoAccounting 适配集成与开源发布指南

本目录包含将 BeeCount 接入 [AutoAccountingOrg/AutoAccounting](https://github.com/AutoAccountingOrg/AutoAccounting) 所需的全部适配层代码。

---

## 一、集成到 AutoAccounting 步骤

### 1. 克隆 / Fork 官方仓库
```bash
git clone https://github.com/AutoAccountingOrg/AutoAccounting.git
cd AutoAccounting
git checkout -b feat/add-beecount-adapter
```

### 2. 放置适配器代码
将本目录下的 `BeeCountAdapter.kt` 复制到 AutoAccounting 项目的适配器目录下：
```bash
cp BeeCountAdapter.kt app/src/main/java/net/ankio/auto/adapter/
```

### 3. 在管理器中注册
打开 `app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt`：
在 `adapters` 列表中追加一行：
```kotlin
BeeCountAdapter(),
```
（具体修改方式可参考同目录下的 `AppAdapterManager_patch.kt`）

### 4. 本地编译与验证
使用 Android Studio 打开 AutoAccounting 工程，编译生成 Debug APK 安装到测试手机上：
1. 打开 AutoAccounting -> 设置 -> 选择记账软件 -> 选择 **BeeCount**。
2. 授予无障碍、通知读取权限（或 LSPosed 模块激活）。
3. 进行一笔模拟支付或接收短信，确认 BeeCount 会自动生成对应账单。

---

## 二、独立开源与发布方案

如果你希望**独立发布专用的“BeeCount 自动记账”助手**（独立 APK）：
1. 在 GitHub 上 Fork AutoAccounting 到你们的组织/个人账号下。
2. 默认选择的目标软件可设为 `BeeCount`。
3. 利用仓库提供的 GitHub Actions 脚本（参见 `github_workflows/build_auto_accounting.yml`），每次打 Release Tag 时自动打包出专用的独立 APK。
4. 在 BeeCount 软件内的设置页中提供引导：“下载 BeeCount 自动记账伴侣”。

---

## 三、向上游 AutoAccountingOrg 提交 PR

当本地验证稳定后，建议向官方仓库提交 Pull Request：
1. 提交 Commit：
   ```bash
   git commit -m "feat(adapter): add BeeCount app adapter support"
   ```
2. 推送至个人 Fork 仓库并创建 PR：
   - 标题：`feat: 支持 BeeCount 开源记账软件自动同步`
   - 说明：介绍 BeeCount 的 URL Scheme 支持情况及已测功能。
3. 官方合并后，所有安装原版 AutoAccounting 的用户都将直接支持同步到 BeeCount，扩大软件生态影响力。
