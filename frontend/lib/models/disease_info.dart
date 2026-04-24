class DiseaseInfo {
  final String diseaseName;
  final String summary;
  final String cause;
  final List<String> symptoms;
  final List<String> treatmentSteps;

  const DiseaseInfo({
    required this.diseaseName,
    required this.summary,
    required this.cause,
    required this.symptoms,
    required this.treatmentSteps,
  });

  factory DiseaseInfo.fromJson(Map<String, dynamic> json) {
    return DiseaseInfo(
      diseaseName: _asString(json['diseaseName']) ?? 'Unknown',
      summary: _asString(json['summary']) ?? 'No summary available.',
      cause: _asString(json['cause']) ?? 'Cause is currently unknown.',
      symptoms: _asStringList(json['symptoms']),
      treatmentSteps: _asStringList(json['treatmentSteps']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diseaseName': diseaseName,
      'summary': summary,
      'cause': cause,
      'symptoms': symptoms,
      'treatmentSteps': treatmentSteps,
    };
  }

  static String? _asString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
