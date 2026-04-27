import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/dummy_catalog.dart';
import '../models/detection_record.dart';
import '../services/detection_history_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DetectionHistoryStore _historyStore = DetectionHistoryStore();
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  int _currentIndex = 0;
  bool _loadingHistory = true;
  bool _detecting = false;
  String? _actionMessage;
  List<DetectionHistoryEntry> _history = [];
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  DetectionApiResponse? _latestResult;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
    });

    final entries = await _historyStore.loadEntries();
    if (mounted) {
      setState(() {
        _history = entries;
        _loadingHistory = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
      _actionMessage = null;
    });
  }

  Future<void> _runDetection() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      _showSnackBar('Pick an image to analyze.');
      return;
    }

    setState(() {
      _detecting = true;
      _actionMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final plant = demoPlants[_random.nextInt(demoPlants.length)];
      final disease = plant.diseases[_random.nextInt(plant.diseases.length)];
      final confidence = double.parse(
        (_random.nextDouble() * 0.59 + 0.40).toStringAsFixed(2),
      );
      final status = confidence < 0.60 ? 'low_confidence' : 'success';
      final message = status == 'success'
          ? 'Demo detection generated locally on this device.'
          : 'Confidence is low. Try scanning another leaf in better lighting.';

      final result = DetectionResult(
        id: DateTime.now().millisecondsSinceEpoch,
        plantName: plant.name,
        diseaseName: disease.name,
        diseaseDescription: disease.symptoms,
        diseaseRemedy: disease.remedy,
        uploadedImageUrl: _selectedImage!.name,
        gradcamImageUrl: null,
        confidence: confidence,
        confidencePct: '${(confidence * 100).toStringAsFixed(1)}%',
        status: status,
        createdAt: DateTime.now(),
      );

      final response = DetectionApiResponse(
        status: status,
        message: message,
        data: result,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latestResult = response;
        _actionMessage = message;
      });

      final historyEntry = DetectionHistoryEntry.fromDetection(
        result: result,
        message: message,
        diseaseCause: disease.cause,
        diseasePrevention: disease.prevention,
        imageBytes: _selectedImageBytes,
        gradcamBytes: null,
      );
      await _historyStore.saveEntry(historyEntry);

      if (mounted) {
        setState(() {
          _history = [historyEntry, ..._history];
        });
      }
    } catch (_) {
      _showSnackBar('Detection failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _detecting = false;
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear();
    if (mounted) {
      setState(() {
        _history = [];
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Plant Disease Detector')),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildScanTab(), _buildHistoryTab()],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SafeArea(top: false, child: _buildFloatingCuboidNavBar()),
      ),
    );
  }

  Future<void> _onTabSelected(int index) async {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      await _loadHistory();
    }
  }

  Widget _buildFloatingCuboidNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBDBDBD), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavBarItem(
              label: 'Scan',
              selected: _currentIndex == 0,
              icon: Icons.document_scanner_outlined,
              activeIcon: Icons.document_scanner,
              onTap: () => _onTabSelected(0),
            ),
          ),
          Expanded(
            child: _NavBarItem(
              label: 'History',
              selected: _currentIndex == 1,
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              onTap: () => _onTabSelected(1),
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets _responsivePadding(BoxConstraints constraints) {
    final horizontal = constraints.maxWidth >= 900
        ? 28.0
        : constraints.maxWidth >= 600
        ? 24.0
        : 20.0;
    return EdgeInsets.fromLTRB(horizontal, 20, horizontal, 20);
  }

  Widget _buildScanTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadHistory();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 120),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildImageCard(),
                const SizedBox(height: 16),
                if (_latestResult != null) _buildResultCard(_latestResult!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.local_florist, color: Colors.white, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simple scanning, local history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Upload a photo and let the app choose a local demo result automatically.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: _selectedImageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 44),
                          SizedBox(height: 12),
                          Text('Tap to choose a photo'),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Pick image'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _detecting ? null : _runDetection,
                    icon: _detecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_detecting ? 'Scanning...' : 'Detect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(DetectionApiResponse response) {
    final result = response.data;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  response.status == 'success' ? 'Result' : 'Low confidence',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(result.confidencePct),
                  backgroundColor: Colors.green.shade50,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.diseaseName ?? 'No disease matched',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Plant: ${result.plantName}'),
            const SizedBox(height: 12),
            if (result.diseaseDescription != null)
              Text(result.diseaseDescription!),
            if (result.diseaseRemedy != null) ...[
              const SizedBox(height: 10),
              Text(
                'Remedy: ${result.diseaseRemedy!}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              response.message ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 120),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Saved on this device',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _history.isEmpty ? null : _clearHistory,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingHistory)
                  const Center(child: CircularProgressIndicator())
                else if (_history.isEmpty)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 48,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No detection history yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Run a scan and it will appear here.'),
                        ],
                      ),
                    ),
                  )
                else
                  ..._history.map((entry) => _buildHistoryCard(entry)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DetectionHistoryEntry entry) {
    final isLowConfidence = entry.status == 'low_confidence';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: Colors.green.shade50,
                  child: entry.imageBytes == null
                      ? const Icon(Icons.image_outlined)
                      : Image.memory(entry.imageBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.diseaseName ?? 'No disease matched',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(entry.status),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(entry.plantName),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(entry.confidence * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(entry.createdAt),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (isLowConfidence && entry.message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.message!,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fgColor = selected ? Colors.white : const Color(0xFF2B2B2B);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F1F1F) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF1F1F1F) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: fgColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
