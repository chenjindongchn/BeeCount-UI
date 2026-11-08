# BeeCount 与自动记账发行版本（Release）

本目录包含已完成完整代码审计与加固的正式发行版（Release）安装包。

## 安装包清单

| 文件名 | 类型 / 架构 | 体积 | SHA-256 校验码 | 适用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **`BeeCount-Release-Universal.apk`** | 正式发行版 (通用全架构) | 49 MB | `53e922b20d1123afbbbe7e37322404c6286e46064d13ee690d24079114bec28d` | 所有 Android 手机通用 |
| **`BeeCount-Release-arm64-v8a.apk`** | 正式发行版 (ARM64 优化) | 20 MB | `662eee5ea4130c08b771cdb85374a737a0a49fd0d1da6d12cc081ea3be39ab88` | 近年主流 Android 手机 (体积更轻小) |
| **`AutoAccounting-BeeCount-Release-v4.0.2.apk`** | 自动记账正式发行版 | 52 MB | `96ba57835621c6acadc011ed54dba62e0ab6a5ecd6c6d8762f4fdbb604f6e5a1` | 已内置 BeeCount 适配器 & 已关闭官方更新弹窗 |

---

## 关键特性与改动说明

### 1. BeeCount 发行版
* **包名**：`com.tntlikely.beecount`（正式版）
* **自动化记账接收增强**：
  * 支持 `beecount://add` 与 `beecount://publicapi/addbill` 两种协议；
  * 完美支持 `money` / `amount`、`0/1/2` 交易类型（支出/收入/转账）、`remark`、`account_name`、`target_account`、`time`、`auto_save`；
  * 分类多重容错（精确匹配 -> 模糊包含匹配 -> 默认分类自动兜底，并将原分类名称自动附入交易备注，零丢账）；
  * 账户安全映射（精确匹配 -> 模糊匹配 -> `upsertAccount` 安全创建，杜绝重名异常）；
  * 冷启动防丢队列（应用未就绪时暂存，Splash 结束后自动写入）。

### 2. AutoAccounting 发行版
* **包名**：`net.ankio.auto`
* **内置 BeeCount 适配器**：
  * 支持自动记账目标应用直接选择 **BeeCount**；
  * 全量交易类型识别映射（消费、转账、还款、借入、报销等）；
  * 禁用官方更新检测弹窗（防止误更新导致官方原版覆盖掉适配器）；
  * 保留规则库自动云同步（确保微信、支付宝及银行规则持续保持最新）。

---

## ADB 一键安装命令（电脑端）

```bash
# 1. 查看设备连接
adb devices

# 2. 安装 BeeCount 发行版
adb install -r 自动记账/发行版本/BeeCount-Release-Universal.apk

# 3. 安装 自动记账 发行版
adb install -r 自动记账/发行版本/AutoAccounting-BeeCount-Release-v4.0.2.apk
```
