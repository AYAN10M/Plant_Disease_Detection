import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/detection_model.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.response,
    required this.result,
  });

  final DetectionApiResponse response;
  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    Color bg, border, fg;
    IconData icon;
    String title;

    switch (response.status) {
      case 'healthy':
        bg = AppColors.green600.withValues(alpha: 0.10);
        border = AppColors.green600.withValues(alpha: 0.35);
        fg = AppColors.green600;
        icon = Icons.check_circle_rounded;
        title = 'Healthy Plant, No disease detected!';
        break;
      case 'success':
        if (response.effectivelyHealthy) {
          bg = AppColors.green600.withValues(alpha: 0.10);
          border = AppColors.green600.withValues(alpha: 0.35);
          fg = AppColors.green600;
          icon = Icons.check_circle_rounded;
          title = 'Healthy Plant, No disease detected!';
        } else {
          bg = const Color(0xFF1565C0).withValues(alpha: 0.08);
          border = const Color(0xFF1565C0).withValues(alpha: 0.28);
          fg = const Color(0xFF1565C0);
          icon = Icons.biotech_rounded;
          title = result.diseaseName ?? 'Disease Detected';
        }
        break;
      case 'not_recognized':
        bg = const Color(0xFF6A1B9A).withValues(alpha: 0.08);
        border = const Color(0xFF6A1B9A).withValues(alpha: 0.30);
        fg = const Color(0xFF6A1B9A);
        icon = Icons.help_outline_rounded;
        title = 'Plant Not Recognised';
        break;
      case 'no_model':
        bg = const Color(0xFF1565C0).withValues(alpha: 0.08);
        border = const Color(0xFF1565C0).withValues(alpha: 0.30);
        fg = const Color(0xFF1565C0);
        icon = Icons.science_outlined;
        title = '${result.plantName} - No Disease Model Yet';
        break;
      case 'low_confidence':
        bg = const Color(0xFFD84315).withValues(alpha: 0.09);
        border = const Color(0xFFD84315).withValues(alpha: 0.35);
        fg = const Color(0xFFD84315);
        icon = Icons.warning_amber_rounded;
        title = 'Low Confidence - Retake Recommended';
        break;
      default:
        bg = const Color(0xFF1565C0).withValues(alpha: 0.08);
        border = const Color(0xFF1565C0).withValues(alpha: 0.28);
        fg = const Color(0xFF1565C0);
        icon = Icons.biotech_rounded;
        title = result.diseaseName ?? 'Disease Detected';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: fg, fontSize: 16)),
                if (response.message != null &&
                    response.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(response.message!,
                      style: TextStyle(
                          fontSize: 13, color: fg.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
