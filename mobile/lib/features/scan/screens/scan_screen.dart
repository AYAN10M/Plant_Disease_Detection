import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart' show themeModeNotifier;
import '../models/detection_model.dart';
import '../services/history_service.dart';
import '../widgets/confidence_slider.dart';
import '../widgets/history_card.dart';
import '../widgets/history_controls.dart';
import '../widgets/image_card.dart';
import '../widgets/notice_card.dart';
import '../widgets/plant_override_dropdown.dart';
import '../widgets/result_card.dart';


class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {

  final _historyStore = DetectionHistoryStore();
  final _picker = ImagePicker();
  final _apiClient = MidoriApiClient();


  int _currentIndex = 0;


  bool _serverReady = false;


  bool _detecting = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  Uint8List? _plantGradcamBytes;
  Uint8List? _diseaseGradcamBytes;

  DetectionApiResponse? _latestResult;
  String? _scanFeedbackMessage;
  bool _scanFeedbackIsError = false;

  String? _selectedPlantOverride;
  double _minConfidence = 40.0;
  bool _settingsExpanded = false;


  bool _loadingHistory = false;
  String? _historyErrorMessage;
  String? _historyErrorActionLabel;
  VoidCallback? _historyErrorAction;

  List<DetectionHistoryEntry> _history = [];
  final Set<String> _expandedHistoryCards = {};

  bool _filterExpanded = false;
  HistorySearchScope _historySearchScope = HistorySearchScope.all;
  HistorySortMode _historySortMode = HistorySortMode.newest;
  final _historySearchController = TextEditingController();


  DetectionHistoryEntry? _pendingHistoryEntry;



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



