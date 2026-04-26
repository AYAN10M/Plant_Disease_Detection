import 'package:flutter/material.dart';

class DemoDisease {
  final String name;
  final String severity;
  final String cause;
  final String symptoms;
  final String remedy;
  final String prevention;
  final IconData icon;

  const DemoDisease({
    required this.name,
    required this.severity,
    required this.cause,
    required this.symptoms,
    required this.remedy,
    required this.prevention,
    required this.icon,
  });
}

class DemoPlant {
  final int id;
  final String name;
  final String scientificName;
  final IconData icon;
  final String description;
  final List<DemoDisease> diseases;

  const DemoPlant({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.icon,
    required this.description,
    required this.diseases,
  });
}

const demoPlants = [
  DemoPlant(
    id: 1,
    name: 'Tomato',
    scientificName: 'Solanum lycopersicum',
    icon: Icons.set_meal_outlined,
    description: 'Common garden crop that often shows leaf spot and blight.',
    diseases: [
      DemoDisease(
        name: 'Early Blight',
        severity: 'Medium',
        cause: 'Alternaria solani fungus — thrives in warm, humid conditions with dew periods.',
        symptoms: 'Brown concentric spots, yellowing leaves, premature leaf drop.',
        remedy: 'Remove infected leaves and apply a copper-based or chlorothalonil fungicide.',
        prevention: 'Water at soil level, avoid wetting foliage, and space plants for airflow.',
        icon: Icons.coronavirus_outlined,
      ),
      DemoDisease(
        name: 'Leaf Mold',
        severity: 'Low',
        cause: 'Cladosporium fulvum fungus — spreads rapidly in poorly ventilated, humid greenhouses.',
        symptoms: 'Pale yellow patches on upper leaf surface with fuzzy olive-brown growth beneath.',
        remedy: 'Improve airflow, reduce ambient humidity, and apply a suitable fungicide.',
        prevention: 'Space plants properly, prune dense growth, and avoid overhead irrigation.',
        icon: Icons.grass_outlined,
      ),
    ],
  ),
  DemoPlant(
    id: 2,
    name: 'Potato',
    scientificName: 'Solanum tuberosum',
    icon: Icons.ramen_dining_outlined,
    description: 'Tubers that are sensitive to fungal leaf diseases.',
    diseases: [
      DemoDisease(
        name: 'Late Blight',
        severity: 'High',
        cause: 'Phytophthora infestans oomycete — spreads explosively in cool, wet weather.',
        symptoms: 'Dark water-soaked lesions on leaves and stems, rapid collapse of foliage.',
        remedy: 'Remove affected foliage immediately and apply a systemic fungicide.',
        prevention: 'Avoid overhead watering, rotate crops, and use certified disease-free seed.',
        icon: Icons.warning_amber_outlined,
      ),
      DemoDisease(
        name: 'Early Blight',
        severity: 'Medium',
        cause: 'Alternaria solani fungus — survives in soil and infected debris between seasons.',
        symptoms: 'Target-like concentric spots on older leaves, reduced plant vigour.',
        remedy: 'Trim affected leaves and support with balanced nutrients; apply fungicide.',
        prevention: 'Use clean seeds, keep soil mulch in place, and rotate crops annually.',
        icon: Icons.local_florist_outlined,
      ),
    ],
  ),
  DemoPlant(
    id: 3,
    name: 'Apple',
    scientificName: 'Malus domestica',
    icon: Icons.apple_outlined,
    description: 'Fruit tree often affected by spot and scab conditions.',
    diseases: [
      DemoDisease(
        name: 'Apple Scab',
        severity: 'Medium',
        cause: 'Venturia inaequalis fungus — overwinters in fallen leaves and releases spores in spring.',
        symptoms: 'Olive-green to brown velvety lesions on leaves and distorted fruit surface.',
        remedy: 'Prune infected tissue and apply a registered orchard fungicide spray.',
        prevention: 'Collect and destroy fallen leaves; keep tree canopies open for airflow.',
        icon: Icons.forest_outlined,
      ),
      DemoDisease(
        name: 'Cedar Rust',
        severity: 'Low',
        cause: 'Gymnosporangium juniperi-virginianae — alternate host is Eastern red cedar/juniper.',
        symptoms: 'Bright orange spots on leaves and premature yellowing in spring.',
        remedy: 'Remove nearby juniper host plants if possible; apply fungicide at bud break.',
        prevention: 'Keep the orchard area clear of debris and avoid planting near cedars.',
        icon: Icons.waves_outlined,
      ),
    ],
  ),
  DemoPlant(
    id: 4,
    name: 'Grape',
    scientificName: 'Vitis vinifera',
    icon: Icons.emoji_food_beverage_outlined,
    description: 'Vine crop that benefits from airflow and clean foliage.',
    diseases: [
      DemoDisease(
        name: 'Black Rot',
        severity: 'High',
        cause: 'Guignardia bidwellii fungus — overwinters in mummified fruit and infected canes.',
        symptoms: 'Dark circular lesions on leaves and berries, shrivelled mummified fruit.',
        remedy: 'Remove and destroy infected clusters; apply fungicide from bud break.',
        prevention: 'Prune for airflow, avoid overhead irrigation, and remove mummified fruit.',
        icon: Icons.warning_outlined,
      ),
      DemoDisease(
        name: 'Leaf Blight',
        severity: 'Medium',
        cause: 'Isariopsis clavispora fungus — favoured by warm temperatures and wet weather.',
        symptoms: 'Brown leaf margins and angular lesions, leading to reduced canopy health.',
        remedy: 'Dispose of damaged leaves; apply copper-based fungicide.',
        prevention: 'Use disease-free cuttings, inspect vines weekly, maintain proper nutrition.',
        icon: Icons.auto_awesome_outlined,
      ),
    ],
  ),
  DemoPlant(
    id: 5,
    name: 'Corn',
    scientificName: 'Zea mays',
    icon: Icons.grain_outlined,
    description: 'Field crop with common rust and leaf spot issues.',
    diseases: [
      DemoDisease(
        name: 'Common Rust',
        severity: 'Medium',
        cause: 'Puccinia sorghi fungus — airborne spores spread rapidly in cool, humid weather.',
        symptoms: 'Orange-cinnamon pustules on upper and lower leaf surfaces, gradual yellowing.',
        remedy: 'Apply a triazole or strobilurin fungicide at first sign of pustules.',
        prevention: 'Plant resistant hybrid varieties and manage crop residue after harvest.',
        icon: Icons.wb_sunny_outlined,
      ),
      DemoDisease(
        name: 'Northern Leaf Blight',
        severity: 'High',
        cause: 'Exserohilum turcicum fungus — survives in infected crop debris over winter.',
        symptoms: 'Long cigar-shaped gray-green lesions that expand quickly in wet weather.',
        remedy: 'Apply recommended fungicide and monitor neighbouring plants.',
        prevention: 'Plant resistant varieties, rotate fields, and incorporate crop residue.',
        icon: Icons.shield_outlined,
      ),
    ],
  ),
];
