"""
seed_model_catalog — populate Plant + Disease tables from model class labels.
Usage: python manage.py seed_model_catalog [--keep-media]
"""

import shutil
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

from detections.engine import DISEASE_CLASSES
from detections.models import Detection
from diseases.models import Disease
from plants.models import Plant


PLANT_METADATA: dict[str, dict] = {
    "Apple": {
        "scientific_name": "Malus domestica",
        "family": "Rosaceae",
        "origin": "Central Asia (Kazakhstan region)",
        "growing_season": "Spring to Autumn (temperate climates)",
        "ideal_climate": (
            "Temperate climate with cold winters (800-1200 chilling hours below 7°C) "
            "and warm, dry summers. Optimal temperature 18-24°C. Rainfall 600-800 mm."
        ),
        "common_uses": "Fresh consumption, juice, cider, vinegar, jam, and dried fruit.",
        "description": (
            "Apple (Malus domestica) is one of the most widely cultivated fruit trees globally, "
            "with over 7,500 cultivars. Susceptible to Apple Scab, Black Rot, and Cedar Apple Rust."
        ),
    },
    "Corn": {
        "scientific_name": "Zea mays",
        "family": "Poaceae",
        "origin": "Mesoamerica (Mexico)",
        "growing_season": "Kharif (June-October in South Asia); warm season in temperate zones",
        "ideal_climate": (
            "Warm climate with 21-30°C during growing season. "
            "Requires well-drained soil with pH 5.8-7.0. Rainfall 500-800 mm."
        ),
        "common_uses": "Staple food, animal feed, corn oil, ethanol, corn starch, and sweeteners.",
        "description": (
            "Corn (Zea mays) is the world's most produced cereal grain. "
            "Susceptible to Cercospora Gray Leaf Spot, Common Rust, and Northern Leaf Blight."
        ),
    },
    "Grape": {
        "scientific_name": "Vitis vinifera",
        "family": "Vitaceae",
        "origin": "Near East / Mediterranean (Georgia, Armenia)",
        "growing_season": "Spring bud-break to Autumn harvest (April-October in temperate zones)",
        "ideal_climate": (
            "Mediterranean climate with warm, dry summers and mild, wet winters. "
            "Optimal temperature 15-25°C. Rainfall 500-700 mm."
        ),
        "common_uses": "Wine production, fresh table grapes, raisins, grape juice, and jam.",
        "description": (
            "Grapevine (Vitis vinifera) is a woody perennial cultivated for over 6,000 years. "
            "Prone to Black Rot, Esca (Black Measles), and Isariopsis Leaf Spot."
        ),
    },
    "Potato": {
        "scientific_name": "Solanum tuberosum",
        "family": "Solanaceae",
        "origin": "Andes mountains, South America (Peru and Bolivia)",
        "growing_season": "Rabi (October-March in South Asia); Spring-Summer in temperate zones",
        "ideal_climate": (
            "Cool climate with 15-20°C during tuber formation. "
            "Requires well-drained sandy-loam soil with pH 5.2-6.4. Rainfall 500-700 mm."
        ),
        "common_uses": "Staple food (boiled, fried, chips), industrial starch, and animal feed.",
        "description": (
            "Potato (Solanum tuberosum) is the world's fourth-largest food crop. "
            "Early Blight and Late Blight are the primary leaf diseases."
        ),
    },
    "Pepper": {
        "scientific_name": "Capsicum annuum",
        "family": "Solanaceae",
        "origin": "Central and South America (Mexico, Bolivia)",
        "growing_season": "Kharif (June-October in South Asia); warm season in temperate zones",
        "ideal_climate": (
            "Warm climate with 20-30°C; sensitive to frost. "
            "Requires well-drained loamy soil with pH 6.0-7.0. Rainfall 600-900 mm."
        ),
        "common_uses": "Culinary spice, fresh consumption, pickling, and sauces.",
        "description": (
            "Pepper (Capsicum annuum) encompasses bell peppers, chillies, and paprika. "
            "Bacterial Spot (Xanthomonas spp.) is the primary leaf disease."
        ),
    },
    "Strawberry": {
        "scientific_name": "Fragaria × ananassa",
        "family": "Rosaceae",
        "origin": "Europe (hybrid of North and South American species)",
        "growing_season": "Spring to early Summer; everbearing varieties produce into Autumn",
        "ideal_climate": (
            "Temperate climate with 15-26°C. "
            "Requires well-drained acidic soil with pH 5.5-6.5. Moderate rainfall."
        ),
        "common_uses": "Fresh consumption, jam, juice, desserts, and flavoring.",
        "description": (
            "Strawberry (Fragaria × ananassa) is a widely grown fruit crop. "
            "Leaf Scorch is the primary foliar disease detected."
        ),
    },
}


