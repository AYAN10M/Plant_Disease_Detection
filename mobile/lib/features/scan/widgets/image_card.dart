import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'image_slider.dart';

/// Image selection card with preview slider, source buttons, and detect CTA.
class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    required this.selectedImageBytes,
    required this.plantGradcamBytes,
    required this.diseaseGradcamBytes,
    required this.detecting,
    required this.hasSelectedImage,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onDetect,
  });

  final Uint8List? selectedImageBytes;
  final Uint8List? plantGradcamBytes;
  final Uint8List? diseaseGradcamBytes;
  final bool detecting;
  final bool hasSelectedImage;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Image preview area
        if (selectedImageBytes == null)
          _buildPlaceholder(context, isDark)
        else
          ImageSlider.fromScanData(
            selectedImageBytes: selectedImageBytes,
            plantGradcamBytes: plantGradcamBytes,
            diseaseGradcamBytes: diseaseGradcamBytes,
            detecting: detecting,
            height: 260,
          ),
        const SizedBox(height: 20),

        // Source buttons
        Row(
          children: [
            Expanded(
              child: _sourceButton(
                context,
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: detecting ? null : onPickGallery,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _sourceButton(
                context,
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: detecting ? null : onPickCamera,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Detect button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: detecting || !hasSelectedImage ? null : onDetect,
            child: detecting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isDark ? AppColors.black : AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Analysing…',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.biotech_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('Detect Disease',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: onPickGallery,
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.gray700.withValues(alpha: 0.6)
                : AppColors.green100,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.gray800.withValues(alpha: 0.8),
                    AppColors.gray900,
                  ]
                : [
                    AppColors.green50,
                    AppColors.white,
                  ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.green400.withValues(alpha: 0.12)
                    : AppColors.green600.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_a_photo_rounded,
                size: 32,
                color: isDark ? AppColors.green400 : AppColors.green600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a leaf photo',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Take a photo or choose from gallery',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final accent = isDark ? AppColors.green400 : AppColors.green600;

    return Material(
      color: isDark
          ? AppColors.gray800.withValues(alpha: 0.6)
          : AppColors.green50.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.gray700.withValues(alpha: 0.5)
                  : AppColors.green100,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}
