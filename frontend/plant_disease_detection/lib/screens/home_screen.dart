import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Add to pubspec.yaml
import 'package:plant_disease_detection/theme/app_theme.dart';


// ─────────────────────────────────────────
//  HomeScreen
//  The main scan screen. User can:
//    1. Take a photo with camera
//    2. Pick from gallery
//    3. See a preview of the selected image
//    4. Press Analyse to send to backend
// ─────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Holds the image the user selected
  File? _selectedImage;

  // Loading state while the API call is happening
  bool _isAnalysing = false;

  // ImagePicker lets us access camera and gallery
  final ImagePicker _picker = ImagePicker();

  // ── Pick image from camera or gallery ──
  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85, // Compress slightly to reduce upload size
      maxWidth: 1024,
    );

    if (file != null) {
      setState(() {
        _selectedImage = File(file.path);
      });
    }
  }

  // ── Send image to Django backend ──
  Future<void> _analyse() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalysing = true);

    // TODO: Replace with actual API call
    // Example using dio package:
    // final result = await ApiService.predict(_selectedImage!);
    // Navigator.pushNamed(context, '/result', arguments: result);
    await Future.delayed(const Duration(seconds: 2)); // Simulated delay

    setState(() => _isAnalysing = false);

    if (mounted) {
      // Pass the image and result to the result screen
      Navigator.pushNamed(
        context,
        '/result',
        arguments: {
          'imagePath': _selectedImage!.path,
          'disease': 'Early Blight', // Will come from API
          'confidence': 0.91, // Will come from API
          'plant': 'Tomato',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LeafScan'),
        actions: [
          // History icon top right
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Scan history',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          // Profile / logout
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO: navigate to profile or show logout dialog
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ──
            const Text('Good morning,', style: AppText.bodySecondary),
            const SizedBox(height: 2),
            const Text(
              'Scan a leaf to detect disease',
              style: AppText.heading2,
            ),
            const SizedBox(height: 28),

            // ── Image preview / placeholder ──
            _ImagePreview(
              image: _selectedImage,
              onCameraPressed: () => _pickImage(ImageSource.camera),
              onGalleryPressed: () => _pickImage(ImageSource.gallery),
            ),

            const SizedBox(height: 20),

            // ── Source buttons ──
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Tips card ──
            if (_selectedImage == null) _TipsCard(),

            // ── Analyse button (shows when image selected) ──
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAnalysing ? null : _analyse,
                  icon: _isAnalysing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, size: 20),
                  label: Text(_isAnalysing ? 'Analysing...' : 'Analyse leaf'),
                ),
              ),
              const SizedBox(height: 12),
              // Clear selection
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  child: const Text('Clear image'),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Recent scans preview ──
            _RecentScansSection(),
          ],
        ),
      ),
    );
  }
}

// ── Image preview box ────────────────────

class _ImagePreview extends StatelessWidget {
  final File? image;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  const _ImagePreview({
    required this.image,
    required this.onCameraPressed,
    required this.onGalleryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: image != null ? Colors.transparent : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: image != null
              ? Colors.transparent
              : AppColors.primaryLight.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: image != null
          ? Image.file(image!, fit: BoxFit.cover)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('No image selected', style: AppText.body),
                const SizedBox(height: 4),
                const Text(
                  'Use camera or gallery below',
                  style: AppText.bodySecondary,
                ),
              ],
            ),
    );
  }
}

// ── Source button (Camera / Gallery) ────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppText.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tips card ────────────────────────────

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tips = [
      'Place the leaf against a plain background',
      'Ensure good lighting — natural light is best',
      'Capture the affected area clearly',
      'Hold the phone steady to avoid blur',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tips for best results',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                  Expanded(child: Text(tip, style: AppText.bodySecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent scans ─────────────────────────

class _RecentScansSection extends StatelessWidget {
  // Dummy data — will be replaced by API call
  final List<Map<String, dynamic>> _recentScans = const [
    {
      'disease': 'Early Blight',
      'plant': 'Tomato',
      'date': 'Today, 9:14 AM',
      'severity': 'high',
    },
    {
      'disease': 'Powdery Mildew',
      'plant': 'Cucumber',
      'date': 'Yesterday',
      'severity': 'medium',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent scans', style: AppText.heading3),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
              ),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentScans.map(
          (scan) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScanCard(scan: scan),
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  const _ScanCard({required this.scan});

  Color _severityColor(String s) {
    switch (s) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Leaf icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan['disease'], style: AppText.heading3),
                const SizedBox(height: 2),
                Text(
                  '${scan['plant']} · ${scan['date']}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          // Severity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _severityColor(scan['severity']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              scan['severity'],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _severityColor(scan['severity']),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
