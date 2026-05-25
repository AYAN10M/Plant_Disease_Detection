"""
seed_model_catalog — populate Plant + Disease tables from the two-stage model labels.

Usage
-----
    python manage.py seed_model_catalog
    python manage.py seed_model_catalog --keep-media

What it does
------------
1. Deletes all existing Detection, Disease, Plant records (wrapped in a transaction).
2. Optionally removes media sub-directories.
3. Creates one Plant record per entry in DISEASE_CLASSES (plants with a disease model).
4. Creates one Disease record per class label for each plant.
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


# ─────────────────────────────────────────────────────────────────────────────
# Plant metadata
# ─────────────────────────────────────────────────────────────────────────────

PLANT_METADATA: dict[str, dict] = {
    # Only plants with a trained disease model are seeded.
    "Apple": {
        "scientific_name": "Malus domestica",
        "family": "Rosaceae",
        "origin": "Central Asia (Kazakhstan region)",
        "growing_season": "Spring to Autumn (temperate climates)",
        "ideal_climate": (
            "Temperate climate with cold winters (chilling hours 800–1,200 h below 7 °C) "
            "and warm, dry summers. Optimal temperature 18–24 °C. "
            "Annual rainfall 600–800 mm; avoid waterlogging."
        ),
        "common_uses": (
            "Fresh consumption, juice, cider, vinegar, jam, and dried fruit. "
            "Leaves and bark used in traditional medicine as anti-inflammatory agents."
        ),
        "description": (
            "Apple (Malus domestica) is one of the most widely cultivated fruit trees globally, "
            "with over 7,500 cultivars grown across temperate regions. "
            "It is susceptible to fungal diseases—Apple Scab, Black Rot, and Cedar Apple Rust—"
            "that affect leaf health, fruit marketability, and overall yield."
        ),
    },
    "Grape": {
        "scientific_name": "Vitis vinifera",
        "family": "Vitaceae",
        "origin": "Near East / Mediterranean (Georgia, Armenia)",
        "growing_season": "Spring bud-break to Autumn harvest (April–October in temperate zones)",
        "ideal_climate": (
            "Mediterranean climate with warm, dry summers and mild, wet winters. "
            "Optimal temperature 15–25 °C during the growing season. "
            "Annual rainfall 500–700 mm; high humidity during fruit set promotes disease."
        ),
        "common_uses": (
            "Wine production, fresh table grapes, raisins, grape juice, and jam. "
            "Grape seed extract used as an antioxidant supplement."
        ),
        "description": (
            "Grapevine (Vitis vinifera) is a woody perennial vine cultivated for over 6,000 years "
            "for fruit and wine production. It is prone to several destructive diseases—"
            "Black Rot, Esca (Black Measles), and Isariopsis Leaf Spot—"
            "that can devastate entire harvests if not managed."
        ),
    },
    "Potato": {
        "scientific_name": "Solanum tuberosum",
        "family": "Solanaceae",
        "origin": "Andes mountains, South America (Peru and Bolivia)",
        "growing_season": "Rabi (cool season, October–March in South Asia); Spring–Summer in temperate zones",
        "ideal_climate": (
            "Cool climate with 15–20 °C during tuber formation. "
            "Requires well-drained, loose, sandy-loam soil with pH 5.2–6.4. "
            "Annual rainfall 500–700 mm; frost-sensitive during early and late stages."
        ),
        "common_uses": (
            "Staple food (boiled, roasted, fried, chips), industrial starch, animal feed, "
            "and vodka/potato spirits. Leaves occasionally used in folk medicine."
        ),
        "description": (
            "Potato (Solanum tuberosum) is the world's fourth-largest food crop and a "
            "critical source of carbohydrates and nutrients. "
            "Early Blight (Alternaria solani) and Late Blight (Phytophthora infestans) "
            "are the primary leaf diseases detected by the Midori model."
        ),
    },
    "Pepper": {
        "scientific_name": "Capsicum annuum",
        "family": "Solanaceae",
        "origin": "Central and South America (Mexico, Bolivia)",
        "growing_season": "Kharif (June–October in South Asia); warm season crop in temperate zones",
        "ideal_climate": (
            "Warm climate with 20–30 °C; sensitive to frost and waterlogging. "
            "Requires well-drained, loamy soil with pH 6.0–7.0. "
            "Annual rainfall 600–900 mm; prefers low to moderate humidity."
        ),
        "common_uses": (
            "Culinary spice (paprika, chilli powder, cayenne), fresh consumption, "
            "pickling, and sauces. Capsaicin used in pain-relief creams and food additives."
        ),
        "description": (
            "Pepper (Capsicum annuum) encompasses bell peppers, chillies, and paprika. "
            "It is an important vegetable and spice crop worldwide. "
            "Bacterial Spot (Xanthomonas spp.) is the primary leaf disease detected "
            "by the current Midori model."
        ),
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# Disease catalog — accurate, rich data for every model class
# ─────────────────────────────────────────────────────────────────────────────

DISEASE_CATALOG: dict[str, dict[str, dict]] = {

    # ── Apple ─────────────────────────────────────────────────────────────────
    "Apple": {
        "Apple Scab": {
            "description": (
                "Apple Scab is a common fungal disease of apple trees caused by "
                "Venturia inaequalis. It is most severe in cool, wet spring weather "
                "and can significantly reduce fruit marketability and cause early defoliation."
            ),
            "cause": (
                "Caused by the ascomycete fungus Venturia inaequalis. "
                "Primary inoculum overwinters in infected leaf litter; "
                "ascospores are released during spring rains and infect young leaves and fruit."
            ),
            "symptoms": (
                "Olive-green to dark brown, scab-like lesions on upper leaf surfaces. "
                "Infected fruit develops corky, rough, dark spots. "
                "Severe infections cause distorted leaves and premature defoliation."
            ),
            "remedy": (
                "Apply fungicides containing captan, myclobutanil, or mancozeb at bud-break "
                "and repeat every 7-14 days during wet weather. "
                "Remove and destroy infected fallen leaves to reduce overwintering inoculum."
            ),
            "prevention": (
                "Plant resistant apple varieties where available. "
                "Rake and destroy all fallen leaves in autumn. "
                "Prune trees to improve canopy air circulation. "
                "Apply protective fungicide sprays before infection periods (rain events)."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Black Rot": {
            "description": (
                "Black Rot is a destructive fungal disease of apple caused by "
                "Botryosphaeria obtusa (anamorph: Diplodia seriata). "
                "It can kill branches and cause fruit mummification, significantly impacting yield."
            ),
            "cause": (
                "Caused by the fungus Botryosphaeria obtusa. "
                "The pathogen enters through wounds, pruning cuts, and fire-blight lesions. "
                "It overwinters in dead bark, mummified fruit, and infected wood."
            ),
            "symptoms": (
                "Dark brown to black cankers with sunken, cracked bark on branches. "
                "Fruit rot begins as small purple spots that expand into circular lesions "
                "with concentric rings (frog-eye pattern). "
                "Infected fruit eventually shrivels and mummifies."
            ),
            "remedy": (
                "Prune infected wood 8-12 inches below visible cankers. "
                "Apply copper-based or captan fungicides during the growing season. "
                "Remove and destroy all mummified fruit and dead wood. "
                "Avoid overhead irrigation to reduce leaf wetness."
            ),
            "prevention": (
                "Maintain tree vigor through proper fertilization and irrigation. "
                "Prune out dead and diseased wood annually in dry weather. "
                "Apply wound sealant after pruning cuts. "
                "Control fire blight infections promptly as they create entry points."
            ),
            "severity": "severe",
            "affected_parts": "fruit, twig, leaf",
        },
        "Cedar Apple Rust": {
            "description": (
                "Cedar Apple Rust is a fungal disease caused by Gymnosporangium juniperi-virginianae "
                "that requires two hosts to complete its life cycle: apple/crabapple and eastern red cedar "
                "(Juniperus virginiana). It weakens trees and reduces fruit quality."
            ),
            "cause": (
                "Caused by the heteroecious rust fungus Gymnosporangium juniperi-virginianae. "
                "Teliospores from orange gelatinous galls on cedar/juniper trees are wind-dispersed "
                "to apple leaves during wet spring weather."
            ),
            "symptoms": (
                "Bright yellow-orange spots on upper leaf surfaces in spring. "
                "Tube-like structures (aecia) develop on the undersides of leaves. "
                "Heavy infections cause premature defoliation and reduced fruit set."
            ),
            "remedy": (
                "Apply protective fungicides (mancozeb, myclobutanil, or trifloxystrobin) "
                "from pink bud stage through petal fall. "
                "Remove nearby juniper/cedar host trees within a 300-metre radius if feasible."
            ),
            "prevention": (
                "Plant rust-resistant apple cultivars. "
                "Avoid planting apple trees near eastern red cedars or ornamental junipers. "
                "Apply fungicide sprays preventatively during the infection period (wet spring weather). "
                "Monitor cedar galls and remove them before they release spores."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Healthy": {
            "description": (
                "The apple leaf shows no visible signs of disease. "
                "The plant appears vigorous with normal leaf color and texture."
            ),
            "cause": "Not applicable — no disease detected.",
            "symptoms": "No symptoms observed. Leaf color, texture, and shape are normal.",
            "remedy": "No treatment required. Maintain current care practices.",
            "prevention": (
                "Continue regular scouting for early disease detection. "
                "Maintain proper irrigation, fertilization, and canopy management. "
                "Apply dormant oil sprays in late winter to control overwintering pests."
            ),
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    # ── Potato ────────────────────────────────────────────────────────────────
    "Potato": {
        "Early Blight": {
            "description": (
                "Early Blight is a common fungal disease of potato caused by Alternaria solani. "
                "It typically appears on older lower leaves first and can cause significant "
                "defoliation and yield loss if unmanaged."
            ),
            "cause": (
                "Caused by the fungus Alternaria solani. "
                "The pathogen survives in infected plant debris in the soil. "
                "Disease is favoured by warm temperatures (24-29°C) and alternating wet and dry conditions."
            ),
            "symptoms": (
                "Circular to angular dark brown spots with concentric rings forming a target-board pattern. "
                "Lesions are surrounded by a yellow halo. "
                "Symptoms begin on older lower leaves and progress upward. "
                "Severely infected leaves turn yellow and drop prematurely."
            ),
            "remedy": (
                "Apply fungicides containing chlorothalonil, mancozeb, or azoxystrobin at the first "
                "sign of infection and repeat every 7-14 days. "
                "Remove and dispose of heavily infected leaves. "
                "Avoid wetting foliage during irrigation."
            ),
            "prevention": (
                "Use certified disease-free seed tubers. "
                "Rotate crops — avoid planting potato or tomato in the same field for at least 2 years. "
                "Destroy all crop debris after harvest. "
                "Maintain adequate plant nutrition, especially potassium, to reduce susceptibility."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, stem",
        },
        "Late Blight": {
            "description": (
                "Late Blight is one of the most devastating plant diseases in history, caused by "
                "Phytophthora infestans. It was responsible for the Irish Potato Famine (1845-1849) "
                "and remains a serious threat to potato production worldwide."
            ),
            "cause": (
                "Caused by the oomycete Phytophthora infestans, often incorrectly called a fungus. "
                "Sporangia are dispersed by wind and rain; infection occurs rapidly in cool, moist weather "
                "(10-24°C with high relative humidity). Oospores can persist in soil for years."
            ),
            "symptoms": (
                "Water-soaked, pale green to brown lesions on leaves that rapidly enlarge. "
                "White sporulating growth visible on the underside of leaves in humid conditions. "
                "Stems develop dark brown streaks and collapse. "
                "Tubers show reddish-brown granular rot that may extend inward."
            ),
            "remedy": (
                "URGENT ACTION REQUIRED: Apply metalaxyl, cymoxanil, or mancozeb-based fungicides immediately. "
                "Remove and destroy all infected plant material — do not compost. "
                "Harvest tubers promptly if the disease is severe. "
                "Report significant outbreaks to local agricultural authorities."
            ),
            "prevention": (
                "Use certified blight-resistant varieties. "
                "Plant only certified disease-free seed tubers. "
                "Apply preventative fungicide sprays when conditions favour disease (cool and wet). "
                "Avoid overhead irrigation; use drip irrigation where possible. "
                "Hill soil over tubers to prevent sporangia from washing down to them."
            ),
            "severity": "severe",
            "affected_parts": "leaf, stem, tuber",
        },
        "Healthy": {
            "description": (
                "The potato leaf shows no visible signs of disease. "
                "The plant appears vigorous with normal green foliage."
            ),
            "cause": "Not applicable — no disease detected.",
            "symptoms": "No symptoms observed. Leaves are uniformly green with no lesions or discoloration.",
            "remedy": "No treatment required. Maintain current agronomic practices.",
            "prevention": (
                "Continue crop rotation (2+ years between solanaceous crops). "
                "Scout regularly for early signs of blight. "
                "Ensure adequate drainage and avoid waterlogging. "
                "Monitor weather forecasts and apply preventative fungicides ahead of blight-favorable conditions."
            ),
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    # ── Grape ─────────────────────────────────────────────────────────────────
    "Grape": {
        "Black Rot": {
            "description": (
                "Black Rot is a serious fungal disease of grapevines caused by Guignardia bidwellii. "
                "It can destroy entire clusters and cause significant economic loss in humid climates."
            ),
            "cause": (
                "Caused by the ascomycete fungus Guignardia bidwellii. "
                "The pathogen overwinters in infected mummified berries and cane lesions. "
                "Ascospores are released during spring rains and infect young green tissues."
            ),
            "symptoms": (
                "Reddish-brown circular lesions with dark borders on leaves. "
                "Infected berries initially turn brown, then shrivel and mummify into hard, "
                "black, wrinkled structures that cling to the cluster. "
                "Cane lesions appear as elongated dark spots."
            ),
            "remedy": (
                "Apply mancozeb, myclobutanil, or tebuconazole from bud break through veraison. "
                "Remove and destroy all mummified berries and infected canes during dormant pruning. "
                "Fungicide applications must begin early — infected berries are not recoverable."
            ),
            "prevention": (
                "Remove mummified fruit and infected material during winter pruning. "
                "Prune to open the canopy for good air circulation and faster drying. "
                "Time irrigation to minimize leaf wetness duration. "
                "Apply protective fungicides before rain events, especially at critical growth stages."
            ),
            "severity": "severe",
            "affected_parts": "leaf, fruit, cane",
        },
        "Esca (Black Measles)": {
            "description": (
                "Esca is a complex trunk disease of grapevines associated with several wood-infecting fungi. "
                "It is a chronic, progressive disease with no curative treatment once a vine is infected. "
                "'Black Measles' refers to the striking tiger-stripe leaf symptoms."
            ),
            "cause": (
                "A complex of wood-decay fungi including Phaeomoniella chlamydospora, "
                "Phaeoacremonium minimum, and Fomitiporia mediterranea. "
                "Infection occurs through pruning wounds; spores are airborne."
            ),
            "symptoms": (
                "Inter-veinal chlorosis and necrosis giving a 'tiger-stripe' pattern on leaves. "
                "Dark spots on berries (measles symptom). "
                "Internal wood shows brown streaking and necrotic tissue. "
                "Apoplexy (sudden vine death) can occur in summer, causing rapid wilting of the entire vine."
            ),
            "remedy": (
                "No curative chemical treatment exists. "
                "Remove and destroy severely infected vines. "
                "Apply trunk wound protectants (paint or paste) immediately after pruning. "
                "Avoid large pruning cuts. Double pruning (spur first, final cut later) reduces infection risk."
            ),
            "prevention": (
                "Always apply wound protectants after pruning (Trichoderma-based biological products or "
                "copper-based pastes). "
                "Prune during dry weather to minimise spore dispersal. "
                "Avoid pruning in autumn and early winter when spore levels are highest. "
                "Use young, certified disease-free planting material."
            ),
            "severity": "severe",
            "affected_parts": "leaf, cane, wood",
        },
        "Leaf Blight (Isariopsis Leaf Spot)": {
            "description": (
                "Grape Leaf Blight, also known as Isariopsis Leaf Spot, is caused by the fungus "
                "Pseudocercospora vitis (formerly Isariopsis clavispora). "
                "It causes defoliation that weakens vines and reduces fruit quality."
            ),
            "cause": (
                "Caused by the fungus Pseudocercospora vitis. "
                "Conidia are produced on infected leaf surfaces and spread by wind and rain. "
                "Disease is favoured by warm, humid conditions."
            ),
            "symptoms": (
                "Angular to irregular dark brown spots near leaf margins and veins. "
                "Spots may coalesce and cause large necrotic areas. "
                "Severely infected leaves turn yellow and drop prematurely, "
                "reducing the vine's ability to ripen fruit."
            ),
            "remedy": (
                "Apply copper-based fungicides or mancozeb at first sign of symptoms. "
                "Remove and destroy infected fallen leaves. "
                "Ensure good canopy air circulation through appropriate pruning and shoot positioning."
            ),
            "prevention": (
                "Maintain open canopy architecture through shoot positioning and leaf removal. "
                "Avoid excessive nitrogen fertilization which promotes dense canopy growth. "
                "Apply preventative copper sprays in humid conditions. "
                "Remove infected leaf litter from the vineyard floor."
            ),
            "severity": "moderate",
            "affected_parts": "leaf",
        },
        "Healthy": {
            "description": (
                "The grapevine leaf shows no visible signs of disease. "
                "The vine appears vigorous with healthy green foliage."
            ),
            "cause": "Not applicable — no disease detected.",
            "symptoms": "No symptoms observed. Leaves are uniformly green with no spots or discoloration.",
            "remedy": "No treatment required. Maintain current vineyard management practices.",
            "prevention": (
                "Continue regular canopy management to maintain good air circulation. "
                "Scout weekly for early signs of disease. "
                "Monitor weather and apply preventative sprays before high-risk periods. "
                "Maintain balanced vine nutrition."
            ),
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },

    # ── Pepper ────────────────────────────────────────────────────────────────
    "Pepper": {
        "Bacterial Spot": {
            "description": (
                "Bacterial Spot is one of the most common and destructive diseases of pepper "
                "and tomato, caused by Xanthomonas spp. It can cause severe defoliation, "
                "fruit spots, and significant yield losses, especially in warm, wet conditions."
            ),
            "cause": (
                "Caused by four species of Xanthomonas: X. euvesicatoria, X. vesicatoria, "
                "X. perforans, and X. gardneri. "
                "The bacteria are seed-borne and spread by rain splash, overhead irrigation, "
                "and contaminated tools. Warm temperatures (24-30°C) and wet weather favour spread."
            ),
            "symptoms": (
                "Small, water-soaked spots on leaves that turn brown with yellow halos. "
                "Lesions may have a greasy appearance when wet. "
                "Heavily infected leaves turn yellow and drop, causing defoliation. "
                "Fruit develops slightly raised, scab-like spots with water-soaked margins."
            ),
            "remedy": (
                "Apply copper-based bactericides (copper hydroxide or copper sulfate + mancozeb) "
                "at the first sign of disease and repeat every 5-7 days during wet weather. "
                "Avoid overhead irrigation. "
                "Remove and destroy severely infected plants."
            ),
            "prevention": (
                "Use certified disease-free seed or hot-water treat seeds (50°C for 25 minutes). "
                "Use drip irrigation instead of overhead sprinklers. "
                "Rotate crops for 2-3 years away from solanaceous plants. "
                "Disinfect tools and equipment between uses. "
                "Avoid working in the field when plants are wet."
            ),
            "severity": "moderate",
            "affected_parts": "leaf, fruit",
        },
        "Healthy": {
            "description": (
                "The pepper leaf shows no visible signs of disease. "
                "The plant appears vigorous with normal, dark green foliage."
            ),
            "cause": "Not applicable — no disease detected.",
            "symptoms": "No symptoms observed. Leaves are uniformly green with no spots or lesions.",
            "remedy": "No treatment required. Maintain current care practices.",
            "prevention": (
                "Use certified disease-free transplants. "
                "Scout regularly for early signs of bacterial spot. "
                "Avoid overhead irrigation; prefer drip systems. "
                "Maintain crop rotation with non-solanaceous plants."
            ),
            "severity": "mild",
            "affected_parts": "leaf",
        },
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _remove_media_subdirs() -> None:
    media_root = Path(settings.MEDIA_ROOT)
    for rel in (
        "detections/uploads",
        "detections/gradcam_plant",
        "detections/gradcam_disease",
        "detections/gradcam",   # legacy path
        "plants",
        "diseases",
    ):
        target = media_root / rel
        if target.exists():
            shutil.rmtree(target)


# ─────────────────────────────────────────────────────────────────────────────
# Management command
# ─────────────────────────────────────────────────────────────────────────────

class Command(BaseCommand):
    help = (
        "Clear the plant/disease/detection catalog and reseed it "
        "from the two-stage model class labels with accurate disease metadata."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--keep-media",
            action="store_true",
            help="Keep uploaded images and Grad-CAM outputs while clearing the DB.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write("=" * 55)
        self.stdout.write("  Midori — Database Reseed")
        self.stdout.write("=" * 55)

        # ── Step 1: Clear existing data ───────────────────────────────────────
        self.stdout.write("\n[1] Clearing existing records ...")
        det_count = Detection.objects.count()
        dis_count = Disease.objects.count()
        pln_count = Plant.objects.count()
        Detection.objects.all().delete()
        Disease.objects.all().delete()
        Plant.objects.all().delete()
        self.stdout.write(
            f"    Deleted {det_count} detections, "
            f"{dis_count} diseases, {pln_count} plants."
        )

        if not options["keep_media"]:
            _remove_media_subdirs()
            self.stdout.write("    Media sub-directories cleared.")

        # ── Step 2: Seed plants ───────────────────────────────────────────────
        self.stdout.write("\n[2] Seeding plants ...")
        plants_created   = 0
        diseases_created = 0

        # Iterate only over plants with a trained disease model.
        for plant_name in DISEASE_CLASSES:
            meta  = PLANT_METADATA.get(plant_name, {})
            plant = Plant.objects.create(
                name=plant_name,
                scientific_name=meta.get("scientific_name", ""),
                family=meta.get("family", ""),
                origin=meta.get("origin", ""),
                growing_season=meta.get("growing_season", ""),
                ideal_climate=meta.get("ideal_climate", ""),
                common_uses=meta.get("common_uses", ""),
                description=meta.get("description", f"{plant_name} — managed by Midori."),
            )
            plants_created += 1

            class_names = DISEASE_CLASSES[plant_name]  # guaranteed to exist
            if not class_names:
                continue

            # ── Step 3: Seed diseases for this plant ──────────────────────────
            plant_catalog = DISEASE_CATALOG.get(plant_name, {})
            seeded = 0
            for disease_name in class_names:
                data = plant_catalog.get(disease_name, {})
                Disease.objects.create(
                    plant=plant,
                    name=disease_name,
                    description=data.get(
                        "description",
                        f"{disease_name} detected in {plant_name}.",
                    ),
                    cause=data.get("cause", ""),
                    symptoms=data.get("symptoms", ""),
                    remedy=data.get("remedy", ""),
                    prevention=data.get("prevention", ""),
                    severity=data.get("severity", "moderate"),
                    affected_parts=data.get("affected_parts", "leaf"),
                )
                seeded += 1
                diseases_created += 1

            self.stdout.write(
                f"    {plant_name:<10} created  ({seeded} disease classes)"
            )

        # ── Summary ───────────────────────────────────────────────────────────
        self.stdout.write("\n" + "=" * 55)
        self.stdout.write(
            self.style.SUCCESS(
                f"  [OK] {plants_created} plants  |  {diseases_created} diseases seeded."
            )
        )
        self.stdout.write("=" * 55)