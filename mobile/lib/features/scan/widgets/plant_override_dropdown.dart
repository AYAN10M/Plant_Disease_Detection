import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Plant override dropdown — bypasses Stage 1 auto-detection.
class PlantOverrideDropdown extends StatelessWidget {
  const PlantOverrideDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plant override:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}
