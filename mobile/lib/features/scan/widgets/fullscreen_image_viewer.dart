import 'dart:typed_data';

import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatelessWidget {
  const FullscreenImageViewer({
    super.key,
    required this.imageBytes,
    required this.title,
  });

  final Uint8List imageBytes;
  final String title;

  static void show(BuildContext context,
      {required Uint8List imageBytes, required String title}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) =>
          FullscreenImageViewer(imageBytes: imageBytes, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
