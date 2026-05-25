import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Bordered section container with a title header.
class DetailGroup extends StatelessWidget {
  const DetailGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.gray800 : AppColors.green50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.gray700 : AppColors.green100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
