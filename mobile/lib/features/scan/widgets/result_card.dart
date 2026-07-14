import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/detection_model.dart';
import 'detail_group.dart';
import 'detail_line.dart';
import 'performance_card.dart';
import 'score_chart.dart';
import 'stage_confidence_bar.dart';
import 'status_banner.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.response,
    required this.plantGradcamBytes,
    required this.diseaseGradcamBytes,
    required this.onRetake,
  });

  final DetectionApiResponse response;
  final Uint8List? plantGradcamBytes;
  final Uint8List? diseaseGradcamBytes;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final result = response.data;
    if (result == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ────────────────────────────────────────────
            StatusBanner(response: response, result: result),
            const SizedBox(height: 18),

            // ── Stage 1 — Plant confidence ───────────────────────────────
            StageConfidenceBar(
              stageLabel: 'Stage 1: Plant ID (${result.stage1Model})',
              label: result.plantName.isEmpty ? 'Unknown' : result.plantName,
              confidence: result.plantConfidence,
            ),
            const SizedBox(height: 14),

            // ── Stage 2 — Disease confidence ─────────────────────────────
            if (result.diseaseName != null || response.effectivelyHealthy) ...[
              StageConfidenceBar(
                stageLabel: 'Stage 2: Disease (${result.stage2Model})',
                label: response.effectivelyHealthy
                    ? 'Healthy 🌱'
                    : (result.diseaseName ?? 'Unknown'),
                confidence: result.confidence,
              ),
              const SizedBox(height: 18),
            ],

            // ── Performance metrics ──────────────────────────────────────
            if (result.totalLatencyMs > 0) ...[
              PerformanceCard(result: result),
              const SizedBox(height: 14),
            ],

            // ── All plant scores ─────────────────────────────────────────
            if (result.plantScores.isNotEmpty) ...[
              ScoreChart(
                title: 'Plant identification scores',
                scores: result.plantScores,
                winnerName: result.plantName,
              ),
              const SizedBox(height: 14),
            ],

            // ── All disease scores ────────────────────────────────────────
            if (result.diseaseScores.isNotEmpty) ...[
              ScoreChart(
                title: 'Disease detection scores',
                scores: result.diseaseScores,
                winnerName: response.effectivelyHealthy
                    ? 'Healthy'
                    : (result.diseaseName ?? ''),
                isDisease: true,
              ),
              const SizedBox(height: 18),
            ],

            // ── Disease details (only for actual diseases, not healthy) ──
            if (!response.effectivelyHealthy &&
                response.status != 'not_recognized' &&
                response.status != 'no_model') ...[
              DetailGroup(
                title: 'Diagnosis details',
                children: [
                  if (result.diseaseCause != null)
                    DetailLine(label: 'Cause', value: result.diseaseCause!),
                  if (result.diseaseDescription != null) ...[
                    const SizedBox(height: 10),
                    DetailLine(
                        label: 'Description',
                        value: result.diseaseDescription!),
                  ],
                  if (result.diseaseRemedy != null) ...[
                    const SizedBox(height: 10),
                    DetailLine(label: 'Remedy', value: result.diseaseRemedy!),
                  ],
                  if (result.diseasePrevention != null) ...[
                    const SizedBox(height: 10),
                    DetailLine(
                        label: 'Prevention', value: result.diseasePrevention!),
                  ],
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── Treatment advice ──────────────────────────────────────────
            if (result.advice != null && result.advice!.isNotEmpty) ...[
              DetailGroup(
                title: '💊 Treatment Advice',
                children: [
                  Text(
                    result.advice!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── Healthy care tips ─────────────────────────────────────────
            if (response.effectivelyHealthy) ...[
              const DetailGroup(
                title: 'Keep it healthy 🌿',
                children: [
                  DetailLine(
                    label: 'Watering',
                    value: 'Water consistently but avoid waterlogging. '
                        'Check soil moisture before each watering.',
                  ),
                  SizedBox(height: 10),
                  DetailLine(
                    label: 'Sunlight',
                    value:
                        'Ensure adequate sunlight. Rotate periodically for even growth.',
                  ),
                  SizedBox(height: 10),
                  DetailLine(
                    label: 'Prevention',
                    value:
                        'Inspect leaves regularly. Remove dead leaves and maintain airflow.',
                  ),
                ],
              ),
            ],

            // ── Low-confidence scan tips ──────────────────────────────────
            if (response.status == 'low_confidence') ...[
              const SizedBox(height: 14),
              const DetailGroup(
                title: 'Tips for a better scan',
                children: [
                  DetailLine(
                      label: 'Background',
                      value: 'Use a plain white/grey surface behind the leaf.'),
                  SizedBox(height: 10),
                  DetailLine(
                      label: 'Lighting',
                      value:
                          'Scan in bright natural light. Avoid shadows or flash.'),
                  SizedBox(height: 10),
                  DetailLine(
                      label: 'Framing',
                      value: 'Fill the frame with the affected leaf.'),
                  SizedBox(height: 10),
                  DetailLine(
                      label: 'Focus',
                      value: 'Make sure lesions are sharply in focus.'),
                ],
              ),
            ],

            // ── No-model info (Strawberry / Corn) ─────────────────────────
            if (response.status == 'no_model') ...[
              const SizedBox(height: 14),
              DetailGroup(
                title: '🔬 Disease Model',
                children: [
                  Text(
                    response.message ?? 'Disease detection model coming soon.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],

            // ── Retake / scan-again buttons ────────────────────────────────
            const SizedBox(height: 16),

            if (response.status == 'low_confidence' ||
                response.status == 'not_recognized') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD84315),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onRetake,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Retake Photo',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(height: 10),
            ],

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onRetake,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Scan Another Leaf',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
