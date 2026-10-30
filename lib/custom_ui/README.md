# Custom UI 专属定制目录说明

该目录专门存放所有个性化、UI 改造的页面与组件，与原作者官方代码物理隔离。

## 目录结构
- `pages/`: 自定义的页面（例如 `custom_home_page.dart`，替代原作者的 `home_page.dart`）
- `widgets/`: 自定义的卡片、列表项、动画组件
- `styles/`: 自定义的颜色、圆角、阴影等样式 Token

## 核心解耦原则
1. **数据与逻辑**：直接通过 `ref.watch(xxxProvider)` 复用原作者在 `lib/providers/` 中定义好的 Riverpod 逻辑。
2. **挂载方式**：在 `lib/app.dart` 或路由表中将原页面指向本目录对应页面，原项目代码改动控制在极简（1~2行 import 和替换）。
3. **更新同步**：原作者代码更新时，在 `custom-ui` 分支执行 `git rebase main`，该目录文件永不冲突。
