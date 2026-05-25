import 'package:flutter/material.dart';

/// Bold label + muted value row for structured data display.
class DetailLine extends StatelessWidget {
  const DetailLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Builder(
          builder: (ctx) => Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: valueColor ??
                  Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
