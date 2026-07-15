import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'fullscreen_image_viewer.dart';

class ImageSlide {
  final String title;
  final Widget child;
  final Uint8List? fullscreenBytes;

  const ImageSlide({
    required this.title,
    required this.child,
    this.fullscreenBytes,
  });
}

class ImageSlider extends StatefulWidget {
  const ImageSlider({
    super.key,
    required this.slides,
    this.height = 220,
  });

  factory ImageSlider.fromScanData({
    Key? key,
    required Uint8List? selectedImageBytes,
    required Uint8List? plantGradcamBytes,
    required Uint8List? diseaseGradcamBytes,
    required bool detecting,
    double height = 260,
  }) {
    final slides = <ImageSlide>[];

    if (selectedImageBytes != null) {
      slides.add(ImageSlide(
        title: 'Original',
        fullscreenBytes: selectedImageBytes,
        child: Image.memory(selectedImageBytes, fit: BoxFit.cover),
      ));
    }


    final camBytes = diseaseGradcamBytes ?? plantGradcamBytes;
    if (camBytes != null) {
      slides.add(ImageSlide(
        title: 'Grad-CAM',
        fullscreenBytes: camBytes,
        child: Image.memory(camBytes, fit: BoxFit.cover),
      ));
    } else if (selectedImageBytes != null) {
      slides.add(ImageSlide(
        title: 'Grad-CAM',
        child: Center(
          child: Text(
            detecting ? 'Generating heatmap…' : 'Not available',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ));
    }

    return ImageSlider(key: key, slides: slides, height: height);
  }

  factory ImageSlider.fromHistoryEntry({
    Key? key,
    required Uint8List? imageBytes,
    required Uint8List? plantGradcamBytes,
    required Uint8List? gradcamBytes,
    double height = 200,
  }) {
    final slides = <ImageSlide>[];

    if (imageBytes != null) {
      slides.add(ImageSlide(
        title: 'Original',
        fullscreenBytes: imageBytes,
        child: Image.memory(imageBytes, fit: BoxFit.cover),
      ));
    }

    final camBytes = gradcamBytes ?? plantGradcamBytes;
    if (camBytes != null) {
      slides.add(ImageSlide(
        title: 'Grad-CAM',
        fullscreenBytes: camBytes,
        child: Image.memory(camBytes, fit: BoxFit.cover),
      ));
    }

    return ImageSlider(key: key, slides: slides, height: height);
  }

  final List<ImageSlide> slides;
  final double height;

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(keepPage: false);
  }

  @override
  void didUpdateWidget(ImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slides.length != oldWidget.slides.length) {
      _currentPage = 0;
      _controller.dispose();
      _controller = PageController(keepPage: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.green400 : AppColors.green600;

    return Column(
      children: [

        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.gray800 : AppColors.green50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.gray700 : AppColors.green100,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final slide = widget.slides[index];
                    return GestureDetector(
                      onTap: slide.fullscreenBytes != null
                          ? () => FullscreenImageViewer.show(
                                context,
                                imageBytes: slide.fullscreenBytes!,
                                title: slide.title,
                              )
                          : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          slide.child,
                          if (slide.fullscreenBytes != null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.0),
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                          if (slide.fullscreenBytes != null)
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: Icon(Icons.fullscreen_rounded,
                                  color: Colors.white70, size: 22),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                if (widget.slides.length > 1) ...[
                  if (_currentPage > 0)
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _arrow(Icons.chevron_left_rounded, -1)),
                    ),
                  if (_currentPage < widget.slides.length - 1)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _arrow(Icons.chevron_right_rounded, 1)),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),


        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.slides[_currentPage].title,
                key: ValueKey(_currentPage),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
            if (widget.slides.length > 1) ...[
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.slides.length, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _controller.animateToPage(i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? accent
                            : (isDark ? AppColors.gray700 : AppColors.gray300),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, int direction) {
    return GestureDetector(
      onTap: () {
        final target = _currentPage + direction;
        if (target >= 0 && target < widget.slides.length) {
          _controller.animateToPage(target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic);
        }
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
