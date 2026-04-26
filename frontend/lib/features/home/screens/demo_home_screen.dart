import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dummy_catalog.dart';
import '../models/detection_record.dart';

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  static const _historyKey = 'midori_detection_history';
  static const _maxHistoryEntries = 20;
  static const _confidenceThreshold = 0.60;

  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  int _currentIndex = 0;
  int _selectedPlantIndex = 0;
  bool _loadingHistory = true;
  bool _detecting = false;
  String? _selectedImageName;
  Uint8List? _selectedImageBytes;
  DetectionApiResponse? _latestResult;
  List<DetectionHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    final history = raw == null || raw.isEmpty
        ? <DetectionHistoryEntry>[]
        : (jsonDecode(raw) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(DetectionHistoryEntry.fromJson)
              .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _history = history;
      _loadingHistory = false;
    });
  }

  Future<void> _saveHistoryEntry(DetectionHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [entry, ..._history].take(_maxHistoryEntries).toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _history = updated;
    });
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
      _selectedImageName = image.name;
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _runDemoDetection() async {
    if (_selectedImageBytes == null) {
      _showSnackBar('Pick an image first.');
      return;
    }

    final plant = demoPlants[_selectedPlantIndex];
    final disease = plant.diseases[_random.nextInt(plant.diseases.length)];
    final confidence = double.parse(
      // Range 0.40–0.99 — matches the backend mock in ml_model.py
      (_random.nextDouble() * 0.59 + 0.40).toStringAsFixed(2),
    );
    final status = confidence < _confidenceThreshold
        ? 'low_confidence'
        : 'success';
    final message = status == 'success'
        ? 'Demo detection generated locally on this device.'
        : 'Demo result only. Confidence is low, so please retake the photo.';

    final result = DetectionResult(
      id: DateTime.now().millisecondsSinceEpoch,
      plantName: plant.name,
      diseaseName: disease.name,
      diseaseDescription: disease.symptoms,
      diseaseRemedy: disease.remedy,
      uploadedImageUrl: _selectedImageName,
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

    final historyEntry = DetectionHistoryEntry.fromDetection(
      result: result,
      message: message,
    );

    // BUG FIX: set _detecting = true FIRST (show spinner), do the work,
    // then set _latestResult and _detecting = false together so the result
    // card never appears while the spinner is still running.
    setState(() {
      _detecting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _saveHistoryEntry(historyEntry);

    if (!mounted) return;

    setState(() {
      _latestResult = response;
      _detecting    = false;
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _history = [];
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Color> _heroGradientColors() {
    if (widget.isDarkMode) {
      return const [Color(0xFF1DB954), Color(0xFF0F5C2E)];
    }
    return const [Color(0xFF1DB954), Color(0xFF149143)];
  }

  Color _softSurfaceColor() {
    if (widget.isDarkMode) {
      return const Color(0xFF1F1F1F);
    }
    return const Color(0xFFF0F4F1);
  }

  Color _softBorderColor() {
    if (widget.isDarkMode) {
      return const Color(0xFF2E2E2E);
    }
    return const Color(0xFFD5E4DA);
  }

  Color _mutedTextColor() {
    return Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: widget.isDarkMode ? 0.72 : 0.62);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Midori'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    widget.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: widget.isDarkMode,
                    onChanged: widget.onThemeChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildScanTab(), _buildHistoryTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
          await _pickImage();
        },
        tooltip: 'Scan a plant',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadHistory();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildPlantPickerCard(),
          const SizedBox(height: 16),
          _buildImageCard(),
          const SizedBox(height: 16),
          if (_latestResult != null) _buildResultCard(_latestResult!),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _heroGradientColors(),
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
            child: Icon(Icons.eco_rounded, color: Colors.white, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Midori',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Take or upload a photo — get an instant plant disease diagnosis.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantPickerCard() {
    final plant = demoPlants[_selectedPlantIndex];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose plant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: plant.id,
              items: demoPlants
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.name} (${item.scientificName})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedPlantIndex = demoPlants.indexWhere(
                    (item) => item.id == value,
                  );
                });
              },
              decoration: const InputDecoration(
                labelText: 'Plant',
                prefixIcon: Icon(Icons.eco_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  plant.icon,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plant.description,
                    style: TextStyle(color: _mutedTextColor()),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                  color: _softSurfaceColor(),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _softBorderColor()),
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
            if (_selectedImageName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _selectedImageName!,
                  style: TextStyle(color: _mutedTextColor()),
                ),
              ),
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
                    onPressed: _detecting ? null : _runDemoDetection,
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
    if (result == null) return const SizedBox.shrink();

    final plant = demoPlants.firstWhere(
      (item) => item.name == result.plantName,
      orElse: () => demoPlants.first,
    );
    final disease = plant.diseases.firstWhere(
      (item) => item.name == result.diseaseName,
      orElse: () => plant.diseases.first,
    );

    final isLowConf = response.status == 'low_confidence';

    // Severity colour
    Color severityColor(String sev) {
      switch (sev.toLowerCase()) {
        case 'high':
          return Colors.red.shade700;
        case 'medium':
          return Colors.orange.shade700;
        default:
          return Colors.green.shade700;
      }
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    isLowConf ? 'Low Confidence Result' : 'Detection Result',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Confidence badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLowConf
                        ? Colors.orange.shade50
                        : const Color(0xFFE8F7EE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLowConf
                          ? Colors.orange.shade300
                          : const Color(0xFF1DB954),
                    ),
                  ),
                  child: Text(
                    result.confidencePct,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isLowConf ? Colors.orange.shade800 : const Color(0xFF1DB954),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Disease name + severity badge ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.diseaseName ?? 'No disease matched',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: severityColor(disease.severity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    disease.severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: severityColor(disease.severity),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Plant: ${result.plantName}',
              style: TextStyle(color: _mutedTextColor()),
            ),

            const Divider(height: 24),

            // ── Symptoms ───────────────────────────────────────────────────
            _infoSection(
              icon: Icons.search_rounded,
              label: 'Symptoms',
              content: result.diseaseDescription ?? disease.symptoms,
            ),
            const SizedBox(height: 12),

            // ── Cause ──────────────────────────────────────────────────────
            _infoSection(
              icon: Icons.bug_report_outlined,
              label: 'Cause',
              content: disease.cause,
            ),
            const SizedBox(height: 12),

            // ── Remedy ─────────────────────────────────────────────────────
            _infoSection(
              icon: Icons.healing_outlined,
              label: 'Remedy',
              content: result.diseaseRemedy ?? disease.remedy,
            ),
            const SizedBox(height: 12),

            // ── Prevention ─────────────────────────────────────────────────
            _infoSection(
              icon: Icons.shield_outlined,
              label: 'Prevention',
              content: disease.prevention,
            ),

            // ── Low confidence warning + retake ────────────────────────────
            if (isLowConf) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Low confidence',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      response.message ??
                          'Please retake the photo in better lighting with the affected area clearly visible.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Retake Photo'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Reusable section row for symptoms / cause / remedy / prevention.
  Widget _infoSection({
    required IconData icon,
    required String label,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1DB954)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(content, style: TextStyle(color: _mutedTextColor())),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved on this device',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                      color: _softBorderColor(),
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
            ..._history.map(_buildHistoryCard),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(DetectionHistoryEntry entry) {
    final isLowConf = entry.status == 'low_confidence';
    final confidencePct = '${(entry.confidence * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: _softSurfaceColor(),
                  child: Icon(
                    Icons.eco_outlined,
                    color: const Color(0xFF1DB954).withValues(alpha: 0.7),
                    size: 28,
                  ),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Colour-coded confidence pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLowConf
                                ? Colors.orange.shade50
                                : const Color(0xFFE8F7EE),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLowConf
                                  ? Colors.orange.shade300
                                  : const Color(0xFF1DB954),
                            ),
                          ),
                          child: Text(
                            confidencePct,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLowConf
                                  ? Colors.orange.shade800
                                  : const Color(0xFF1DB954),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.plantName,
                      style: TextStyle(color: _mutedTextColor(), fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(entry.createdAt),
                      style: TextStyle(color: _mutedTextColor(), fontSize: 12),
                    ),
                    if (isLowConf) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Low confidence — retake recommended',
                            style: TextStyle(
                                color: Colors.orange.shade800, fontSize: 12),
                          ),
                        ],
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

