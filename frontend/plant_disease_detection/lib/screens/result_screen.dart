import 'dart:io';
import 'package:flutter/material.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';

// ─────────────────────────────────────────
//  ResultScreen
//  Shows after the ML model processes the image.
//  Displays:
//    - Annotated image (returned from backend)
//    - Disease name + confidence score
//    - Cause, symptoms, treatment
//    - Save to history button
// ─────────────────────────────────────────

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaved = false;

  void _saveToHistory() {
    // TODO: Call API to save this scan to history
    // await ApiService.saveHistory(...)
    setState(() => _isSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan saved to history'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Data passed from HomeScreen via Navigator
    // In real app this will be the API response object
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String imagePath = args?['imagePath'] ?? '';
    final String disease = args?['disease'] ?? 'Unknown';
    final double confidence = (args?['confidence'] ?? 0.0) as double;
    final String plant = args?['plant'] ?? 'Unknown plant';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan result'),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: implement share using share_plus package
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Annotated image ──
            // The backend OpenCV-annotated image replaces the original
            _AnnotatedImageCard(imagePath: imagePath),
            const SizedBox(height: 20),

            // ── Disease diagnosis card ──
            _DiagnosisCard(
              disease: disease,
              plant: plant,
              confidence: confidence,
            ),
            const SizedBox(height: 16),

            // ── Disease detail sections ──
            _InfoSection(
              title: 'What is this disease?',
              icon: Icons.info_outline,
              content:
                  'Early Blight is a common fungal disease caused by Alternaria solani. '
                  'It typically appears as dark brown spots with concentric rings, '
                  'giving a "target" appearance on older leaves first.',
              // TODO: Load this text from your DiseaseInfo database model
            ),
            const SizedBox(height: 12),

            _InfoSection(
              title: 'Why does it occur?',
              icon: Icons.warning_amber_outlined,
              content:
                  'Caused by humid conditions, excessive moisture on leaves, '
                  'poor air circulation, and infected soil or plant debris from '
                  'previous seasons. Warm temperatures (24–29°C) accelerate spread.',
            ),
            const SizedBox(height: 12),

            _InfoSection(
              title: 'How to treat it',
              icon: Icons.healing_outlined,
              content:
                  '1. Remove and destroy infected leaves immediately.\n'
                  '2. Apply copper-based or chlorothalonil fungicide.\n'
                  '3. Water at the base — avoid wetting the foliage.\n'
                  '4. Ensure proper spacing for air circulation.\n'
                  '5. Rotate crops in the next season.',
            ),
            const SizedBox(height: 28),

            // ── Action buttons ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaved ? null : _saveToHistory,
                icon: Icon(
                  _isSaved ? Icons.check_circle_outline : Icons.save_outlined,
                ),
                label: Text(_isSaved ? 'Saved to history' : 'Save to history'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Scan another leaf'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Annotated image card ─────────────────

class _AnnotatedImageCard extends StatelessWidget {
  final String imagePath;
  const _AnnotatedImageCard({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // The annotated image from backend
          // In a real call: Image.network(annotatedImageUrl, ...)
          imagePath.isNotEmpty
              ? Image.file(
                  File(imagePath),
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 260,
                  width: double.infinity,
                  color: AppColors.primarySurface,
                  child: const Icon(
                    Icons.eco_outlined,
                    size: 60,
                    color: AppColors.primaryLight,
                  ),
                ),

          // "Annotated" label badge at bottom left
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'AI annotated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diagnosis summary card ───────────────

class _DiagnosisCard extends StatelessWidget {
  final String disease;
  final String plant;
  final double confidence;

  const _DiagnosisCard({
    required this.disease,
    required this.plant,
    required this.confidence,
  });

  Color get _severityColor {
    if (confidence > 0.85) return AppColors.danger;
    if (confidence > 0.6) return AppColors.warning;
    return AppColors.success;
  }

  String get _severityLabel {
    if (confidence > 0.85) return 'High confidence';
    if (confidence > 0.6) return 'Medium confidence';
    return 'Low confidence';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(disease, style: AppText.heading2),
                    const SizedBox(height: 3),
                    Text(
                      plant,
                      style: AppText.bodySecondary.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Severity badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _severityLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _severityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Confidence bar
          Text(
            'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
            style: AppText.label,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_severityColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disease info section ──────────────────

class _InfoSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  State<_InfoSection> createState() => _InfoSectionState();
}

class _InfoSectionState extends State<_InfoSection> {
  // Sections are expandable — tap to open/close
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.title, style: AppText.heading3)),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Content (visible when expanded)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(widget.content, style: AppText.body),
            ),
        ],
      ),
    );
  }
}
