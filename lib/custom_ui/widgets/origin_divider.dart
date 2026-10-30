import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 发丝分割线 (OriginDivider)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md`：
/// 1. 厚度收敛为 1 物理像素（真机实测 0.5dp）；
/// 2. 日间 `#D9D9D9`，夜间 `#262626`；
/// 3. 默认缩进 16dp 或 20dp，与卡片文字左侧起点对齐，右侧贴边。
class OriginDivider extends StatelessWidget {
  final double startIndent;
  final double endIndent;
  final Color? color;
  final double thickness;

  const OriginDivider({
    super.key,
    this.startIndent = 16.0,
    this.endIndent = 0.0,
    this.color,
    this.thickness = OriginTokens.hairline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: startIndent, right: endIndent),
      height: thickness,
      color: color ?? OriginTokens.divider(context),
    );
  }
}