  Future<void> _pingServer() async {
    final ready = await _apiClient.checkServerHealth();
    if (mounted) setState(() => _serverReady = ready);
  }



  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _loadingHistory = true;
      _historyErrorMessage = null;
    });
    try {
      final entries = await _historyStore.loadEntries();
      if (mounted) {
        setState(() {
          _history = entries;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _historyErrorMessage = 'Could not load detection history.';
          _historyErrorActionLabel = 'Retry';
          _historyErrorAction = _loadHistory;
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
      _historySearchScope = HistorySearchScope.all;
      _historySortMode = HistorySortMode.newest;
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
          (e) =>
              e.createdAt.toIso8601String() ==
              entry.createdAt.toIso8601String(),
        );
        _expandedHistoryCards.remove(entry.createdAt.toIso8601String());
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not delete this entry. Please try again.')),
      );
    }
  }



  Future<bool> _ensureMediaPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return _requestPermission(
        Permission.camera,
        'Camera permission is needed to take a photo.',
      );
    }
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
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = bytes;
        _plantGradcamBytes = null;
        _diseaseGradcamBytes = null;
        _latestResult = null;
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a new photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }



  Future<void> _runDetection() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      _setScanFeedback('Please select a leaf photo first.', isError: true);
      return;
    }

    if (_selectedImageBytes!.lengthInBytes > AppConstants.maxImageBytes) {
      _setScanFeedback(
          'Image is too large (max 10 MB). Please choose a smaller photo.',
          isError: true);
      return;
    }

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
      _detecting = true;
      _scanFeedbackMessage = null;
      _plantGradcamBytes = null;
      _diseaseGradcamBytes = null;
    });

    try {
      final filename =
          _selectedImage!.name.isNotEmpty ? _selectedImage!.name : 'leaf.jpg';

      final response = await _apiClient.detectImage(
        imageBytes: _selectedImageBytes!,
        filename: filename,
        plantOverride: _selectedPlantOverride,
        confidenceThreshold: _minConfidence,
      );

      if (!mounted) return;


      if (response.status == 'not_a_plant') {
        setState(() {
          _detecting = false;
          _latestResult = null;
        });
        _setScanFeedback(
          response.message ??
              'No plant detected. Please use a clear leaf photo.',
          isError: true,
        );
        return;
      }


      final plantGradcamUrl = response.data?.plantGradcamImageUrl;
      final diseaseGradcamUrl = response.data?.gradcamImageUrl;

      final results = await Future.wait([
        _apiClient.fetchBytes(plantGradcamUrl),
        _apiClient.fetchBytes(diseaseGradcamUrl),
      ]);

      if (!mounted) return;

      setState(() {
        _latestResult = response;
        _detecting = false;
        _plantGradcamBytes = results[0];
        _diseaseGradcamBytes = results[1];
        if (response.status == 'not_recognized') {
          _scanFeedbackMessage = null;
        }
      });


      if (response.data != null) {
        final entry = DetectionHistoryEntry.fromDetection(
          response.data!,
          response.message,
          imageBytes: _selectedImageBytes,
          gradcamBytes: results[1],
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
      _setScanFeedback('An unexpected error occurred. Please try again.',
          isError: true);
    }
  }

  void _setScanFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _scanFeedbackMessage = message;
      _scanFeedbackIsError = isError;
    });
  }



  EdgeInsets _responsivePadding(BoxConstraints c) {
    final h = c.maxWidth > 600 ? 24.0 : 16.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: 16);
  }



  List<DetectionHistoryEntry> _filteredHistoryEntries() {
    final query = _historySearchController.text.trim().toLowerCase();
    final filtered = _history.where((entry) {
      if (query.isEmpty) return true;
      switch (_historySearchScope) {
        case HistorySearchScope.all:
          return _entryMatchesAny(entry, query);
        case HistorySearchScope.plant:
          return entry.plantName.toLowerCase().contains(query);
        case HistorySearchScope.disease:
          return _entryMatchesDisease(entry, query);
      }
    }).toList();

    filtered.sort((l, r) {
      switch (_historySortMode) {
        case HistorySortMode.newest:
          return r.createdAt.compareTo(l.createdAt);
        case HistorySortMode.lowestConfidence:
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, size: 22,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Midori',
              style:
                  TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        centerTitle: false,
        actions: [

          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _serverReady
                    ? AppColors.green600.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _serverReady
                        ? Icons.circle_rounded
                        : Icons.circle_outlined,
                    size: 8,
                    color:
                        _serverReady ? AppColors.green500 : AppColors.error,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _serverReady ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _serverReady
                          ? AppColors.green600
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20),
              onPressed: () {
                themeModeNotifier.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            );
          }),
          const SizedBox(width: 4),
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
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner_rounded),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }



  Widget _buildScanTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.green400 : AppColors.green600;

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _pingServer,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: _responsivePadding(constraints).copyWith(bottom: 40),
              children: [

                ImageCard(
                  selectedImageBytes: _selectedImageBytes,
                  plantGradcamBytes: _plantGradcamBytes,
                  diseaseGradcamBytes: _diseaseGradcamBytes,
                  detecting: _detecting,
                  hasSelectedImage: _selectedImage != null,
                  onPickGallery: () => _pickImage(ImageSource.gallery),
                  onPickCamera: () => _pickImage(ImageSource.camera),
                  onDetect: _runDetection,
                ),
                const SizedBox(height: 20),


                GestureDetector(
                  onTap: () => setState(
                      () => _settingsExpanded = !_settingsExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.gray800 : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.gray700 : AppColors.gray200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: accent),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Detection Options',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        if (_selectedPlantOverride != null ||
                            _minConfidence != 40.0)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        AnimatedRotation(
                          turns: _settingsExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded,
                              size: 22,
                              color:
                                  isDark ? AppColors.gray400 : AppColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _settingsExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              PlantOverrideDropdown(
                                value: _selectedPlantOverride,
                                onChanged: (v) => setState(
                                    () => _selectedPlantOverride = v),
                              ),
                              const SizedBox(height: 12),
                              ConfidenceSlider(
                                value: _minConfidence,
                                onChanged: (v) =>
                                    setState(() => _minConfidence = v),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),


                if (_detecting) ...[
                  const SizedBox(height: 16),
                  NoticeCard(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Analysing leaf…',
                    message:
                        'Stage 1: identifying plant. Stage 2: detecting disease.',
                    iconColor: AppColors.green500,
                    showProgress: true,
                  ),
                ],
                if (_scanFeedbackMessage != null) ...[
                  const SizedBox(height: 16),
                  NoticeCard(
                    icon: _scanFeedbackIsError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    title: _scanFeedbackIsError ? 'Problem' : 'Note',
                    message: _scanFeedbackMessage!,
                    iconColor: _scanFeedbackIsError
                        ? AppColors.error
                        : AppColors.green500,
                    actionLabel:
                        _pendingHistoryEntry != null ? 'Retry save' : null,
                    onAction: _pendingHistoryEntry != null
                        ? _retryPendingHistoryEntry
                        : null,
                  ),
                ],
                if (_latestResult != null) ...[
                  const SizedBox(height: 16),
                  ResultCard(
                    response: _latestResult!,
                    plantGradcamBytes: _plantGradcamBytes,
                    diseaseGradcamBytes: _diseaseGradcamBytes,
                    onRetake: _retakePhoto,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }



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
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Clear all',
                                          style: TextStyle(
                                              color: Color(0xFFD32F2F))),
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
                HistoryControls(
                  searchController: _historySearchController,
                  onSearchChanged: () => setState(() {}),
                  filterExpanded: _filterExpanded,
                  onFilterToggle: () =>
                      setState(() => _filterExpanded = !_filterExpanded),
                  searchScope: _historySearchScope,
                  onSearchScopeChanged: (v) =>
                      setState(() => _historySearchScope = v),
                  sortMode: _historySortMode,
                  onSortModeChanged: (v) =>
                      setState(() => _historySortMode = v),
                ),
                const SizedBox(height: 12),
                if (_loadingHistory)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ))
                else if (_historyErrorMessage != null)
                  NoticeCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'History unavailable',
                    message: _historyErrorMessage!,
                    iconColor: AppColors.error,
                    actionLabel: _historyErrorActionLabel,
                    onAction: _historyErrorAction,
                  )
                else if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.gray800
                                : AppColors.green50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_rounded,
                              size: 40,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.gray600
                                  : AppColors.gray300),
                        ),
                        const SizedBox(height: 20),
                        const Text('No scans yet',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Your scan results will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (visible.isEmpty)
                  NoticeCard(
                    icon: Icons.manage_search_outlined,
                    title: 'No matches',
                    message: 'Try a different search term or filter.',
                    iconColor: AppColors.green500,
                    actionLabel: 'Clear search',
                    onAction: () => setState(() {
                      _historySearchController.clear();
                      _historySearchScope = HistorySearchScope.all;
                      _historySortMode = HistorySortMode.newest;
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
                  ...visible.map((entry) {
                    final key = entry.createdAt.toIso8601String();
                    return HistoryCard(
                      entry: entry,
                      isExpanded: _expandedHistoryCards.contains(key),
                      onExpansionChanged: (exp) => setState(() {
                        if (exp) {
                          _expandedHistoryCards.add(key);
                        } else {
                          _expandedHistoryCards.remove(key);
                        }
                      }),
                      onDelete: () => _deleteHistoryEntry(entry),
                      onDismissConfirm: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: Text(
                                'Remove "${entry.diseaseName ?? 'this entry'}" from history?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: Color(0xFFD32F2F)))),
                            ],
                          ),
                        );
                        return result ?? false;
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
