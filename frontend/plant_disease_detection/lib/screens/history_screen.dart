import 'package:flutter/material.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';

// ─────────────────────────────────────────
//  HistoryScreen — richer version
//  Features:
//   - Summary strip (total / diseases / healthy)
//   - Filter chips: All | Diseases | Healthy | High risk
//   - Search bar
//   - Scans grouped by date
//   - Richer card with plant tag, confidence bar, severity badge
//   - Swipe to delete
//   - Empty states per filter
// ─────────────────────────────────────────

// Filter options
enum _Filter { all, diseases, healthy, highRisk }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _activeFilter = _Filter.all;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Master data — replace with API response
  final List<Map<String, dynamic>> _all = [
    {
      'id': 1,
      'disease': 'Early Blight',
      'plant': 'Tomato',
      'dateLabel': 'Today',
      'confidence': 0.91,
      'severity': 'high',
      'isHealthy': false,
    },
    {
      'id': 2,
      'disease': 'Healthy',
      'plant': 'Cucumber',
      'dateLabel': 'Today',
      'confidence': 0.97,
      'severity': 'none',
      'isHealthy': true,
    },
    {
      'id': 3,
      'disease': 'Powdery Mildew',
      'plant': 'Cucumber',
      'dateLabel': 'Yesterday',
      'confidence': 0.76,
      'severity': 'medium',
      'isHealthy': false,
    },
    {
      'id': 4,
      'disease': 'Late Blight',
      'plant': 'Potato',
      'dateLabel': 'Yesterday',
      'confidence': 0.88,
      'severity': 'high',
      'isHealthy': false,
    },
    {
      'id': 5,
      'disease': 'Healthy',
      'plant': 'Tomato',
      'dateLabel': 'Jun 12',
      'confidence': 0.99,
      'severity': 'none',
      'isHealthy': true,
    },
    {
      'id': 6,
      'disease': 'Leaf Spot',
      'plant': 'Pepper',
      'dateLabel': 'Jun 12',
      'confidence': 0.63,
      'severity': 'medium',
      'isHealthy': false,
    },
    {
      'id': 7,
      'disease': 'Healthy',
      'plant': 'Brinjal',
      'dateLabel': 'Jun 10',
      'confidence': 0.95,
      'severity': 'none',
      'isHealthy': true,
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    var list = _all.where((s) {
      // Filter chip
      switch (_activeFilter) {
        case _Filter.diseases:
          if (s['isHealthy'] as bool) return false;
          break;
        case _Filter.healthy:
          if (!(s['isHealthy'] as bool)) return false;
          break;
        case _Filter.highRisk:
          if (s['severity'] != 'high') return false;
          break;
        case _Filter.all:
          break;
      }
      // Search query
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return (s['disease'] as String).toLowerCase().contains(q) ||
            (s['plant'] as String).toLowerCase().contains(q);
      }
      return true;
    }).toList();
    return list;
  }

  // Group filtered scans by their dateLabel
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final s in _filtered) {
      final label = s['dateLabel'] as String;
      groups.putIfAbsent(label, () => []).add(s);
    }
    return groups;
  }

  void _delete(int id) {
    setState(() => _all.removeWhere((s) => s['id'] == id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textSecondary,
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
    final grouped = _grouped;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: const Text('History', style: AppText.heading2),
            ),

            // ── Summary strip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _SummaryStrip(all: _all),
            ),

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search disease or plant...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: _all.length,
                      isActive: _activeFilter == _Filter.all,
                      onTap: () => setState(() => _activeFilter = _Filter.all),
                    ),
                    _FilterChip(
                      label: 'Diseases',
                      count: _all
                          .where((s) => !(s['isHealthy'] as bool))
                          .length,
                      isActive: _activeFilter == _Filter.diseases,
                      color: AppColors.danger,
                      onTap: () =>
                          setState(() => _activeFilter = _Filter.diseases),
                    ),
                    _FilterChip(
                      label: 'Healthy',
                      count: _all.where((s) => s['isHealthy'] as bool).length,
                      isActive: _activeFilter == _Filter.healthy,
                      color: AppColors.success,
                      onTap: () =>
                          setState(() => _activeFilter = _Filter.healthy),
                    ),
                    _FilterChip(
                      label: 'High risk',
                      count: _all.where((s) => s['severity'] == 'high').length,
                      isActive: _activeFilter == _Filter.highRisk,
                      color: const Color(0xFF9B2335),
                      onTap: () =>
                          setState(() => _activeFilter = _Filter.highRisk),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── List ──
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      filter: _activeFilter,
                      hasQuery: _query.isNotEmpty,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      itemCount: grouped.length,
                      itemBuilder: (ctx, groupIndex) {
                        final dateLabel = grouped.keys.elementAt(groupIndex);
                        final scans = grouped[dateLabel]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date group header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(dateLabel, style: AppText.label),
                            ),
                            ...scans.map(
                              (scan) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _HistoryCard(
                                  scan: scan,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/result',
                                    arguments: {
                                      'imagePath': '',
                                      'disease': scan['disease'],
                                      'confidence': scan['confidence'],
                                      'plant': scan['plant'],
                                    },
                                  ),
                                  onDelete: () => _delete(scan['id'] as int),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary strip ─────────────────────────

class _SummaryStrip extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  const _SummaryStrip({required this.all});

  @override
  Widget build(BuildContext context) {
    final total = all.length;
    final diseases = all.where((s) => !(s['isHealthy'] as bool)).length;
    final healthy = all.where((s) => s['isHealthy'] as bool).length;
    final highRisk = all.where((s) => s['severity'] == 'high').length;

    return Row(
      children: [
        _StripItem(label: 'Total', value: '$total', color: AppColors.primary),
        _StripDivider(),
        _StripItem(
          label: 'Diseased',
          value: '$diseases',
          color: AppColors.danger,
        ),
        _StripDivider(),
        _StripItem(
          label: 'Healthy',
          value: '$healthy',
          color: AppColors.success,
        ),
        _StripDivider(),
        _StripItem(
          label: 'High risk',
          value: '$highRisk',
          color: const Color(0xFF9B2335),
        ),
      ],
    );
  }
}

class _StripItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StripItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.divider);
}

// ── Filter chip ───────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isActive,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? color : AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History card ──────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HistoryCard({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  Color get _severityColor {
    switch (scan['severity'] as String) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String get _severityLabel {
    switch (scan['severity'] as String) {
      case 'high':
        return 'High risk';
      case 'medium':
        return 'Medium';
      default:
        return 'Healthy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    final confidence = scan['confidence'] as double;

    return Dismissible(
      key: Key('${scan['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.danger,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Left accent
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scan['disease'] as String,
                          style: AppText.heading3,
                        ),
                        const SizedBox(height: 2),
                        // Plant tag
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                scan['plant'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Severity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _severityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Confidence bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: confidence,
                        minHeight: 5,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(confidence * 100).round()}% confident',
                    style: AppText.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  final bool hasQuery;
  const _EmptyState({required this.filter, required this.hasQuery});

  String get _message {
    if (hasQuery) return 'No scans match your search';
    switch (filter) {
      case _Filter.diseases:
        return 'No diseased plants found';
      case _Filter.healthy:
        return 'No healthy scans yet';
      case _Filter.highRisk:
        return 'No high-risk scans';
      default:
        return 'No scans yet — scan a leaf to begin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.history_outlined,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
