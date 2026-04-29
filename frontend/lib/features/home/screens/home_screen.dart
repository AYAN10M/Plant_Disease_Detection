import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../main.dart' show themeModeNotifier;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../models/detection_record.dart';
import '../services/detection_history_store.dart';

// Helper: returns a theme-aware subtle fill color
Color _surfaceVariant(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? AppColors.gray800 : AppColors.gray100;
}
Color _borderColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? AppColors.gray700 : AppColors.gray200;
}

enum _HistorySearchScope { all, plant, disease }

enum _HistorySortMode { newest, lowestConfidence }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DetectionHistoryStore _historyStore = DetectionHistoryStore();
  final ImagePicker _picker = ImagePicker();
  final MidoriApiClient _apiClient = MidoriApiClient();
  final TextEditingController _historySearchController =
      TextEditingController();

  int _currentIndex = 0;
  bool _loadingHistory = true;
  bool _detecting = false;
  bool _serverReady = false;   // true once health check passes
  bool _filterExpanded = false;
  List<DetectionHistoryEntry> _history = [];
  final Set<String> _expandedHistoryCards = <String>{};
  _HistorySearchScope _historySearchScope = _HistorySearchScope.all;
  _HistorySortMode _historySortMode = _HistorySortMode.newest;
  String? _scanFeedbackMessage;
  String? _scanFeedbackActionLabel;
  VoidCallback? _scanFeedbackAction;
  String? _historyErrorMessage;
  String? _historyErrorActionLabel;
  VoidCallback? _historyErrorAction;
  DetectionHistoryEntry? _pendingHistoryEntry;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  Uint8List? _gradcamBytes;
  DetectionApiResponse? _latestResult;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _pingServer();
  }

  Future<void> _pingServer() async {
    final ready = await _apiClient.checkServerHealth();
    if (mounted) setState(() => _serverReady = ready);
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyErrorMessage = null;
      _historyErrorActionLabel = null;
      _historyErrorAction = null;
    });

    try {
      final entries = await _historyStore.loadEntries();
      if (!mounted) {
        return;
      }

      setState(() {
        _history = entries;
        _loadingHistory = false;
        _expandedHistoryCards.removeWhere(
          (key) => !entries.any((entry) => _historyCardKey(entry) == key),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingHistory = false;
        _historyErrorMessage =
            'Could not load saved scans. Please check storage access and try again.';
        _historyErrorActionLabel = 'Retry';
        _historyErrorAction = _loadHistory;
      });
    }
  }

  void _setScanFeedback(
    String message, {
    String? actionLabel,
    VoidCallback? action,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _scanFeedbackMessage = message;
      _scanFeedbackActionLabel = actionLabel;
      _scanFeedbackAction = action;
    });
  }

  void _clearScanFeedback() {
    if (!mounted) {
      return;
    }

    setState(() {
      _scanFeedbackMessage = null;
      _scanFeedbackActionLabel = null;
      _scanFeedbackAction = null;
    });
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    if (kIsWeb) {
      return true;
    }

    if (source == ImageSource.camera) {
      return _requestPermission(
        Permission.camera,
        deniedMessage:
            'Camera access is off. Allow it to take a fresh leaf photo.',
        permanentlyDeniedMessage:
            'Camera access is blocked. Open settings to enable it.',
        retryAction: () => _pickImage(ImageSource.camera),
      );
    }

    // On Android 13+ (API 33+) READ_EXTERNAL_STORAGE is replaced by
    // READ_MEDIA_IMAGES. The image_picker plugin handles the picker UI
    // itself and does NOT require us to pre-request storage permission
    // — doing so actually causes a denial on many devices. We only
    // need to request the legacy permission on older Android builds.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final sdkInfo = await Permission.storage.status;
      // If storage is already permanently denied, the system is old
      // enough that we need it — guide the user to settings.
      if (sdkInfo.isPermanentlyDenied) {
        _setScanFeedback(
          'Photo access is blocked. Open settings to enable it.',
          actionLabel: 'Open settings',
          action: openAppSettings,
        );
        return false;
      }
      // Otherwise, skip the permission dialog and let the OS picker handle it.
      return true;
    }

    // iOS / macOS — always need explicit photos permission.
    return _requestPermission(
      Permission.photos,
      deniedMessage:
          'Photo access is off. Allow it to pick an image from your gallery.',
      permanentlyDeniedMessage:
          'Photo access is blocked. Open settings to enable it.',
      retryAction: () => _pickImage(ImageSource.gallery),
    );
  }

  Future<bool> _requestPermission(
    Permission permission, {
    required String deniedMessage,
    required String permanentlyDeniedMessage,
    required VoidCallback retryAction,
  }) async {
    final status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _setScanFeedback(
        permanentlyDeniedMessage,
        actionLabel: 'Open settings',
        action: openAppSettings,
      );
    } else {
      _setScanFeedback(
        deniedMessage,
        actionLabel: 'Try again',
        action: retryAction,
      );
    }

    return false;
  }

  Future<bool> _pickImage(ImageSource source) async {
    _clearScanFeedback();

    if (!await _ensureMediaPermission(source)) {
      return false;
    }

    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) {
        return false;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) {
        return false;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _gradcamBytes = null;
        _latestResult = null;
        _pendingHistoryEntry = null;
      });

      return true;
    } catch (_) {
      _setScanFeedback(
        'Could not open the photo picker. Please try again.',
        actionLabel: 'Retry',
        action: () => _pickImage(source),
      );
      return false;
    }
  }

  Future<void> _retakePhoto() async {
    // Show a bottom sheet so the user can choose camera or gallery
    if (!mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Retake photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a new photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _runDetection() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      _setScanFeedback(
        'Pick an image to analyze.',
        actionLabel: 'Choose photo',
        action: () => _pickImage(ImageSource.gallery),
      );
      return;
    }

    // Quick server health probe before committing to a long upload
    if (!_serverReady) {
      setState(() => _detecting = true);
      _serverReady = await _apiClient.checkServerHealth();
      if (!mounted) return;
      if (!_serverReady) {
        setState(() => _detecting = false);
        _setScanFeedback(
          'Cannot reach the backend server. Start it with:\n'
          'cd backend  ->  python manage.py runserver 0.0.0.0:8000',
          actionLabel: 'Retry',
          action: _runDetection,
        );
        return;
      }
      setState(() => _detecting = false);
    }

    // Guard: reject images over 10 MB to avoid OOM and very slow uploads.
    const int maxBytes = 10 * 1024 * 1024;
    if (_selectedImageBytes!.length > maxBytes) {
      _setScanFeedback(
        'The selected image is too large (max 10 MB). Please choose a smaller photo.',
        actionLabel: 'Choose photo',
        action: () => _pickImage(ImageSource.gallery),
      );
      return;
    }

    _clearScanFeedback();

    setState(() {
      _detecting = true;
      _latestResult = null;
    });

    try {
      final response = await _apiClient.detectImage(
        imageBytes: _selectedImageBytes!,
        filename: _selectedImage!.name,
      );

      if (!mounted) return;
      setState(() => _latestResult = response);

      // Not a plant — show feedback, clear result so no blank card shows.
      if (response.status == 'not_a_plant') {
        setState(() => _latestResult = null);
        _setScanFeedback(
          response.message ?? '🌿 Please provide a clear photo of a plant leaf.',
          actionLabel: 'Choose another photo',
          action: () => _pickImage(ImageSource.gallery),
        );
        return;
      }

      final result = response.data;
      if (result == null) {
        throw MidoriApiException('The detection API returned no prediction data.');
      }

      final gradcamBytes = await _apiClient.fetchBytes(result.gradcamImageUrl);
      if (mounted && gradcamBytes != null) {
        setState(() => _gradcamBytes = gradcamBytes);
      }

      // Save to history for BOTH success and low_confidence results.
      final historyEntry = DetectionHistoryEntry.fromDetection(
        result: result,
        message: response.message,
        imageBytes: _selectedImageBytes,
        gradcamBytes: gradcamBytes,
      );
      await _saveHistoryEntry(historyEntry);
    } on MidoriApiException catch (error) {
      // Handle not-a-plant response surfaced via status field
      if (_latestResult?.status == 'not_a_plant') {
        _setScanFeedback(
          '🌿 Please provide a clear photo of a plant leaf.',
          actionLabel: 'Choose another photo',
          action: () => _pickImage(ImageSource.gallery),
        );
      } else {
        _setScanFeedback(
          error.message,
          actionLabel: 'Retry detection',
          action: _runDetection,
        );
      }
    } catch (_) {
      _setScanFeedback(
        'Detection failed. Please check the backend connection and try again.',
        actionLabel: 'Retry detection',
        action: _runDetection,
      );
    } finally {
      if (mounted) {
        setState(() {
          _detecting = false;
        });
      }
    }
  }

  Future<void> _saveHistoryEntry(DetectionHistoryEntry entry) async {
    try {
      await _historyStore.saveEntry(entry);
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingHistoryEntry = null;
        _history = [entry, ..._history];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingHistoryEntry = entry;
      });

      _setScanFeedback(
        'The result was generated, but saving it to history failed.',
        actionLabel: 'Retry save',
        action: _retryPendingHistoryEntry,
      );
    }
  }

  Future<void> _retryPendingHistoryEntry() async {
    final entry = _pendingHistoryEntry;
    if (entry == null) {
      return;
    }

    await _saveHistoryEntry(entry);
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _history = [];
      _expandedHistoryCards.clear();
      _historySearchController.clear();
      _historySearchScope = _HistorySearchScope.all;
      _historySortMode = _HistorySortMode.newest;
    });
  }

  void _toggleTheme() {
    themeModeNotifier.value =
        themeModeNotifier.value == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌿 Midori'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: _toggleTheme,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildScanTab(), _buildHistoryTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
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

  Future<void> _onTabSelected(int index) async {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (index == 1) await _loadHistory();
  }

  // ignore: unused_element
  Widget _buildFloatingCuboidNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFDDDDDD);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
      onRefresh: _loadHistory,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 24),
              children: [
                _buildImageCard(),
                if (_detecting) ...[
                  const SizedBox(height: 16),
                  _buildLoadingNotice(
                    title: 'Analyzing photo',
                    message:
                        'Step 1: Checking if this is a plant leaf…\n'
                        'Step 2: Running MobileNetV2 + Grad-CAM inference.\n'
                        'First scan after server start may take 10–30 s.',
                  ),
                ],
                if (_scanFeedbackMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildNoticeCard(
                    icon: Icons.error_outline,
                    title: 'Something needs attention',
                    message: _scanFeedbackMessage!,
                    iconColor: Colors.orange.shade700,
                    actionLabel: _scanFeedbackActionLabel,
                    onAction: _scanFeedbackAction,
                  ),
                ],
                if (_latestResult != null) ...[
                  const SizedBox(height: 16),
                  _buildResultCard(_latestResult!),
                ],
              ],
            ),
          ),
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
              'Add photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: _buildPhotoPreviewArea(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text(
                      'Pick photo',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text(
                      'Click photo',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_detecting || _selectedImageBytes == null)
                        ? null
                        : _runDetection,
                    icon: _detecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _detecting ? 'Scanning...' : 'Detect',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The photo preview zone inside the image card — theme-aware.
  Widget _buildPhotoPreviewArea() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final emptyBg    = isDark ? AppColors.gray800 : AppColors.green50;
    final emptyBorder = isDark ? AppColors.gray700 : AppColors.green100;
    final gradcamBg  = isDark ? AppColors.gray900 : AppColors.green50;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: emptyBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: emptyBorder),
      ),
      child: _selectedImageBytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 44,
                  color: cs.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to choose a photo',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 320,
                      height: 204,
                      color: cs.surface,
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 320,
                      height: 204,
                      color: gradcamBg,
                      child: _detecting
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Generating heatmap…',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _gradcamBytes != null
                              ? Image.memory(
                                  _gradcamBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    'Grad-CAM\nappears after detection',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                    ),
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

    final isHealthy  = result.isHealthy;
    final isLowConf  = result.confidence < 0.60;
    final confidenceColor = result.confidence >= 0.80
        ? const Color(0xFF2E7D32)   // deep green
        : result.confidence >= 0.60
            ? const Color(0xFFF9A825) // amber
            : const Color(0xFFD84315); // deep orange-red

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Healthy plant banner ──────────────────────────────────────
            if (isHealthy) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2E7D32),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Healthy Plant — No disease detected! 🌱',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D32),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (response.message != null && response.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        response.message!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Low-confidence top banner ─────────────────────────────────
            if (!isHealthy && isLowConf) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD84315).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD84315).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD84315),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Low confidence — Retake recommended',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD84315),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (response.message != null &&
                        response.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        response.message!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD84315),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _retakePhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text(
                        'Retake Photo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Header: plant / disease name ──────────────────────────────
            Text(
              isHealthy
                  ? (result.plantName.isNotEmpty ? result.plantName : 'Plant')
                  : (result.diseaseName ?? 'No disease matched'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isHealthy
                  ? 'Status: Healthy ✅'
                  : 'Plant: ${result.plantName}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // ── Animated confidence bar ───────────────────────────────────
            _buildConfidenceBar(result.confidence, confidenceColor),

            // ── Side-by-side image previews (original + Grad-CAM) ─────────
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPreviewTile(
                      title: 'Original',
                      fullscreenBytes: _selectedImageBytes,
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPreviewTile(
                      title: 'Grad-CAM',
                      fullscreenBytes: _gradcamBytes,
                      child: _gradcamBytes != null
                          ? Image.memory(
                              _gradcamBytes!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  _detecting
                                      ? 'Generating heatmap…'
                                      : 'Heatmap not\navailable',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Disease details (only for diseased plants) ────────────────
            if (!isHealthy) ...[
              const SizedBox(height: 16),
              _buildDetailGroup(
                title: 'Prediction details',
                children: [
                  _DetailLine(
                    label: 'Cause',
                    value: result.diseaseCause ?? 'Not available yet',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Remedy',
                    value: result.diseaseRemedy ?? 'Not available yet',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Prevention',
                    value: result.diseasePrevention ?? 'Not available yet',
                  ),
                ],
              ),
              if (result.diseaseDescription != null) ...[
                const SizedBox(height: 12),
                _buildDetailGroup(
                  title: 'Description',
                  children: [Text(result.diseaseDescription!)],
                ),
              ],
            ],

            // ── Healthy care tips placeholder ─────────────────────────────
            if (isHealthy) ...[
              const SizedBox(height: 16),
              _buildDetailGroup(
                title: 'Keep it healthy 🌿',
                children: const [
                  _DetailLine(
                    label: 'Watering',
                    value:
                        'Water consistently but avoid waterlogging. '
                        'Check soil moisture before each watering.',
                  ),
                  SizedBox(height: 10),
                  _DetailLine(
                    label: 'Sunlight',
                    value:
                        'Ensure adequate sunlight for the plant species. '
                        'Rotate periodically for even growth.',
                  ),
                  SizedBox(height: 10),
                  _DetailLine(
                    label: 'Prevention',
                    value:
                        'Inspect leaves regularly for early signs of disease. '
                        'Remove dead leaves promptly and maintain airflow.',
                  ),
                ],
              ),
            ],

            // ── Info note for high-confidence disease results ─────────────
            if (!isHealthy &&
                !isLowConf &&
                response.message != null &&
                response.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildNoticeCard(
                icon: Icons.info_outline,
                title: 'Result note',
                message: response.message!,
                iconColor: AppColors.green500,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Animated confidence progress bar with label.
  Widget _buildConfidenceBar(double confidence, Color color) {
    final label = confidence >= 0.80
        ? 'High confidence'
        : confidence >= 0.60
            ? 'Moderate confidence'
            : 'Low confidence';
    final pct = '${(confidence * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Confidence',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                pct,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: confidence),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final visibleHistory = _filteredHistoryEntries();

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
                _buildHistoryControls(),
                const SizedBox(height: 12),
                if (_loadingHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_historyErrorMessage != null)
                  _buildNoticeCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'History unavailable',
                    message: _historyErrorMessage!,
                    iconColor: AppColors.error,
                    actionLabel: _historyErrorActionLabel,
                    onAction: _historyErrorAction,
                  )
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
                else if (visibleHistory.isEmpty)
                  _buildNoticeCard(
                    icon: Icons.manage_search_outlined,
                    title: 'No matches found',
                    message:
                        'Try a different search term, filter, or sorting option.',
                    iconColor: AppColors.green500,
                    actionLabel: 'Clear search',
                    onAction: () {
                      setState(() {
                        _historySearchController.clear();
                        _historySearchScope = _HistorySearchScope.all;
                        _historySortMode = _HistorySortMode.newest;
                      });
                    },
                  )
                else ...[
                  Text(
                    '${visibleHistory.length} result${visibleHistory.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...visibleHistory.map(_buildHistoryCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryControls() {
    final cs = Theme.of(context).colorScheme;
    final hasActiveFilter = _historySearchScope != _HistorySearchScope.all ||
        _historySortMode != _HistorySortMode.newest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Compact search row ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _historySearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search history…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
            // Filter toggle badge
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
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _filterExpanded ? Icons.tune : Icons.tune_outlined,
                      key: ValueKey(_filterExpanded),
                      size: 20,
                    ),
                  ),
                  onPressed: () =>
                      setState(() => _filterExpanded = !_filterExpanded),
                ),
                if (hasActiveFilter)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ── Animated filter panel ──────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _filterExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      // Filter-by chip group
                      Expanded(
                        child: _buildSegmentRow<_HistorySearchScope>(
                          label: 'Filter',
                          options: const [
                            (_HistorySearchScope.all, 'All'),
                            (_HistorySearchScope.plant, 'Plant'),
                            (_HistorySearchScope.disease, 'Disease'),
                          ],
                          selected: _historySearchScope,
                          onSelected: (v) =>
                              setState(() => _historySearchScope = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort chip group
                      Expanded(
                        child: _buildSegmentRow<_HistorySortMode>(
                          label: 'Sort',
                          options: const [
                            (_HistorySortMode.newest, 'Newest'),
                            (_HistorySortMode.lowestConfidence, 'Lowest %'),
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

  /// Horizontal chip row with label for a generic enum selector.
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
            final isSelected = selected == value;
            return ChoiceChip(
              label: Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? cs.onPrimary
                          : cs.onSurface)),
              selected: isSelected,
              selectedColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelected(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<DetectionHistoryEntry> _filteredHistoryEntries() {
    final query = _historySearchController.text.trim().toLowerCase();
    final filtered = _history.where((entry) {
      if (query.isEmpty) {
        return true;
      }

      switch (_historySearchScope) {
        case _HistorySearchScope.all:
          return _entryMatchesAnyField(entry, query);
        case _HistorySearchScope.plant:
          return entry.plantName.toLowerCase().contains(query);
        case _HistorySearchScope.disease:
          return _entryMatchesDiseaseFields(entry, query);
      }
    }).toList();

    filtered.sort((left, right) {
      switch (_historySortMode) {
        case _HistorySortMode.newest:
          return right.createdAt.compareTo(left.createdAt);
        case _HistorySortMode.lowestConfidence:
          final comparison = left.confidence.compareTo(right.confidence);
          if (comparison != 0) {
            return comparison;
          }
          return right.createdAt.compareTo(left.createdAt);
      }
    });

    return filtered;
  }

  bool _entryMatchesAnyField(DetectionHistoryEntry entry, String query) {
    return entry.plantName.toLowerCase().contains(query) ||
        (entry.diseaseName?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseCause?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseDescription?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseRemedy?.toLowerCase().contains(query) ?? false) ||
        (entry.diseasePrevention?.toLowerCase().contains(query) ?? false);
  }

  bool _entryMatchesDiseaseFields(DetectionHistoryEntry entry, String query) {
    return (entry.diseaseName?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseCause?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseDescription?.toLowerCase().contains(query) ?? false) ||
        (entry.diseaseRemedy?.toLowerCase().contains(query) ?? false) ||
        (entry.diseasePrevention?.toLowerCase().contains(query) ?? false);
  }

  String _historyCardKey(DetectionHistoryEntry entry) {
    return entry.createdAt.toIso8601String();
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
      _setScanFeedback('Could not delete this entry. Please try again.');
    }
  }

  Widget _buildHistoryCard(DetectionHistoryEntry entry) {
    final historyKey = _historyCardKey(entry);
    final isLowConfidence = entry.confidence < 0.60;
    final isExpanded = _expandedHistoryCards.contains(historyKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(historyKey),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete entry?'),
              content: Text(
                'Remove "${entry.diseaseName ?? 'this entry'}" from history?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete', style: TextStyle(color: Color(0xFFD32F2F))),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) => _deleteHistoryEntry(entry),
        child: Card(
          elevation: 0,
          child: ExpansionTile(
          key: PageStorageKey<String>('history-$historyKey'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedHistoryCards.add(historyKey);
              } else {
                _expandedHistoryCards.remove(historyKey);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Builder(builder: (ctx) => Container(
              width: 56,
              height: 56,
              color: _surfaceVariant(ctx),
              child: entry.imageBytes == null
                  ? const Icon(Icons.image_outlined)
                  : Image.memory(entry.imageBytes!, fit: BoxFit.cover),
            )),
          ),
          title: Text(
            entry.isHealthy
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
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ConfidenceChip(confidence: entry.confidence),
                    Text(
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(entry.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        //color: AppColors.textSecondary,
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
            if (entry.gradcamBytes != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPreviewTile(
                      title: 'Original',
                      fullscreenBytes: entry.imageBytes,
                      child: entry.imageBytes != null
                          ? Image.memory(entry.imageBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPreviewTile(
                      title: 'Grad-CAM',
                      fullscreenBytes: entry.gradcamBytes,
                      child: Image.memory(entry.gradcamBytes!, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _buildDetailGroup(
              title: 'Details',
              children: [
                if (entry.isHealthy) ...[
                  const _DetailLine(
                    label: 'Status',
                    value: '✅ No disease detected — plant looks healthy!',
                  ),
                ] else ...[
                  _DetailLine(
                    label: 'Cause',
                    value: entry.diseaseCause ?? 'Not available yet',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Description',
                    value: entry.diseaseDescription ?? 'Not available yet',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Remedy',
                    value: entry.diseaseRemedy ?? 'Not available yet',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Prevention',
                    value: entry.diseasePrevention ?? 'Not available yet',
                  ),
                ],
                if (isLowConfidence && entry.message != null) ...[
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Note',
                    value: entry.message!,
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

  Widget _buildLoadingNotice({required String title, required String message}) {
    return _buildNoticeCard(
      icon: Icons.hourglass_top,
      title: title,
      message: message,
      iconColor: AppColors.green500,
      showProgress: true,
    );
  }

  Widget _buildDetailGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreviewTile({required String title, required Widget child, Uint8List? fullscreenBytes}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void openFullscreen() {
      if (fullscreenBytes == null) return;
      showDialog<void>(
        context: context,
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
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
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
        height: 190,
        decoration: BoxDecoration(
          color: isDark ? AppColors.gray800 : AppColors.green50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.gray700 : AppColors.green100),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (fullscreenBytes != null) ...const [
                      SizedBox(width: 4),
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 14)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showProgress)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Color-coded confidence badge for history cards.
class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = confidence * 100;
    final Color bg;
    final Color fg;
    if (pct >= 70) {
      bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32);
    } else if (pct >= 45) {
      bg = const Color(0xFFFFF8E1); fg = const Color(0xFFE65100);
    } else {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFC62828);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

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
            color: valueColor ?? Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        )),
      ],
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
