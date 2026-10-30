import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';
import 'origin_divider.dart';
import 'origin_card.dart';

/// vivo OriginOS 设置项行模型
class OriginSettingItem {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showArrow;

  const OriginSettingItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showArrow = true,
  });
}

/// vivo OriginOS 设置分组卡片 (OriginSettingGroup)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md` 与 `24`:
/// 1. 圆角 12dp，外侧横向边距 20dp；
/// 2. 日间纯白 #FFFFFF，夜间纯暗卡片 #202020；
/// 3. 行间使用 0.5dp 发丝分割线（#D9D9D9 / #262626），缩进与文字对齐；
/// 4. 尾部信息使用细线右箭头，层级清晰。
class OriginSettingGroup extends StatelessWidget {
  final List<OriginSettingItem> items;
  final EdgeInsetsGeometry? margin;

  const OriginSettingGroup({
    super.key,
    required this.items,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return OriginCard(
      margin: margin,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              OriginDivider(
                startIndent: items[i].leading != null ? 52.0 : 16.0,
                endIndent: 0,
              ),
            _OriginSettingTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _OriginSettingTile extends StatelessWidget {
  final OriginSettingItem item;

  const _OriginSettingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
        child: Row(
          children: [
            if (item.leading != null) ...[
              SizedBox(
                width: 24.0,
                height: 24.0,
                child: Center(child: item.leading!),
              ),
              const SizedBox(width: 12.0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.trailing != null) ...[
              item.trailing!,
              if (item.showArrow) const SizedBox(width: 4.0),
            ],
            if (item.showArrow && item.onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20.0,
                color: OriginTokens.textTertiary(context),
              ),
          ],
        ),
      ),
    );
  }
}
