import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'gemini_voice_ribbons.dart';

/// 灵动光丝声纹区域（去除突兀塑料感白边与硬胶囊，与背景流光融为一体）
class GeminiVoiceIsland extends StatelessWidget {
  final double amplitude;
  final GeminiRibbonMode mode;
  final bool showHoldHint;
  final String holdHintLabel;
  final bool pressed;
  final bool reduceMotion;
  final VoidCallback? onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  static const double height = 54;
  static const double width = 220;

  const GeminiVoiceIsland({
    super.key,
    required this.amplitude,
    required this.mode,
    required this.showHoldHint,
    required this.holdHintLabel,
    this.pressed = false,
    this.reduceMotion = false,
    this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = Colors.white;

    // 通透水润的流体舞台（绝无硬边框，微弱的高光光晕自然融于背景）
    final body = AnimatedScale(
      scale: pressed ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              // 极度轻透的柔和微光底色，消除与背景的割裂
              color: isDark
                  ? Colors.white.withValues(alpha: pressed ? 0.14 : 0.06)
                  : Colors.white.withValues(alpha: pressed ? 0.35 : 0.20),
              borderRadius: BorderRadius.circular(height / 2),
              // 柔和微光漫射，而非实线描边
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: showHoldHint
                  ? Row(
                      key: const ValueKey('hint'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 20,
                          color: fgColor.withValues(alpha: 0.95),
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 6),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            holdHintLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: fgColor,
                              shadows: const [
                                Shadow(
                                  color: Color(0x80000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : GeminiVoiceRibbons(
                      key: const ValueKey('ribbons'),
                      amplitude: amplitude,
                      mode: mode,
                      reduceMotion: reduceMotion,
                    ),
            ),
          ),
        ),
      ),
    );

    if (onHoldStart != null || onHoldEnd != null) {
      return Listener(
        onPointerDown: (_) => onHoldStart?.call(),
        onPointerUp: (_) => onHoldEnd?.call(),
        onPointerCancel: (_) => onHoldEnd?.call(),
        child: body,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
