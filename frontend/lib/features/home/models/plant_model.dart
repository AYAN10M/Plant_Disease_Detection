class PlantModel {
  final int id;
  final String name;
  final String scientificName;
  final String? image;

  const PlantModel({
    required this.id,
    required this.name,
    required this.scientificName,
    this.image,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    return PlantModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}
