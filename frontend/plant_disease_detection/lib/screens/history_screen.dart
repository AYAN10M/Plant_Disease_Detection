import 'package:flutter/material.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';

// ─────────────────────────────────────────
//  HistoryScreen
//  Shows all past scans from the backend.
//  Features:
//    - Search by disease name or plant
//    - Filter by date
//    - Tap a card to see full result again
//    - Delete a scan
// ─────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Dummy scan history — replace with API response
  // Each item maps to a ScanHistory model from your Django backend
  final List<Map<String, dynamic>> _allScans = [
    {
      'id': 1,
      'disease': 'Early Blight',
      'plant': 'Tomato',
      'date': 'Today, 9:14 AM',
      'confidence': 0.91,
      'severity': 'high',
    },
    {
      'id': 2,
      'disease': 'Powdery Mildew',
      'plant': 'Cucumber',
      'date': 'Yesterday, 3:02 PM',
      'confidence': 0.76,
      'severity': 'medium',
    },
    {
      'id': 3,
      'disease': 'Leaf Spot',
      'plant': 'Pepper',
      'date': 'Jun 12, 2025',
      'confidence': 0.63,
      'severity': 'medium',
    },
    {
      'id': 4,
      'disease': 'Healthy',
      'plant': 'Tomato',
      'date': 'Jun 10, 2025',
      'confidence': 0.98,
      'severity': 'none',
    },
    {
      'id': 5,
      'disease': 'Late Blight',
      'plant': 'Potato',
      'date': 'Jun 8, 2025',
      'confidence': 0.88,
      'severity': 'high',
    },
  ];

  // Filter scans based on search text
  List<Map<String, dynamic>> get _filteredScans {
    if (_searchQuery.trim().isEmpty) return _allScans;
    final q = _searchQuery.toLowerCase();
    return _allScans.where((scan) {
      return scan['disease'].toString().toLowerCase().contains(q) ||
          scan['plant'].toString().toLowerCase().contains(q);
    }).toList();
  }

  void _deleteScan(int id) {
    // TODO: Call API to delete scan
    // await ApiService.deleteHistory(id)
    setState(() {
      _allScans.removeWhere((s) => s['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan deleted'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scans = _filteredScans;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan history')),

      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by disease or plant...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Summary row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Text(
                  '${scans.length} scan${scans.length != 1 ? 's' : ''}',
                  style: AppText.bodySecondary,
                ),
                const Spacer(),
                // Disease summary chips
                _SummaryChip(
                  label:
                      '${_allScans.where((s) => s['severity'] == 'high').length} high risk',
                  color: AppColors.danger,
                ),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: scans.isEmpty
                ? _EmptyState(hasSearch: _searchQuery.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    itemCount: scans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final scan = scans[index];
                      return _HistoryCard(
                        scan: scan,
                        onTap: () {
                          // Navigate back to result screen with this scan's data
                          Navigator.pushNamed(
                            context,
                            '/result',
                            arguments: {
                              'imagePath': '', // Load from saved path
                              'disease': scan['disease'],
                              'confidence': scan['confidence'],
                              'plant': scan['plant'],
                            },
                          );
                        },
                        onDelete: () => _deleteScan(scan['id']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── History card ─────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  Color _severityColor(String s) {
    switch (s) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      case 'none':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'none':
        return 'Healthy';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(scan['severity']);

    return Dismissible(
      // Swipe left to delete
      key: Key(scan['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              // Left color indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // Leaf icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  scan['severity'] == 'none'
                      ? Icons.check_circle_outline
                      : Icons.eco_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Disease + plant + date
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

              // Confidence + severity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _severityLabel(scan['severity']),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(scan['confidence'] * 100).toStringAsFixed(0)}%',
                    style: AppText.caption,
                  ),
                ],
              ),

              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.history_outlined,
            size: 54,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No matching scans' : 'No scans yet',
            style: AppText.heading3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Scan a leaf to see results here',
            style: AppText.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ─────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
