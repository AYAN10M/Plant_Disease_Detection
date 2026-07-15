import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/detection_model.dart';
import 'detail_group.dart';

class ScoreChart extends StatelessWidget {
  const ScoreChart({
    super.key,
    required this.title,
    required this.scores,
    required this.winnerName,
    this.isDisease = false,
  });

  final String title;
  final List<ConfidenceScore> scores;
  final String winnerName;
  final bool isDisease;

  @override
  Widget build(BuildContext context) {
    final sorted = List<ConfidenceScore>.from(scores)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return DetailGroup(
      title: title,
      children: sorted.map((score) {
        final pct = score.confidence * 100;
        final isWinner = score.name.toLowerCase() == winnerName.toLowerCase();
        final barColor = isWinner
            ? (pct >= 80
                ? AppColors.green600
                : pct >= 55
                    ? const Color(0xFFF9A825)
                    : const Color(0xFFD84315))
            : Colors.grey.shade400;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      score.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isWinner ? FontWeight.w700 : FontWeight.w500,
                        color: isWinner ? barColor : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score.confidence,
                  minHeight: 8,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
