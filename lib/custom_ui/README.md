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

## OriginUI 核心交互规划与范式
1. **页面核心操作置底常驻（Bottom CTA）**：
   - 页面级核心操作默认采用**页面置底大胶囊按钮**形式（挂载在 `OriginScaffold` 的 `bottomNavigationBar`），禁止混在滚动列表内部。
   - 尺寸与几何真值统一：高度 46dp (`OriginTokens.buttonHeight`)，圆角 23dp (`OriginTokens.buttonRadius`)，外边距水平 20dp、垂直 12dp。
2. **对话框规范**：
   - 严禁使用原生 `AlertDialog`，统一使用 `OriginDialog`（贴底居中悬浮、30dp 大圆角、软键盘避让与竖排双胶囊）。
