import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/detection_record.dart';
import '../models/plant_model.dart';
import '../services/detection_api_service.dart';
import '../services/detection_history_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DetectionApiService _apiService = DetectionApiService();
  final DetectionHistoryStore _historyStore = DetectionHistoryStore();
  final ImagePicker _picker = ImagePicker();

  int _currentIndex = 0;
  bool _loadingPlants = true;
  bool _loadingHistory = true;
  bool _detecting = false;
  String? _plantError;
  String? _actionMessage;
  List<PlantModel> _plants = [];
  List<DetectionHistoryEntry> _history = [];
  int? _selectedPlantId;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  DetectionApiResponse? _latestResult;

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('FLUTTER_TEST')) {
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadPlants(), _loadHistory()]);
  }

  Future<void> _loadPlants() async {
    setState(() {
      _loadingPlants = true;
      _plantError = null;
    });

    try {
      final plants = await _apiService.fetchPlants();
      if (mounted) {
        setState(() {
          _plants = plants;
          _selectedPlantId = plants.isNotEmpty ? plants.first.id : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _plantError = 'Could not load plants. Check the backend connection.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlants = false;
        });
      }
    }
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
    if (_selectedPlantId == null) {
      _showSnackBar('Choose a plant first.');
      return;
    }

    if (_selectedImage == null || _selectedImageBytes == null) {
      _showSnackBar('Pick an image to analyze.');
      return;
    }

    setState(() {
      _detecting = true;
      _actionMessage = null;
    });

    try {
      final response = await _apiService.detect(
        plantId: _selectedPlantId!,
        imageBytes: _selectedImageBytes!,
        fileName: _selectedImage!.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latestResult = response;
        _actionMessage = response.message;
      });

      if (response.data != null) {
        final historyEntry = DetectionHistoryEntry.fromDetection(
          result: response.data!,
          message: response.message,
        );
        await _historyStore.saveEntry(historyEntry);

        if (mounted) {
          setState(() {
            _history = [historyEntry, ..._history];
          });
        }
      }
    } catch (_) {
      _showSnackBar('Detection failed. Check the API and try again.');
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
      appBar: AppBar(
        title: const Text('Plant Disease Detector'),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh history',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildScanTab(), _buildHistoryTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
        await _loadPlants();
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
                  'Pick a plant, upload a photo, and keep the result on this device.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantPickerCard() {
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
            if (_loadingPlants)
              const Center(child: CircularProgressIndicator())
            else if (_plantError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_plantError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadPlants,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedPlantId,
                items: _plants
                    .map(
                      (plant) => DropdownMenuItem(
                        value: plant.id,
                        child: Text(
                          plant.scientificName.isEmpty
                              ? plant.name
                              : '${plant.name} (${plant.scientificName})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlantId = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Plant',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
            if (_actionMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _actionMessage!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
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
          ],
        ),
      ),
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
                  child: entry.imageUrl == null
                      ? const Icon(Icons.image_outlined)
                      : Image.network(entry.imageUrl!, fit: BoxFit.cover),
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
