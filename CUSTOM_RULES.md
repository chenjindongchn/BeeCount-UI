# BeeCount 个性化定制开发铁律（保持上游可平滑更新）

> 本文件是本项目的**第一准则**。无论由人类开发者、还是任何 AI 辅助工具（Antigravity、Cursor、Windsurf、Claude Code、Copilot 等）进行代码修改，**在修改任何文件前必须强制通读并严格遵守本规范**。

---

## 核心设计哲学（第一性原理）

本项目的本质是：**“借用原作者强大的本地优先记账、数据库、同步及 AI 能力，仅定制前端视觉与交互交互体验”**。
为了让原作者未来的所有更新（Bug 修复、新功能、数据库同步演进）能够近乎**零冲突、零痛点**地合入，一切改动遵循以下五大铁律：

---

## 规则 1：物理隔离原则（严禁原位涂改）

1. **绝对禁止**在原作者的页面目录（`lib/pages/`）中直接修改现有 Widget 界面。
2. **所有**个性化开发的页面、组件、样式、动画，必须放在专属目录：
   - 页面：`lib/custom_ui/pages/`
   - 组件：`lib/custom_ui/widgets/`
   - 样式/主题：`lib/custom_ui/styles/`
3. 任何新建文件都必须位于 `lib/custom_ui/` 内，原作者仓库中根本不存在这个目录，因此从源头上消除 99% 的 Git 文件合并冲突。

---

## 规则 2：逻辑纯复用原则（UI 只做数据消费者）

1. **不重写逻辑**：原项目所有业务状态均由 **Riverpod**（`lib/providers/`）管理。
2. 自定义页面（继承 `ConsumerWidget` 或 `ConsumerStatefulWidget`）**只负责消费状态**：
   - 读取数据：使用 `ref.watch(xxxProvider)`；
   - 触发操作：调用 `ref.read(xxxProvider.notifier).action()`；
3. 严禁把业务逻辑私自拷贝一份到自定义目录，必须直接引用原有的 Provider。

---

## 规则 3：极简接触面原则（Minimal Surface Area）

1. 与原项目官方文件的接触面，严格收敛于**挂载入口（通常仅为 `lib/app.dart` 或路由配置文件）**。
2. 在原项目文件上的改动量，必须控制在 **极简范围（仅 1~3 行代码）**：
   ```dart
   // 修改前（原版）：
   // import 'pages/main/home_page.dart';
   // home: HomePage(),

   // 修改后（自定义）：
   import 'custom_ui/pages/custom_home_page.dart';
   // home: CustomHomePage(),
   ```
3. 绝不在原项目现存代码中穿插大段自定义代码。

---

## 规则 4：只读保护区（核心红线禁区）

以下区域属于**绝对只读保护区**，任何改动都会破坏原作者未来的版本演进：
1. **数据库层**：`lib/data/` 中的 Drift 表结构、Dao、迁移脚本。**严禁私自修改表字段**。
2. **同步协议层**：`lib/cloud/` 中的 WebDAV、S3、自建云协议、加解密算法。保持原汁原味。
3. **第三方库主版本**：除兼容当前运行环境所需的极微小版本放宽外，不随意增删重型三方库。

---

## 规则 5：Git 变基同步流（Rebase Only）

1. **`main` 分支神圣纯净**：
   - `main` 分支永远不产生任何本地自定义 commit。
   - `main` 分支仅用于从 `upstream/main`（原作者仓库）拉取更新。
2. **定制分支隔离**：
   - 所有工作必须在 `custom-ui`（或自定义分支）上进行。
3. **更新标准动作**：
   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   git checkout custom-ui
   git rebase main
   ```
   因绝大多数代码都在 `lib/custom_ui/`，Rebase 过程将极度平滑。
