# BeeCount 自动记账通信协议规范 (URL Scheme)

本文档定义了第三方自动化工具（如 **AutoAccounting / 自动记账**、Tasker、快捷指令、外部脚本）与 **BeeCount** 进行跨进程通信与记账数据交换的协议格式。

---

## 一、协议基地址 (Base URI)

BeeCount 支持两种格式的 Base URI，完全兼容原生规范与业界成熟规范（如钱迹 PublicAPI 规范）：

1. **原生标准格式**：
   `beecount://add`
2. **开放生态兼容格式**：
   `beecount://publicapi/addbill`

---

## 二、请求参数规范 (Query Parameters)

所有参数通过 URL Query 方式传递，字符串需做标准 URL 编码（UTF-8）。

| 参数名（原生推荐） | 兼容别名 | 类型 | 必填 | 说明 | 示例 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `amount` | `money` | Decimal | **是** | 账单金额，必须为大于 0 的数字 | `28.50` |
| `type` | - | String/Int | 否 | 交易类型：<br>• `expense` 或 `0`：支出（默认）<br>• `income` 或 `1`：收入<br>• `transfer` 或 `2`：转账 | `expense` 或 `0` |
| `category` | `cate_name` | String | 否 | 分类名称。<br>• 支持精确匹配与子分类匹配<br>• 支持模糊匹配<br>• 若未匹配到，自动兜底至当前账本首个分类，避免丢失账单 | `餐饮` 或 `交通出行` |
| `note` | `remark` | String | 否 | 账单备注 / 商户名称 | `星巴克咖啡` |
| `account` | `account_name` | String | 否 | 支出/收入账户名称。<br>若账户不存在，BeeCount 会自动创建对应账户 | `微信零钱` 或 `招商银行卡` |
| `to_account` | `target_account` | String | 否 | 转入账户名称（仅转账模式 `type=transfer` 或 `type=2` 生效）。<br>若账户不存在亦会自动创建 | `支付宝余额` |
| `date` | `time` | String | 否 | 交易时间（支持 ISO 8601 或 `yyyy-MM-dd HH:mm:ss`）。<br>缺省时使用当前系统时间 | `2026-11-04 12:30:00` |
| `tags` | - | String | 否 | 标签名称列表，多个标签用英文逗号 `,` 分隔 | `聚餐,报销` |
| `silent` | `auto_save` | Int/Bool | 否 | 是否静默保存：<br>• `1` 或 `true`：静默落库并仅弹出通知，不弹确认界面<br>• `0` 或 `false`：弹出常规记账提示（默认） | `1` |

---

## 三、调用示例

### 1. 模拟微信消费支出（自动静默入库）
```text
beecount://publicapi/addbill?money=35.00&type=0&cate_name=餐饮&account_name=微信零钱&remark=麦当劳午餐&auto_save=1
```
*或等价于原生格式：*
```text
beecount://add?amount=35.00&type=expense&category=餐饮&account=微信零钱&note=麦当劳午餐&silent=1
```

### 2. 模拟支付宝转账
```text
beecount://publicapi/addbill?money=500.00&type=2&account_name=招商银行卡&target_account=支付宝余额&remark=提现&auto_save=1
```

### 3. 模拟工资收入
```text
beecount://publicapi/addbill?money=15000.00&type=1&cate_name=职业薪资&account_name=工商银行卡&remark=月度工资&auto_save=1
```

---

## 四、Android 系统唤起方式 (ADB / Intent)

在 Android 系统中，第三方应用或系统可以通过隐式 Intent 调起：

```bash
adb shell am start -a android.intent.action.VIEW -d "beecount://publicapi/addbill?money=19.9&type=0&cate_name=餐饮&remark=自动记账测试&auto_save=1"
```
