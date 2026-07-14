import 'package:flutter/material.dart';

import '../models/detection_model.dart';

/// Displays pipeline architecture and per-stage latency metrics
/// with animated progress bars and colour-coded timing.
class PerformanceCard extends StatelessWidget {
  const PerformanceCard({super.key, required this.result});

  final DetectionResult result;

  // Colour thresholds (milliseconds)
  static const double _fastMs   = 200;
  static const double _mediumMs = 500;

  Color _latencyColor(double ms) {
    if (ms <= 0) return Colors.grey;
    if (ms < _fastMs) return const Color(0xFF43A047);    // green
    if (ms < _mediumMs) return const Color(0xFFFFA000);  // amber
    return const Color(0xFFE53935);                       // red
  }

  String _latencyLabel(double ms) {
    if (ms <= 0) return '—';
    if (ms < 1000) return '${ms.toStringAsFixed(1)} ms';
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalMs = result.totalLatencyMs;
    // For progress bar proportions — avoid divide-by-zero
    final maxMs = totalMs > 0 ? totalMs : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE0E4EA),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Pipeline Performance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Total latency pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _latencyColor(totalMs).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _latencyLabel(totalMs),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _latencyColor(totalMs),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Architecture row ───────────────────────────────────────
          Row(
            children: [
              _ArchChip(
                label: 'S1',
                model: result.stage1Model,
                color: const Color(0xFF5C6BC0),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              _ArchChip(
                label: 'S2',
                model: result.stage2Model,
                color: const Color(0xFF26A69A),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Stage 1 bar ────────────────────────────────────────────
          _LatencyRow(
            icon: Icons.eco_rounded,
            label: 'Plant ID',
            ms: result.stage1LatencyMs,
            fraction: result.stage1LatencyMs / maxMs,
            color: _latencyColor(result.stage1LatencyMs),
          ),
          const SizedBox(height: 8),

          // ── Stage 2 bar ────────────────────────────────────────────
          _LatencyRow(
            icon: Icons.bug_report_rounded,
            label: 'Disease',
            ms: result.stage2LatencyMs,
            fraction: result.stage2LatencyMs / maxMs,
            color: _latencyColor(result.stage2LatencyMs),
          ),
          const SizedBox(height: 8),

          // ── Preprocessing bar ──────────────────────────────────────
          _LatencyRow(
            icon: Icons.image_rounded,
            label: 'Preprocess',
            ms: result.preprocessingLatencyMs,
            fraction: result.preprocessingLatencyMs / maxMs,
            color: _latencyColor(result.preprocessingLatencyMs),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ArchChip extends StatelessWidget {
  const _ArchChip({
    required this.label,
    required this.model,
    required this.color,
  });

  final String label;
  final String model;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            model,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}


class _LatencyRow extends StatelessWidget {
  const _LatencyRow({
    required this.icon,
    required this.label,
    required this.ms,
    required this.fraction,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double ms;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        // Animated bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            ms > 0 ? '${ms.toStringAsFixed(0)} ms' : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