DISEASE_CATALOG: dict[str, dict[str, dict]] = {
    "Apple": {
        "Apple Scab": {
            "description": (
                "Apple Scab is a common fungal disease caused by Venturia inaequalis. "
                "Most severe in cool, wet spring weather."
            ),
            "cause": (
                "Caused by Venturia inaequalis. Primary inoculum overwinters in infected leaf litter; "
                "ascospores are released during spring rains."
            ),
            "symptoms": (
                "Olive-green to dark brown scab-like lesions on upper leaf surfaces. "
                "Infected fruit develops corky, rough, dark spots."
            ),
            "remedy": (
                "Apply fungicides containing captan or myclobutanil at bud-break. "
                "Remove and destroy infected fallen leaves."
            ),
            "prevention": (
                "Plant resistant varieties. Rake and destroy fallen leaves in autumn. "
                "Prune trees to improve air circulation."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Black Rot": {
            "description": (
                "Black Rot is a destructive fungal disease caused by Botryosphaeria obtusa. "
                "It can kill branches and cause fruit mummification."
            ),
            "cause": (
                "Caused by Botryosphaeria obtusa. Enters through wounds and pruning cuts. "
                "Overwinters in dead bark and mummified fruit."
            ),
            "symptoms": (
                "Dark brown to black cankers on branches. Fruit rot with concentric rings "
                "(frog-eye pattern). Fruit eventually mummifies."
            ),
            "remedy": (
                "Prune infected wood below cankers. Apply copper-based or captan fungicides. "
                "Remove mummified fruit and dead wood."
            ),
            "prevention": (
                "Maintain tree vigor. Prune dead wood annually in dry weather. "
                "Apply wound sealant after pruning."
            ),
            "severity": "severe",
            "affected_parts": "fruit, twig, leaf",
        },
        "Cedar Apple Rust": {
            "description": (
                "Cedar Apple Rust is caused by Gymnosporangium juniperi-virginianae. "
                "Requires both apple and eastern red cedar to complete its life cycle."
            ),
            "cause": (
                "Heteroecious rust fungus. Teliospores from orange galls on cedar trees "
                "are wind-dispersed to apple leaves during wet spring weather."
            ),
            "symptoms": (
                "Bright yellow-orange spots on upper leaf surfaces. "
                "Tube-like structures (aecia) on leaf undersides."
            ),
            "remedy": (
                "Apply protective fungicides (mancozeb, myclobutanil) from pink bud through petal fall. "
                "Remove nearby juniper/cedar host trees if feasible."
            ),
            "prevention": (
                "Plant rust-resistant cultivars. Avoid planting near eastern red cedars. "
                "Monitor and remove cedar galls before spore release."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Healthy": {
            "description": "No visible signs of disease. Plant appears vigorous.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Normal leaf color and texture.",
            "remedy": "No treatment required.",
            "prevention": "Continue regular scouting and proper care.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    "Corn": {
        "Cercospora / Gray Leaf Spot": {
            "description": (
                "Gray Leaf Spot is caused by Cercospora zeae-maydis. "
                "One of the most significant yield-limiting diseases of corn worldwide."
            ),
            "cause": (
                "Caused by Cercospora zeae-maydis. Survives in crop residue. "
                "Favored by warm temperatures and high humidity."
            ),
            "symptoms": (
                "Rectangular, grayish-tan lesions between leaf veins. "
                "Lesions may coalesce causing large areas of dead tissue."
            ),
            "remedy": (
                "Apply strobilurin-based fungicides at first sign. "
                "Remove crop debris after harvest."
            ),
            "prevention": (
                "Use resistant hybrids. Practice crop rotation. "
                "Reduce tillage to manage residue-borne inoculum."
            ),
            "severity": "moderate",
            "affected_parts": "leaf",
        },
        "Common Rust": {
            "description": (
                "Common Rust is caused by Puccinia sorghi. "
                "Widespread but usually not severe in well-managed fields."
            ),
            "cause": (
                "Caused by Puccinia sorghi. Spores are wind-dispersed over long distances. "
                "Favored by cool, moist conditions (16-23°C)."
            ),
            "symptoms": (
                "Small, circular to elongate cinnamon-brown pustules on both leaf surfaces. "
                "Pustules produce powdery, rust-colored spores."
            ),
            "remedy": (
                "Apply foliar fungicides early if infection is severe. "
                "Most hybrids have adequate resistance."
            ),
            "prevention": (
                "Plant rust-resistant hybrids. "
                "Early planting reduces exposure to peak spore periods."
            ),
            "severity": "mild",
            "affected_parts": "leaf",
        },
        "Northern Leaf Blight": {
            "description": (
                "Northern Leaf Blight is caused by Exserohilum turcicum. "
                "Can cause significant yield loss in susceptible hybrids."
            ),
            "cause": (
                "Caused by Exserohilum turcicum. Survives in infected crop residue. "
                "Favored by moderate temperatures (18-27°C) and heavy dews."
            ),
            "symptoms": (
                "Long, elliptical grayish-green to tan lesions (2.5-15 cm) on leaves. "
                "Severe infections cause premature death of leaves."
            ),
            "remedy": (
                "Apply fungicides at first sign of lesions. "
                "Practice crop rotation and remove debris."
            ),
            "prevention": (
                "Use resistant hybrids. Rotate crops for 1-2 years. "
                "Reduce surface residue through tillage."
            ),
            "severity": "moderate",
            "affected_parts": "leaf",
        },
        "Healthy": {
            "description": "No visible signs of disease. Plant appears vigorous.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Normal leaf color and texture.",
            "remedy": "No treatment required.",
            "prevention": "Continue regular scouting and proper care.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    "Grape": {
        "Black Rot": {
            "description": (
                "Black Rot is caused by Guignardia bidwellii. "
                "Can destroy entire clusters in humid climates."
            ),
            "cause": (
                "Caused by Guignardia bidwellii. Overwinters in mummified berries. "
                "Ascospores released during spring rains."
            ),
            "symptoms": (
                "Reddish-brown circular lesions with dark borders on leaves. "
                "Berries shrivel and mummify into black structures."
            ),
            "remedy": (
                "Apply mancozeb or myclobutanil from bud break through veraison. "
                "Remove mummified berries during dormant pruning."
            ),
            "prevention": (
                "Remove infected material during winter. Open canopy for air circulation. "
                "Apply protective fungicides before rain events."
            ),
            "severity": "severe",
            "affected_parts": "leaf, fruit, cane",
        },
        "Esca (Black Measles)": {
            "description": (
                "Esca is a complex trunk disease with no curative treatment. "
                "'Black Measles' refers to the tiger-stripe leaf symptoms."
            ),
            "cause": (
                "Complex of wood-decay fungi including Phaeomoniella chlamydospora "
                "and Phaeoacremonium minimum. Infection through pruning wounds."
            ),
            "symptoms": (
                "Inter-veinal chlorosis and necrosis giving a 'tiger-stripe' pattern. "
                "Dark spots on berries. Sudden vine death can occur."
            ),
            "remedy": (
                "No curative treatment. Remove severely infected vines. "
                "Apply trunk wound protectants after pruning."
            ),
            "prevention": (
                "Apply wound protectants after pruning. Prune in dry weather. "
                "Use certified disease-free planting material."
            ),
            "severity": "severe",
            "affected_parts": "leaf, cane, wood",
        },
        "Leaf Blight (Isariopsis Leaf Spot)": {
            "description": (
                "Grape Leaf Blight is caused by Pseudocercospora vitis. "
                "Causes defoliation that weakens vines and reduces fruit quality."
            ),
            "cause": (
                "Caused by Pseudocercospora vitis. "
                "Conidia spread by wind and rain. Favored by warm, humid conditions."
            ),
            "symptoms": (
                "Angular dark brown spots near leaf margins and veins. "
                "Severely infected leaves turn yellow and drop."
            ),
            "remedy": (
                "Apply copper-based fungicides or mancozeb at first sign. "
                "Remove infected fallen leaves."
            ),
            "prevention": (
                "Maintain open canopy. Avoid excessive nitrogen fertilization. "
                "Apply preventative copper sprays in humid conditions."
            ),
            "severity": "moderate",
            "affected_parts": "leaf",
        },
        "Healthy": {
            "description": "No visible signs of disease. Vine appears vigorous.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Leaves are uniformly green.",
            "remedy": "No treatment required.",
            "prevention": "Continue regular canopy management and scouting.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    "Potato": {
        "Early Blight": {
            "description": (
                "Early Blight is caused by Alternaria solani. "
                "Appears on older lower leaves first."
            ),
            "cause": (
                "Caused by Alternaria solani. Survives in plant debris. "
                "Favored by warm temperatures (24-29°C) and alternating wet/dry conditions."
            ),
            "symptoms": (
                "Dark brown spots with concentric rings forming a target-board pattern. "
                "Yellow halo around lesions. Progresses from lower to upper leaves."
            ),
            "remedy": (
                "Apply chlorothalonil or mancozeb at first sign. "
                "Remove heavily infected leaves. Avoid wetting foliage."
            ),
            "prevention": (
                "Use certified disease-free seed tubers. Rotate crops for 2+ years. "
                "Maintain adequate potassium nutrition."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, stem",
        },
        "Late Blight": {
            "description": (
                "Late Blight is caused by Phytophthora infestans. "
                "Responsible for the Irish Potato Famine. Remains a serious threat."
            ),
            "cause": (
                "Caused by the oomycete Phytophthora infestans. "
                "Infection occurs rapidly in cool, moist weather (10-24°C)."
            ),
            "symptoms": (
                "Water-soaked pale green to brown lesions that rapidly enlarge. "
                "White sporulating growth on leaf undersides in humid conditions."
            ),
            "remedy": (
                "URGENT: Apply metalaxyl or mancozeb immediately. "
                "Destroy all infected plant material."
            ),
            "prevention": (
                "Use blight-resistant varieties. Plant certified seed tubers. "
                "Apply preventative fungicide in cool, wet conditions."
            ),
            "severity": "severe",
            "affected_parts": "leaf, stem, tuber",
        },
        "Healthy": {
            "description": "No visible signs of disease. Normal green foliage.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Leaves are uniformly green.",
            "remedy": "No treatment required.",
            "prevention": "Continue crop rotation and regular scouting.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    "Pepper": {
        "Bacterial Spot": {
            "description": (
                "Bacterial Spot is caused by Xanthomonas spp. "
                "Can cause severe defoliation and yield losses in warm, wet conditions."
            ),
            "cause": (
                "Caused by Xanthomonas species. Seed-borne and spread by rain splash "
                "and contaminated tools. Favored by warm temperatures (24-30°C)."
            ),
            "symptoms": (
                "Small water-soaked spots that turn brown with yellow halos. "
                "Heavily infected leaves yellow and drop."
            ),
            "remedy": (
                "Apply copper-based bactericides at first sign. "
                "Avoid overhead irrigation. Remove severely infected plants."
            ),
            "prevention": (
                "Use certified disease-free seed. Use drip irrigation. "
                "Rotate crops for 2-3 years. Disinfect tools between uses."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Healthy": {
            "description": "No visible signs of disease. Normal dark green foliage.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Leaves are uniformly green.",
            "remedy": "No treatment required.",
            "prevention": "Use disease-free transplants. Scout regularly.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    "Strawberry": {
        "Leaf Scorch": {
            "description": (
                "Leaf Scorch is caused by Diplocarpon earlianum. "
                "Causes significant defoliation that weakens plants and reduces yield."
            ),
            "cause": (
                "Caused by Diplocarpon earlianum. Spores spread by rain splash. "
                "Favored by warm, humid conditions."
            ),
            "symptoms": (
                "Small dark purple spots on upper leaf surfaces that enlarge. "
                "Spots may coalesce causing leaves to appear scorched."
            ),
            "remedy": (
                "Apply fungicides (myclobutanil or captan). "
                "Remove infected leaves. Ensure good air circulation."
            ),
            "prevention": (
                "Plant resistant varieties. Avoid overhead irrigation. "
                "Remove old leaves after harvest. Maintain good plant spacing."
            ),
            "severity": "moderate",
            "affected_parts": "leaf",
        },
        "Healthy": {
            "description": "No visible signs of disease. Plant appears vigorous.",
            "cause": "Not applicable.",
            "symptoms": "No symptoms. Healthy green foliage.",
            "remedy": "No treatment required.",
            "prevention": "Continue regular care and scouting.",
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },
}


def _remove_media_subdirs() -> None:
    media_root = Path(settings.MEDIA_ROOT)
    for rel in ("detections/uploads", "detections/gradcam_plant",
                "detections/gradcam_disease", "detections/gradcam",
                "plants", "diseases"):
        target = media_root / rel
        if target.exists():
            shutil.rmtree(target)


class Command(BaseCommand):
    help = "Clear and reseed plant/disease catalog from model class labels."

    def add_arguments(self, parser):
        parser.add_argument("--keep-media", action="store_true",
                            help="Keep uploaded images while clearing the DB.")

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write(f"{'='*50}")
        self.stdout.write("  Database Reseed")
        self.stdout.write(f"{'='*50}")

        self.stdout.write("\n[1] Clearing existing records ...")
        det_count = Detection.objects.count()
        dis_count = Disease.objects.count()
        pln_count = Plant.objects.count()
        Detection.objects.all().delete()
        Disease.objects.all().delete()
        Plant.objects.all().delete()
        self.stdout.write(
            f"    Deleted {det_count} detections, {dis_count} diseases, {pln_count} plants."
        )

        if not options["keep_media"]:
            _remove_media_subdirs()
            self.stdout.write("    Media sub-directories cleared.")

        self.stdout.write("\n[2] Seeding plants ...")
        plants_created = 0
        diseases_created = 0

        for plant_name in DISEASE_CLASSES:
            meta = PLANT_METADATA.get(plant_name, {})
            plant = Plant.objects.create(
                name=plant_name,
                scientific_name=meta.get("scientific_name", ""),
                family=meta.get("family", ""),
                origin=meta.get("origin", ""),
                growing_season=meta.get("growing_season", ""),
                ideal_climate=meta.get("ideal_climate", ""),
                common_uses=meta.get("common_uses", ""),
                description=meta.get("description", f"{plant_name} plant."),
            )
            plants_created += 1

            class_names = DISEASE_CLASSES[plant_name]
            if not class_names:
                continue

            plant_catalog = DISEASE_CATALOG.get(plant_name, {})
            seeded = 0
            for disease_name in class_names:
                data = plant_catalog.get(disease_name, {})
                Disease.objects.create(
                    plant=plant,
                    name=disease_name,
                    description=data.get("description", f"{disease_name} detected in {plant_name}."),
                    cause=data.get("cause", ""),
                    symptoms=data.get("symptoms", ""),
                    remedy=data.get("remedy", ""),
                    prevention=data.get("prevention", ""),
                    severity=data.get("severity", "moderate"),
                    affected_parts=data.get("affected_parts", "leaf"),
                )
                seeded += 1
                diseases_created += 1

            self.stdout.write(f"    {plant_name:<12} ({seeded} disease classes)")

        self.stdout.write(f"\n{'='*50}")
        self.stdout.write(self.style.SUCCESS(
            f"  [OK] {plants_created} plants | {diseases_created} diseases seeded."
        ))
        self.stdout.write(f"{'='*50}")