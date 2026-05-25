import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Min confidence threshold slider with contextual guidance.
class ConfidenceSlider extends StatelessWidget {
  const ConfidenceSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value; // 0–100
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.green500;
    final bgColor = isDark ? AppColors.gray800 : AppColors.green50;
    final border = isDark ? AppColors.gray700 : AppColors.green100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Min Confidence',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${value.round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: 0.18),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.15),
              tickMarkShape:
                  const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor: accent.withValues(alpha: 0.4),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 20, // steps of 5%
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0%', '25%', '50%', '75%', '100%']
                .map((t) => Text(t,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _guidanceText,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String get _guidanceText {
    if (value < 20) return 'Very lenient — almost any image accepted';
    if (value < 40) return 'Lenient — accepts uncertain identifications';
    if (value < 60) return 'Balanced — recommended for most images';
    if (value < 80) return 'Strict — requires clear, well-lit photos';
    return 'Very strict — only high-quality photos pass';
  }
}
