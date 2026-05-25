import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart' show themeModeNotifier;
import '../models/detection_model.dart';
import '../services/history_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _HistorySearchScope { all, plant, disease }
enum _HistorySortMode    { newest, lowestConfidence }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final _historyStore = DetectionHistoryStore();
  final _picker       = ImagePicker();
  final _apiClient    = MidoriApiClient();

  // ── Navigation ─────────────────────────────────────────────────────────────
  int _currentIndex = 0;

  // ── Server health ──────────────────────────────────────────────────────────
  bool _serverReady = false;

  // ── Scan state ─────────────────────────────────────────────────────────────
  bool      _detecting              = false;
  XFile?    _selectedImage;
  Uint8List? _selectedImageBytes;
  Uint8List? _plantGradcamBytes;
  Uint8List? _diseaseGradcamBytes;

  DetectionApiResponse? _latestResult;
  String?               _scanFeedbackMessage;
  bool                  _scanFeedbackIsError = false;

  // Plant override dropdown — sourced from AppConstants (disease-model plants only)
  String? _selectedPlantOverride;   // null == Auto-detect

  // Confidence slider (matches notebook's Min Conf % slider)
  double _minConfidence = 40.0;   // 0–100 %

  // ── History state ──────────────────────────────────────────────────────────
  bool    _loadingHistory      = false;
  String? _historyErrorMessage;
  String? _historyErrorActionLabel;
  VoidCallback? _historyErrorAction;

  List<DetectionHistoryEntry> _history = [];
  final Set<String> _expandedHistoryCards = {};

  bool                _filterExpanded   = false;
  _HistorySearchScope _historySearchScope = _HistorySearchScope.all;
  _HistorySortMode    _historySortMode    = _HistorySortMode.newest;
  final _historySearchController = TextEditingController();

  // Pending save retry
  DetectionHistoryEntry? _pendingHistoryEntry;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _pingServer();
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    _apiClient.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Server health
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pingServer() async {
    final ready = await _apiClient.checkServerHealth();
    if (mounted) setState(() => _serverReady = ready);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // History CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _loadingHistory      = true;
      _historyErrorMessage = null;
    });
    try {
      final entries = await _historyStore.loadEntries();
      if (mounted) setState(() { _history = entries; _loadingHistory = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingHistory      = false;
          _historyErrorMessage = 'Could not load detection history.';
          _historyErrorActionLabel = 'Retry';
          _historyErrorAction  = _loadHistory;
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear();
    setState(() {
      _history.clear();
      _expandedHistoryCards.clear();
      _historySearchController.clear();
      _historySearchScope = _HistorySearchScope.all;
      _historySortMode    = _HistorySortMode.newest;
    });
  }

  Future<void> _saveHistoryEntry(DetectionHistoryEntry entry) async {
    try {
      await _historyStore.saveEntry(entry);
      if (!mounted) return;
      setState(() => _history.insert(0, entry));
    } catch (_) {
      _pendingHistoryEntry = entry;
      if (mounted) {
        _setScanFeedback(
          'Scan saved but history could not be written.',
          isError: true,
        );
      }
    }
  }

  Future<void> _retryPendingHistoryEntry() async {
    final pending = _pendingHistoryEntry;
    if (pending == null) return;
    _pendingHistoryEntry = null;
    await _saveHistoryEntry(pending);
  }

  Future<void> _deleteHistoryEntry(DetectionHistoryEntry entry) async {
    try {
      await _historyStore.deleteEntry(entry);
      if (!mounted) return;
      setState(() {
        _history.removeWhere(
          (e) => e.createdAt.toIso8601String() == entry.createdAt.toIso8601String(),
        );
        _expandedHistoryCards.remove(_historyCardKey(entry));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this entry. Please try again.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permissions & image picking
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return _requestPermission(
        Permission.camera, 'Camera permission is needed to take a photo.',
      );
    }
    // Gallery — Android 13+ and iOS grant access via picker natively.
    // For older Android (< SDK 33) we request storage permission.
    // We simply attempt the permission and grant if the user approves.
    final status = await Permission.photos.status;
    if (status.isDenied) {
      final result = await Permission.photos.request();
      if (result.isPermanentlyDenied) {
        if (mounted) {
          _setScanFeedback(
            'Photo access denied. Please enable it in Settings.',
            isError: true,
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<bool> _requestPermission(Permission permission, String reason) async {
    var perm = await permission.request();
    if (perm.isGranted) return true;
    if (perm.isPermanentlyDenied) {
      if (mounted) {
        _setScanFeedback(
          '$reason Please enable it in app Settings.',
          isError: true,
        );
      }
      return false;
    }
    if (mounted) _setScanFeedback(reason, isError: true);
    return false;
  }

  Future<void> _pickImage(ImageSource source) async {
    final ok = await _ensureMediaPermission(source);
    if (!ok) return;

    final file = await _picker.pickImage(
      source:     source,
      maxWidth:   1920,
      maxHeight:  1920,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _selectedImage       = file;
        _selectedImageBytes  = bytes;
        _plantGradcamBytes   = null;
        _diseaseGradcamBytes = null;
        _latestResult        = null;
        _scanFeedbackMessage = null;
      });
    }
  }

  void _retakePhoto() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a new photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detection
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runDetection() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      _setScanFeedback('Please select a leaf photo first.', isError: true);
      return;
    }

    if (_selectedImageBytes!.lengthInBytes > AppConstants.maxImageBytes) {
      _setScanFeedback('Image is too large (max 10 MB). Please choose a smaller photo.',
          isError: true);
      return;
    }

    // Ping server if not yet confirmed ready
    if (!_serverReady) {
      setState(() => _detecting = true);
      await _pingServer();
      if (!_serverReady) {
        if (mounted) {
          setState(() => _detecting = false);
          _setScanFeedback(
            'Cannot reach the server. Check your network connection.',
            isError: true,
          );
        }
        return;
      }
    }

    setState(() {
      _detecting           = true;
      _scanFeedbackMessage = null;
      _plantGradcamBytes   = null;
      _diseaseGradcamBytes = null;
    });

    try {
      final filename = _selectedImage!.name.isNotEmpty
          ? _selectedImage!.name
          : 'leaf.jpg';

      final response = await _apiClient.detectImage(
        imageBytes:          _selectedImageBytes!,
        filename:            filename,
        plantOverride:       _selectedPlantOverride,
        confidenceThreshold: _minConfidence,
      );

      if (!mounted) return;

      // ── Handle not_a_plant ─────────────────────────────────────────────
      if (response.status == 'not_a_plant') {
        setState(() {
          _detecting    = false;
          _latestResult = null;
        });
        _setScanFeedback(
          response.message ?? 'No plant detected. Please use a clear leaf photo.',
          isError: true,
        );
        return;
      }

      // ── Fetch both Grad-CAM images in parallel ─────────────────────────
      final plantGradcamUrl   = response.data?.plantGradcamImageUrl;
      final diseaseGradcamUrl = response.data?.gradcamImageUrl;

      final results = await Future.wait([
        _apiClient.fetchBytes(plantGradcamUrl),
        _apiClient.fetchBytes(diseaseGradcamUrl),
      ]);

      if (!mounted) return;

      setState(() {
        _latestResult        = response;
        _detecting           = false;
        _plantGradcamBytes   = results[0];
        _diseaseGradcamBytes = results[1];
        if (response.status == 'not_recognized') {
          _scanFeedbackMessage = null;
        }
      });

      // ── Save history entry ─────────────────────────────────────────────
      if (response.data != null) {
        final entry = DetectionHistoryEntry.fromDetection(
          response.data!,
          response.message,
          imageBytes:        _selectedImageBytes,
          gradcamBytes:      results[1],
          plantGradcamBytes: results[0],
        );
        await _saveHistoryEntry(entry);
      }
    } on MidoriApiException catch (e) {
      if (!mounted) return;
      setState(() => _detecting = false);
      _setScanFeedback(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _detecting = false);
      _setScanFeedback('An unexpected error occurred. Please try again.', isError: true);
    }
  }

  void _setScanFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _scanFeedbackMessage = message;
      _scanFeedbackIsError = isError;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  EdgeInsets _responsivePadding(BoxConstraints c) {
    final h = c.maxWidth > 600 ? 24.0 : 16.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: 16);
  }

  Color _surfaceVariant(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark ? AppColors.gray800 : AppColors.green50;
  }

  Color _borderColor(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark ? AppColors.gray700 : AppColors.green100;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌿', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text(
              'Midori',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Server-ready indicator
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: _serverReady ? 'Server connected' : 'Server offline',
              child: Icon(
                _serverReady ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 20,
                color: _serverReady ? AppColors.green500 : AppColors.error,
              ),
            ),
          ),
          // Theme toggle
          Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              onPressed: () {
                themeModeNotifier.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildScanTab(),
          _buildHistoryTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner_rounded),
            label:        'Scan',
          ),
          NavigationDestination(
            icon:         Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label:        'History',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scan tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _pingServer,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 32),
              children: [
                _buildPlantOverrideDropdown(),
                const SizedBox(height: 8),
                _buildConfidenceSlider(),
                const SizedBox(height: 12),
                _buildImageCard(),
                if (_detecting) ...[
                  const SizedBox(height: 12),
                  _buildNoticeCard(
                    icon:    Icons.hourglass_top_rounded,
                    title:   'Analysing leaf…',
                    message: 'Stage 1: identifying plant. Stage 2: detecting disease. '
                             'Generating Grad-CAM heatmaps.',
                    iconColor:    AppColors.green500,
                    showProgress: true,
                  ),
                ],
                if (_scanFeedbackMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildNoticeCard(
                    icon:      _scanFeedbackIsError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    title:     _scanFeedbackIsError ? 'Problem' : 'Note',
                    message:   _scanFeedbackMessage!,
                    iconColor: _scanFeedbackIsError ? AppColors.error : AppColors.green500,
                    actionLabel: _pendingHistoryEntry != null ? 'Retry save' : null,
                    onAction:    _pendingHistoryEntry != null
                        ? _retryPendingHistoryEntry : null,
                  ),
                ],
                if (_latestResult != null) ...[
                  const SizedBox(height: 12),
                  _buildResultCard(_latestResult!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Plant override dropdown
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPlantOverrideDropdown() {
    return Row(
      children: [
        const Text(
          'Plant override:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue:       _selectedPlantOverride,
            isExpanded:  true,
            decoration:  InputDecoration(
              isDense:         true,
              contentPadding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Auto-detect  (Stage 1 runs)'),
              ),
              ...AppConstants.plantOverrideOptions.map(
                (p) => DropdownMenuItem<String?>(value: p, child: Text(p)),
              ),
            ],
            onChanged: (v) => setState(() => _selectedPlantOverride = v),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Confidence slider
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConfidenceSlider() {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final accent  = AppColors.green500;
    final bgColor = isDark ? AppColors.gray800 : AppColors.green50;
    final border  = isDark ? AppColors.gray700 : AppColors.green100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 15, color: accent),
                  const SizedBox(width: 6),
                  const Text(
                    'Min Confidence',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_minConfidence.round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   13,
                    color:      accent,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight:          3,
              thumbShape:           const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:         const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor:     accent,
              inactiveTrackColor:   accent.withValues(alpha: 0.18),
              thumbColor:           accent,
              overlayColor:         accent.withValues(alpha: 0.15),
              tickMarkShape:        const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
              activeTickMarkColor:  Colors.white,
              inactiveTickMarkColor: accent.withValues(alpha: 0.4),
            ),
            child: Slider(
              value:     _minConfidence,
              min:       0,
              max:       100,
              divisions: 20,            // steps of 5%
              onChanged: (v) => setState(() => _minConfidence = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0%', '25%', '50%', '75%', '100%']
                .map((t) => Text(t,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)))
                .toList(),
          ),
          const SizedBox(height: 4),
          Text(
            _minConfidence < 20
                ? 'Very lenient — almost any image accepted'
                : _minConfidence < 40
                    ? 'Lenient — accepts uncertain identifications'
                    : _minConfidence < 60
                        ? 'Balanced — recommended for most images'
                        : _minConfidence < 80
                            ? 'Strict — requires clear, well-lit photos'
                            : 'Very strict — only high-quality photos pass',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildImageCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildThreePanelPreview(),
            const SizedBox(height: 16),
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _detecting ? null : () => _pickImage(ImageSource.gallery),
                    icon:  const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _detecting ? null : () => _pickImage(ImageSource.camera),
                    icon:  const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _detecting || _selectedImage == null
                    ? null
                    : _runDetection,
                icon:  _detecting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.biotech_rounded),
                label: Text(
                  _detecting ? 'Analysing…' : 'Detect Disease',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreePanelPreview() {
    if (_selectedImageBytes == null) {
      return GestureDetector(
        onTap: () => _pickImage(ImageSource.gallery),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: _surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor(context),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 48, color: AppColors.green400),
              const SizedBox(height: 8),
              const Text('Tap to select a leaf photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('JPG, PNG or WebP · max 10 MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildPreviewTile(
            title:           'Original',
            fullscreenBytes: _selectedImageBytes,
            child:           Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPreviewTile(
            title:           'Plant CAM',
            fullscreenBytes: _plantGradcamBytes,
            child:           _plantGradcamBytes != null
                ? Image.memory(_plantGradcamBytes!, fit: BoxFit.cover)
                : _gradcamPlaceholder(_detecting ? 'Stage 1…' : 'Stage 1\nnot available'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPreviewTile(
            title:           'Disease CAM',
            fullscreenBytes: _diseaseGradcamBytes,
            child:           _diseaseGradcamBytes != null
                ? Image.memory(_diseaseGradcamBytes!, fit: BoxFit.cover)
                : _gradcamPlaceholder(_detecting ? 'Stage 2…' : 'Stage 2\nnot available'),
          ),
        ),
      ],
    );
  }

  Widget _gradcamPlaceholder(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11)),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Result card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultCard(DetectionApiResponse response) {
    final result = response.data;
    if (result == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Status banner ────────────────────────────────────────────
            _buildStatusBanner(response, result),
            const SizedBox(height: 16),

            // ── Stage 1 — Plant confidence ───────────────────────────────
            _buildStageConfidenceBar(
              stageLabel:  'Stage 1 — Plant',
              label:       result.plantName.isEmpty ? 'Unknown' : result.plantName,
              confidence:  result.plantConfidence,
              gradcamBytes: _plantGradcamBytes,
            ),
            const SizedBox(height: 12),

            // ── Stage 2 — Disease confidence ─────────────────────────────
            if (result.diseaseName != null || response.effectivelyHealthy) ...[
              _buildStageConfidenceBar(
                stageLabel:  'Stage 2 — Disease',
                label:       response.effectivelyHealthy
                    ? 'Healthy 🌱'
                    : (result.diseaseName ?? 'Unknown'),
                confidence:  result.confidence,
                gradcamBytes: _diseaseGradcamBytes,
              ),
              const SizedBox(height: 16),
            ],

            // ── All plant scores ─────────────────────────────────────────
            if (result.plantScores.isNotEmpty) ...[
              _buildAllScoresSection(
                title:   'Plant identification scores',
                scores:  result.plantScores,
                winnerName: result.plantName,
              ),
              const SizedBox(height: 12),
            ],

            // ── All disease scores ────────────────────────────────────────
            if (result.diseaseScores.isNotEmpty) ...[
              _buildAllScoresSection(
                title:     'Disease detection scores',
                scores:    result.diseaseScores,
                winnerName: response.effectivelyHealthy ? 'Healthy' : (result.diseaseName ?? ''),
                isDisease: true,
              ),
              const SizedBox(height: 16),
            ],

            // ── Disease details (only for actual diseases, not healthy) ──────────
            if (!response.effectivelyHealthy &&
                response.status != 'not_recognized' &&
                response.status != 'no_model') ...[
              _buildDetailGroup(
                title: 'Diagnosis details',
                children: [
                  if (result.diseaseCause != null)
                    _DetailLine(label: 'Cause',      value: result.diseaseCause!),
                  if (result.diseaseDescription != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(label: 'Description', value: result.diseaseDescription!),
                  ],
                  if (result.diseaseRemedy != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(label: 'Remedy',     value: result.diseaseRemedy!),
                  ],
                  if (result.diseasePrevention != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(label: 'Prevention', value: result.diseasePrevention!),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Treatment advice ──────────────────────────────────────────
            if (result.advice != null && result.advice!.isNotEmpty) ...[
              _buildDetailGroup(
                title: '💊 Treatment Advice',
                children: [
                  Text(
                    result.advice!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Healthy care tips ─────────────────────────────────────────
            if (response.effectivelyHealthy) ...[
              _buildDetailGroup(
                title: 'Keep it healthy 🌿',
                children: const [
                  _DetailLine(
                    label: 'Watering',
                    value: 'Water consistently but avoid waterlogging. '
                           'Check soil moisture before each watering.',
                  ),
                  SizedBox(height: 10),
                  _DetailLine(
                    label: 'Sunlight',
                    value: 'Ensure adequate sunlight. Rotate periodically for even growth.',
                  ),
                  SizedBox(height: 10),
                  _DetailLine(
                    label: 'Prevention',
                    value: 'Inspect leaves regularly. Remove dead leaves and maintain airflow.',
                  ),
                ],
              ),
            ],

            // ── Low-confidence scan tips ──────────────────────────────────
            if (response.status == 'low_confidence') ...[
              const SizedBox(height: 12),
              _buildDetailGroup(
                title: 'Tips for a better scan',
                children: const [
                  _DetailLine(label: 'Background',
                      value: 'Use a plain white/grey surface behind the leaf.'),
                  SizedBox(height: 10),
                  _DetailLine(label: 'Lighting',
                      value: 'Scan in bright natural light. Avoid shadows or flash.'),
                  SizedBox(height: 10),
                  _DetailLine(label: 'Framing',
                      value: 'Fill the frame with the affected leaf.'),
                  SizedBox(height: 10),
                  _DetailLine(label: 'Focus',
                      value: 'Make sure lesions are sharply in focus.'),
                ],
              ),
            ],

            // ── Retake / scan-again buttons ────────────────────────────────
            const SizedBox(height: 14),

            // Prominent orange "Retake" only on low-quality results
            if (response.status == 'low_confidence' ||
                response.status == 'not_recognized') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD84315),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _retakePhoto,
                icon:  const Icon(Icons.camera_alt_rounded),
                label: const Text('Retake Photo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
            ],

            // Always available: scan a different leaf
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _retakePhoto,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Scan Another Leaf',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status banner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatusBanner(DetectionApiResponse response, DetectionResult result) {
    Color bg, border, fg;
    IconData icon;
    String title;

    switch (response.status) {
      case 'healthy':
        bg     = AppColors.green600.withValues(alpha: 0.10);
        border = AppColors.green600.withValues(alpha: 0.35);
        fg     = AppColors.green600;
        icon   = Icons.check_circle_rounded;
        title  = 'Healthy Plant — No disease detected! 🌱';
        break;
      case 'success':
        // Backend returns status='success' even when disease_name is 'Healthy'
        if (response.effectivelyHealthy) {
          bg     = AppColors.green600.withValues(alpha: 0.10);
          border = AppColors.green600.withValues(alpha: 0.35);
          fg     = AppColors.green600;
          icon   = Icons.check_circle_rounded;
          title  = 'Healthy Plant — No disease detected! 🌱';
        } else {
          bg     = const Color(0xFF1565C0).withValues(alpha: 0.08);
          border = const Color(0xFF1565C0).withValues(alpha: 0.28);
          fg     = const Color(0xFF1565C0);
          icon   = Icons.biotech_rounded;
          title  = result.diseaseName ?? 'Disease Detected';
        }
        break;
      case 'not_recognized':
        bg     = const Color(0xFF6A1B9A).withValues(alpha: 0.08);
        border = const Color(0xFF6A1B9A).withValues(alpha: 0.30);
        fg     = const Color(0xFF6A1B9A);
        icon   = Icons.help_outline_rounded;
        title  = 'Plant Not Recognised';
        break;
      case 'no_model':
        bg     = const Color(0xFF1565C0).withValues(alpha: 0.08);
        border = const Color(0xFF1565C0).withValues(alpha: 0.30);
        fg     = const Color(0xFF1565C0);
        icon   = Icons.science_outlined;
        title  = '${result.plantName} — No Disease Model Yet';
        break;
      case 'low_confidence':
        bg     = const Color(0xFFD84315).withValues(alpha: 0.09);
        border = const Color(0xFFD84315).withValues(alpha: 0.35);
        fg     = const Color(0xFFD84315);
        icon   = Icons.warning_amber_rounded;
        title  = 'Low Confidence — Retake Recommended';
        break;
      default:
        bg     = const Color(0xFF1565C0).withValues(alpha: 0.08);
        border = const Color(0xFF1565C0).withValues(alpha: 0.28);
        fg     = const Color(0xFF1565C0);
        icon   = Icons.biotech_rounded;
        title  = result.diseaseName ?? 'Disease Detected';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: fg, fontSize: 15)),
                if (response.message != null && response.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(response.message!,
                      style: TextStyle(fontSize: 13,
                          color: fg.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage confidence bar  (single row with label + coloured bar)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStageConfidenceBar({
    required String stageLabel,
    required String label,
    required double confidence,
    Uint8List? gradcamBytes,
  }) {
    final pct   = confidence * 100;
    final color = pct >= 80
        ? AppColors.green600
        : pct >= 55
            ? const Color(0xFFF9A825)
            : const Color(0xFFD84315);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stageLabel,
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color, letterSpacing: 0.4)),
              const Spacer(),
              Text('${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: confidence),
              duration: const Duration(milliseconds: 900),
              curve:    Curves.easeOutCubic,
              builder:  (_, val, __) => LinearProgressIndicator(
                value:           val,
                minHeight:       10,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor:      AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // All-class scores  (mini bar chart)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAllScoresSection({
    required String title,
    required List<ConfidenceScore> scores,
    required String winnerName,
    bool isDisease = false,
  }) {
    final sorted = List<ConfidenceScore>.from(scores)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return _buildDetailGroup(
      title: title,
      children: sorted.map((score) {
        final pct       = score.confidence * 100;
        final isWinner  = score.name.toLowerCase() == winnerName.toLowerCase();
        final barColor  = isWinner
            ? (pct >= 80
                ? AppColors.green600
                : pct >= 55
                    ? const Color(0xFFF9A825)
                    : const Color(0xFFD84315))
            : Colors.grey.shade400;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      score.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                        color: isWinner ? barColor : null,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           score.confidence,
                  minHeight:       6,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor:      AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // History tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final visible = _filteredHistoryEntries();

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 24),
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
                      onPressed: _history.isEmpty
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Clear all history?'),
                                  content: const Text(
                                    'This will permanently delete all saved scans. '
                                    'This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Clear all',
                                          style:
                                              TextStyle(color: Color(0xFFD32F2F))),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) await _clearHistory();
                            },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHistoryControls(),
                const SizedBox(height: 12),
                if (_loadingHistory)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ))
                else if (_historyErrorMessage != null)
                  _buildNoticeCard(
                    icon:        Icons.cloud_off_outlined,
                    title:       'History unavailable',
                    message:     _historyErrorMessage!,
                    iconColor:   AppColors.error,
                    actionLabel: _historyErrorActionLabel,
                    onAction:    _historyErrorAction,
                  )
                else if (_history.isEmpty)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off,
                              size: 48, color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          const Text('No detection history yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text('Run a scan and it will appear here.'),
                        ],
                      ),
                    ),
                  )
                else if (visible.isEmpty)
                  _buildNoticeCard(
                    icon:        Icons.manage_search_outlined,
                    title:       'No matches',
                    message:     'Try a different search term or filter.',
                    iconColor:   AppColors.green500,
                    actionLabel: 'Clear search',
                    onAction:    () => setState(() {
                      _historySearchController.clear();
                      _historySearchScope = _HistorySearchScope.all;
                      _historySortMode    = _HistorySortMode.newest;
                    }),
                  )
                else ...[
                  Text(
                    '${visible.length} result${visible.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...visible.map(_buildHistoryCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryControls() {
    final cs            = Theme.of(context).colorScheme;
    final hasActiveFilter = _historySearchScope != _HistorySearchScope.all ||
        _historySortMode != _HistorySortMode.newest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _historySearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon:     const Icon(Icons.search, size: 20),
                  hintText:       'Search history…',
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border:         OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _historySearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _historySearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Filter & Sort',
                  style: IconButton.styleFrom(
                    backgroundColor: _filterExpanded
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(_filterExpanded ? Icons.tune : Icons.tune_outlined,
                      size: 20),
                  onPressed: () =>
                      setState(() => _filterExpanded = !_filterExpanded),
                ),
                if (hasActiveFilter)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve:    Curves.easeInOut,
          child: _filterExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSegmentRow<_HistorySearchScope>(
                          label:    'Filter',
                          options:  const [
                            (_HistorySearchScope.all,     'All'),
                            (_HistorySearchScope.plant,   'Plant'),
                            (_HistorySearchScope.disease, 'Disease'),
                          ],
                          selected: _historySearchScope,
                          onSelected: (v) =>
                              setState(() => _historySearchScope = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSegmentRow<_HistorySortMode>(
                          label:   'Sort',
                          options: const [
                            (_HistorySortMode.newest,          'Newest'),
                            (_HistorySortMode.lowestConfidence,'Lowest %'),
                          ],
                          selected: _historySortMode,
                          onSelected: (v) =>
                              setState(() => _historySortMode = v),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSegmentRow<T>({
    required String label,
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: options.map((opt) {
            final (value, text) = opt;
            final isSelected    = selected == value;
            return ChoiceChip(
              label: Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? cs.onPrimary : cs.onSurface)),
              selected:      isSelected,
              selectedColor: cs.primary,
              padding:       const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              onSelected:    (_) => onSelected(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<DetectionHistoryEntry> _filteredHistoryEntries() {
    final query    = _historySearchController.text.trim().toLowerCase();
    final filtered = _history.where((entry) {
      if (query.isEmpty) return true;
      switch (_historySearchScope) {
        case _HistorySearchScope.all:
          return _entryMatchesAny(entry, query);
        case _HistorySearchScope.plant:
          return entry.plantName.toLowerCase().contains(query);
        case _HistorySearchScope.disease:
          return _entryMatchesDisease(entry, query);
      }
    }).toList();

    filtered.sort((l, r) {
      switch (_historySortMode) {
        case _HistorySortMode.newest:
          return r.createdAt.compareTo(l.createdAt);
        case _HistorySortMode.lowestConfidence:
          final cmp = l.confidence.compareTo(r.confidence);
          return cmp != 0 ? cmp : r.createdAt.compareTo(l.createdAt);
      }
    });
    return filtered;
  }

  bool _entryMatchesAny(DetectionHistoryEntry e, String q) =>
      e.plantName.toLowerCase().contains(q) ||
      (e.diseaseName?.toLowerCase().contains(q) ?? false) ||
      (e.diseaseCause?.toLowerCase().contains(q) ?? false) ||
      (e.diseaseDescription?.toLowerCase().contains(q) ?? false) ||
      (e.diseaseRemedy?.toLowerCase().contains(q) ?? false) ||
      (e.advice?.toLowerCase().contains(q) ?? false);

  bool _entryMatchesDisease(DetectionHistoryEntry e, String q) =>
      (e.diseaseName?.toLowerCase().contains(q) ?? false) ||
      (e.diseaseCause?.toLowerCase().contains(q) ?? false) ||
      (e.diseaseDescription?.toLowerCase().contains(q) ?? false) ||
      (e.advice?.toLowerCase().contains(q) ?? false);

  String _historyCardKey(DetectionHistoryEntry entry) =>
      entry.createdAt.toIso8601String();

  // ─────────────────────────────────────────────────────────────────────────
  // History card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryCard(DetectionHistoryEntry entry) {
    final key            = _historyCardKey(entry);
    final isExpanded     = _expandedHistoryCards.contains(key);
    final isLowConf      = entry.confidence < 0.55;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key:       ValueKey(key),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding:   const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color:        const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('Delete',
                  style: TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        confirmDismiss: (_) async => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:   const Text('Delete entry?'),
            content: Text('Remove "${entry.diseaseName ?? 'this entry'}" from history?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Color(0xFFD32F2F)))),
            ],
          ),
        ).then((v) => v ?? false),
        onDismissed: (_) => _deleteHistoryEntry(entry),
        child: Card(
          elevation: 0,
          child: ExpansionTile(
            key:             PageStorageKey<String>('hist-$key'),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (exp) => setState(() {
              if (exp) {
                _expandedHistoryCards.add(key);
              } else {
                _expandedHistoryCards.remove(key);
              }
            }),
            tilePadding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Builder(builder: (ctx) => Container(
                width: 56, height: 56,
                color: _surfaceVariant(ctx),
                child: entry.imageBytes == null
                    ? const Icon(Icons.image_outlined)
                    : Image.memory(entry.imageBytes!, fit: BoxFit.cover),
              )),
            ),
            title: Text(
              (entry.isHealthy || entry.diseaseName?.toLowerCase() == 'healthy')
                  ? '${entry.plantName} — Healthy 🌱'
                  : (entry.diseaseName ?? 'No disease matched'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.plantName),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Plant confidence chip
                      _ConfidenceChip(
                        confidence: entry.plantConfidence,
                        label:      'Plant',
                      ),
                      // Disease confidence chip
                      _ConfidenceChip(
                        confidence: entry.confidence,
                        label:      'Disease',
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(entry.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Three-panel preview (original + plant CAM + disease CAM)
              if (entry.imageBytes != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildPreviewTile(
                        title:           'Original',
                        fullscreenBytes: entry.imageBytes,
                        child:           Image.memory(entry.imageBytes!, fit: BoxFit.cover),
                      ),
                    ),
                    if (entry.plantGradcamBytes != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPreviewTile(
                          title:           'Plant CAM',
                          fullscreenBytes: entry.plantGradcamBytes,
                          child:           Image.memory(entry.plantGradcamBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                    if (entry.gradcamBytes != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPreviewTile(
                          title:           'Disease CAM',
                          fullscreenBytes: entry.gradcamBytes,
                          child:           Image.memory(entry.gradcamBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _buildDetailGroup(
                title: 'Details',
                children: [
                  // Plant & disease confidence
                  Row(
                    children: [
                      Expanded(child: _buildMiniConfidenceBar(
                        label: 'Plant (${entry.plantName})',
                        confidence: entry.plantConfidence,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMiniConfidenceBar(
                        label: 'Disease${entry.diseaseName != null ? ' (${entry.diseaseName!})' : ''}',
                        confidence: entry.confidence,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (entry.isHealthy) ...[
                    const _DetailLine(
                        label: 'Status',
                        value: '✅ No disease detected — plant looks healthy!'),
                  ] else ...[
                    if (entry.diseaseCause != null)
                      _DetailLine(label: 'Cause', value: entry.diseaseCause!),
                    if (entry.diseaseDescription != null) ...[
                      const SizedBox(height: 10),
                      _DetailLine(label: 'Description', value: entry.diseaseDescription!),
                    ],
                    if (entry.diseaseRemedy != null) ...[
                      const SizedBox(height: 10),
                      _DetailLine(label: 'Remedy', value: entry.diseaseRemedy!),
                    ],
                    if (entry.diseasePrevention != null) ...[
                      const SizedBox(height: 10),
                      _DetailLine(label: 'Prevention', value: entry.diseasePrevention!),
                    ],
                  ],
                  if (entry.advice != null && entry.advice!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailLine(label: 'Advice', value: entry.advice!),
                  ],
                  if (isLowConf && entry.message != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(
                      label:      'Note',
                      value:      entry.message!,
                      valueColor: Colors.orange.shade800,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniConfidenceBar({
    required String label,
    required double confidence,
  }) {
    final pct   = confidence * 100;
    final color = pct >= 80
        ? AppColors.green600
        : pct >= 55
            ? const Color(0xFFF9A825)
            : const Color(0xFFD84315);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           confidence,
            minHeight:       6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor:      AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared UI components
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreviewTile({
    required String title,
    required Widget child,
    Uint8List? fullscreenBytes,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void openFullscreen() {
      if (fullscreenBytes == null) return;
      showDialog<void>(
        context:      context,
        barrierColor: Colors.black87,
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(fullscreenBytes, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 0, right: 0,
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
        ),
      );
    }

    return GestureDetector(
      onTap: fullscreenBytes != null ? openFullscreen : null,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color:        isDark ? AppColors.gray800 : AppColors.green50,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
              color: isDark ? AppColors.gray700 : AppColors.green100),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.03),
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8, right: 8, bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    if (fullscreenBytes != null) ...const [
                      SizedBox(width: 3),
                      Icon(Icons.fullscreen, color: Colors.white, size: 14),
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

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String message,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    bool showProgress = false,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? AppColors.green500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 14)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                          onPressed: onAction,
                          child: Text(actionLabel)),
                    ),
                  ],
                ],
              ),
            ),
            if (showProgress)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Color-coded confidence badge for history cards.
class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence, this.label});
  final double confidence;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct    = confidence * 100;

    final Color bg, fg;
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: fg.withValues(alpha: 0.30)),
      ),
      child: Text(
        label != null ? '$label ${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Bold label + muted value row.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Builder(builder: (ctx) => Text(
          value,
          style: TextStyle(
            color: valueColor ??
                Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        )),
      ],
    );
  }
}
