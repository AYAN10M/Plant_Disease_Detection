import 'package:flutter/material.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Sticky app bar ──
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 24,
              title: _GreetingHeader(),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySurface,
                    child: const Text(
                      'U',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Stat cards row ──
                  const SizedBox(height: 4),
                  _StatsGrid(),
                  const SizedBox(height: 24),

                  // ── Disease breakdown ──
                  _SectionHeader(
                    title: 'Disease breakdown',
                    subtitle: 'This month',
                  ),
                  const SizedBox(height: 12),
                  _DiseaseBreakdownCard(),
                  const SizedBox(height: 24),

                  // ── Quick scan CTA ──
                  _QuickScanBanner(),
                  const SizedBox(height: 24),

                  // ── Recent scans ──
                  _SectionHeader(
                    title: 'Recent scans',
                    actionLabel: 'See all',
                    onAction: () {}, // Handled by MainShell tab switch
                  ),
                  const SizedBox(height: 12),
                  _RecentScansList(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting header ───────────────────────

class _GreetingHeader extends StatelessWidget {
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(), style: AppText.bodySecondary),
        const SizedBox(height: 1),
        Row(
          children: [
            Text('LeafScan', style: AppText.heading2),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formattedDate(),
                style: AppText.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stats grid ────────────────────────────

class _StatsGrid extends StatelessWidget {
  // TODO: replace these with real counts from your /api/stats/ endpoint
  static const _stats = [
    {
      'label': 'Total scans',
      'value': '48',
      'icon': Icons.eco_outlined,
      'color': 'green',
    },
    {
      'label': 'Diseases found',
      'value': '12',
      'icon': Icons.bug_report_outlined,
      'color': 'red',
    },
    {
      'label': 'Healthy',
      'value': '36',
      'icon': Icons.check_circle_outline,
      'color': 'teal',
    },
    {
      'label': 'This week',
      'value': '7',
      'icon': Icons.calendar_today_outlined,
      'color': 'amber',
    },
  ];

  Color _bg(String c) {
    switch (c) {
      case 'red':
        return AppColors.dangerSurface;
      case 'teal':
        return AppColors.primarySurface;
      case 'amber':
        return const Color(0xFFFFF3E0);
      default:
        return AppColors.primarySurface;
    }
  }

  Color _fg(String c) {
    switch (c) {
      case 'red':
        return AppColors.danger;
      case 'teal':
        return AppColors.success;
      case 'amber':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (ctx, i) {
        final s = _stats[i];
        final color = s['color'] as String;
        final icon = s['icon'] as IconData;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _bg(color),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _fg(color)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['value'] as String,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Nunito',
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(s['label'] as String, style: AppText.caption),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Disease breakdown card ────────────────

class _DiseaseBreakdownCard extends StatelessWidget {
  // TODO: replace with data from /api/stats/disease-breakdown/
  static const _diseases = [
    {'name': 'Early Blight', 'count': 5, 'color': 0xFFE63946},
    {'name': 'Powdery Mildew', 'count': 3, 'color': 0xFFF4A261},
    {'name': 'Leaf Spot', 'count': 2, 'color': 0xFFFFB703},
    {'name': 'Late Blight', 'count': 2, 'color': 0xFF9B2335},
  ];

  @override
  Widget build(BuildContext context) {
    final total = _diseases.fold<int>(0, (sum, d) => sum + (d['count'] as int));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: _diseases.map((d) {
                  final frac = (d['count'] as int) / total;
                  return Expanded(
                    flex: (frac * 100).round(),
                    child: Container(color: Color(d['color'] as int)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          ..._diseases.map((d) {
            final frac = (d['count'] as int) / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(d['color'] as int),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d['name'] as String, style: AppText.body),
                  ),
                  Text('${d['count']} scans', style: AppText.caption),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(frac * 100).round()}%',
                      style: AppText.label.copyWith(
                        color: Color(d['color'] as int),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Quick scan CTA banner ─────────────────

class _QuickScanBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spot something unusual?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap scan to identify a disease instantly',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.heading3),
            if (subtitle != null) Text(subtitle!, style: AppText.caption),
          ],
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ── Recent scans list ─────────────────────

class _RecentScansList extends StatelessWidget {
  static const _scans = [
    {
      'disease': 'Early Blight',
      'plant': 'Tomato',
      'date': 'Today, 9:14 AM',
      'severity': 'high',
      'confidence': 91,
    },
    {
      'disease': 'Powdery Mildew',
      'plant': 'Cucumber',
      'date': 'Yesterday',
      'severity': 'medium',
      'confidence': 76,
    },
    {
      'disease': 'Healthy',
      'plant': 'Pepper',
      'date': 'Jun 12',
      'severity': 'none',
      'confidence': 98,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _scans
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactScanCard(scan: s),
            ),
          )
          .toList(),
    );
  }
}

class _CompactScanCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  const _CompactScanCard({required this.scan});

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

  IconData _severityIcon(String s) {
    switch (s) {
      case 'high':
        return Icons.error_outline;
      case 'medium':
        return Icons.warning_amber_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(scan['severity'] as String);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _severityIcon(scan['severity'] as String),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan['disease'] as String, style: AppText.heading3),
                Text(
                  '${scan['plant']} · ${scan['date']}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${scan['confidence']}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Nunito',
                ),
              ),
              Text('confidence', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}
