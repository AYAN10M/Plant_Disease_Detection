import 'package:flutter/material.dart';

enum HistorySearchScope { all, plant, disease }

enum HistorySortMode { newest, lowestConfidence }

class HistoryControls extends StatelessWidget {
  const HistoryControls({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterExpanded,
    required this.onFilterToggle,
    required this.searchScope,
    required this.onSearchScopeChanged,
    required this.sortMode,
    required this.onSortModeChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final bool filterExpanded;
  final VoidCallback onFilterToggle;
  final HistorySearchScope searchScope;
  final ValueChanged<HistorySearchScope> onSearchScopeChanged;
  final HistorySortMode sortMode;
  final ValueChanged<HistorySortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasActiveFilter = searchScope != HistorySearchScope.all ||
        sortMode != HistorySortMode.newest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search history…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
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
                    backgroundColor: filterExpanded
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                      filterExpanded ? Icons.tune : Icons.tune_outlined,
                      size: 20),
                  onPressed: onFilterToggle,
                ),
                if (hasActiveFilter)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 8,
                      height: 8,
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
          curve: Curves.easeInOut,
          child: filterExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSegmentRow<HistorySearchScope>(
                          context: context,
                          label: 'Filter',
                          options: const [
                            (HistorySearchScope.all, 'All'),
                            (HistorySearchScope.plant, 'Plant'),
                            (HistorySearchScope.disease, 'Disease'),
                          ],
                          selected: searchScope,
                          onSelected: onSearchScopeChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSegmentRow<HistorySortMode>(
                          context: context,
                          label: 'Sort',
                          options: const [
                            (HistorySortMode.newest, 'Newest'),
                            (HistorySortMode.lowestConfidence, 'Lowest %'),
                          ],
                          selected: sortMode,
                          onSelected: onSortModeChanged,
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
    required BuildContext context,
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
                      color: isSelected ? cs.onPrimary : cs.onSurface)),
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
}
