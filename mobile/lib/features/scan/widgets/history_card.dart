import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/detection_model.dart';
import 'detail_group.dart';
import 'detail_line.dart';
import 'image_slider.dart';
import 'stage_confidence_bar.dart';

/// Expandable history entry with swipe-to-delete and inline delete button.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.entry,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onDelete,
    required this.onDismissConfirm,
  });

  final DetectionHistoryEntry entry;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onDelete;
  final Future<bool> Function() onDismissConfirm;

  String get _cardKey => entry.createdAt.toIso8601String();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isLowConf = entry.confidence < 0.55;
    final isHealthy =
        entry.isHealthy || entry.diseaseName?.toLowerCase() == 'healthy';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(_cardKey),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('Delete',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        confirmDismiss: (_) => onDismissConfirm(),
        onDismissed: (_) => onDelete(),
        child: Card(
          elevation: 0,
          child: ExpansionTile(
            key: PageStorageKey<String>('hist-$_cardKey'),
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                color: isDark ? AppColors.gray800 : AppColors.green50,
                child: entry.imageBytes == null
                    ? const Icon(Icons.image_outlined)
                    : Image.memory(entry.imageBytes!, fit: BoxFit.cover),
              ),
            ),
            title: Text(
              isHealthy
                  ? '${entry.plantName} — Healthy 🌱'
                  : (entry.diseaseName ?? 'No disease matched'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.plantName,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  // Pill-shaped tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _pillTag(
                        context,
                        icon: Icons.eco_rounded,
                        text: 'Plant ${(entry.plantConfidence * 100).toStringAsFixed(0)}%',
                        confidence: entry.plantConfidence,
                      ),
                      _pillTag(
                        context,
                        icon: Icons.biotech_rounded,
                        text: 'Disease ${(entry.confidence * 100).toStringAsFixed(0)}%',
                        confidence: entry.confidence,
                      ),
                      _pillTag(
                        context,
                        icon: Icons.schedule_rounded,
                        text: DateFormat('dd MMM, hh:mm a').format(entry.createdAt),
                      ),
                      if (entry.totalLatencyMs > 0)
                        _pillTag(
                          context,
                          icon: Icons.speed_rounded,
                          text: '${entry.totalLatencyMs.toStringAsFixed(0)} ms',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Swipeable image slider
              if (entry.imageBytes != null) ...[
                ImageSlider.fromHistoryEntry(
                  imageBytes: entry.imageBytes,
                  plantGradcamBytes: entry.plantGradcamBytes,
                  gradcamBytes: entry.gradcamBytes,
                  height: 180,
                ),
                const SizedBox(height: 14),
              ],

              // Confidence bars
              DetailGroup(
                title: 'Details',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MiniConfidenceBar(
                          label: 'Plant (${entry.plantName})',
                          confidence: entry.plantConfidence,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MiniConfidenceBar(
                          label: 'Disease${entry.diseaseName != null ? ' (${entry.diseaseName!})' : ''}',
                          confidence: entry.confidence,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (entry.isHealthy) ...[
                    const DetailLine(
                        label: 'Status',
                        value: '✅ No disease detected — plant looks healthy!'),
                  ] else ...[
                    if (entry.diseaseCause != null)
                      DetailLine(label: 'Cause', value: entry.diseaseCause!),
                    if (entry.diseaseDescription != null) ...[
                      const SizedBox(height: 10),
                      DetailLine(label: 'Description', value: entry.diseaseDescription!),
                    ],
                    if (entry.diseaseRemedy != null) ...[
                      const SizedBox(height: 10),
                      DetailLine(label: 'Remedy', value: entry.diseaseRemedy!),
                    ],
                    if (entry.diseasePrevention != null) ...[
                      const SizedBox(height: 10),
                      DetailLine(label: 'Prevention', value: entry.diseasePrevention!),
                    ],
                  ],
                  if (entry.advice != null && entry.advice!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DetailLine(label: 'Advice', value: entry.advice!),
                  ],
                  if (isLowConf && entry.message != null) ...[
                    const SizedBox(height: 10),
                    DetailLine(
                      label: 'Note',
                      value: entry.message!,
                      valueColor: Colors.orange.shade800,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // Delete button (visible in expanded form)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final confirmed = await onDismissConfirm();
                    if (confirmed) onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete this entry',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill-shaped tag with icon, text, and optional confidence coloring.
  Widget _pillTag(
    BuildContext context, {
    required IconData icon,
    required String text,
    double? confidence,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg, fg;
    if (confidence != null) {
      final pct = confidence * 100;
      if (pct >= 70) {
        bg = isDark ? const Color(0xFF1B3A1E) : const Color(0xFFE8F5E9);
        fg = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
      } else if (pct >= 45) {
        bg = isDark ? const Color(0xFF3A2800) : const Color(0xFFFFF8E1);
        fg = isDark ? const Color(0xFFFFCA28) : const Color(0xFFE65100);
      } else {
        bg = isDark ? const Color(0xFF3A0E0E) : const Color(0xFFFFEBEE);
        fg = isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      }
    } else {
      bg = isDark ? AppColors.gray800 : AppColors.gray100;
      fg = isDark ? AppColors.gray300 : AppColors.gray600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
