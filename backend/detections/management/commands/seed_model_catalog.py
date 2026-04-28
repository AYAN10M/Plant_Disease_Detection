from pathlib import Path
import re
import shutil

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

from detections.ml_model import CLASS_NAMES
from detections.models import Detection
from diseases.models import Disease
from plants.models import Plant


PLANT_METADATA = {
    'Apple': {'scientific_name': 'Malus domestica'},
    'Blueberry': {'scientific_name': 'Vaccinium corymbosum'},
    'Cherry (including sour)': {'scientific_name': 'Prunus cerasus'},
    'Corn (maize)': {'scientific_name': 'Zea mays'},
    'Grape': {'scientific_name': 'Vitis vinifera'},
    'Orange': {'scientific_name': 'Citrus sinensis'},
    'Peach': {'scientific_name': 'Prunus persica'},
    'Pepper, bell': {'scientific_name': 'Capsicum annuum'},
    'Potato': {'scientific_name': 'Solanum tuberosum'},
    'Raspberry': {'scientific_name': 'Rubus idaeus'},
    'Rice': {'scientific_name': 'Oryza sativa'},
    'Soybean': {'scientific_name': 'Glycine max'},
    'Squash': {'scientific_name': 'Cucurbita pepo'},
    'Strawberry': {'scientific_name': 'Fragaria x ananassa'},
    'Tomato': {'scientific_name': 'Solanum lycopersicum'},
}


def _split_class_name(class_name):
    if '___' in class_name:
        return class_name.split('___', 1)

    if '__' in class_name:
        return class_name.split('__', 1)

    return class_name, class_name


def _humanize_token(token):
    token = token.replace('_', ' ').strip()
    token = re.sub(r'\s+', ' ', token)
    return token.title()


def _plant_display_name(class_name):
    plant_token, _ = _split_class_name(class_name)
    return _humanize_token(plant_token)


def _disease_display_name(class_name):
    _, disease_token = _split_class_name(class_name)
    return _humanize_token(disease_token)


def _severity_for(class_name):
    lowered = class_name.lower()

    if 'healthy' in lowered:
        return 'mild'

    if any(keyword in lowered for keyword in ('blight', 'rot', 'rust', 'mosaic', 'curl')):
        return 'severe'

    if any(keyword in lowered for keyword in ('spot', 'mildew', 'scab', 'mite', 'blight')):
        return 'moderate'

    return 'moderate'


def _disease_traits(class_name):
    disease_label = _disease_display_name(class_name)
    lowered = class_name.lower()

    if 'healthy' in lowered:
        return {
            'description': f'{disease_label} indicates healthy foliage with no major disease markers.',
            'cause': 'The trained model matched this class to a healthy leaf pattern rather than an active disease.',
            'symptoms': 'Vigorous leaf color, no obvious lesions, and normal growth.',
            'remedy': 'No treatment is required. Continue routine monitoring and balanced care.',
            'prevention': 'Keep watering and nutrition consistent so the plant stays resilient.',
            'affected_parts': 'leaf',
        }

    if 'blight' in lowered:
        return {
            'description': f'{disease_label} is a rapid tissue-damage pattern that usually shows up on leaves and stems.',
            'cause': 'Moist conditions and plant stress often accelerate blight-like infection or decay.',
            'symptoms': 'Brown or dark lesions, fast spread, and collapsing foliage.',
            'remedy': 'Remove the worst-affected leaves, improve airflow, and use an appropriate fungicide if recommended locally.',
            'prevention': 'Avoid overhead watering, keep the canopy open, and rotate crops where possible.',
            'affected_parts': 'leaf, stem',
        }

    if 'spot' in lowered:
        return {
            'description': f'{disease_label} is a spotting pattern that usually starts as small discolored lesions on foliage.',
            'cause': 'Fungal or bacterial pressure often increases spotting after humid weather or repeated leaf wetness.',
            'symptoms': 'Small brown, black, or gray spots that can expand and merge over time.',
            'remedy': 'Trim heavily infected leaves and reduce conditions that keep foliage wet for long periods.',
            'prevention': 'Water at soil level, space plants for airflow, and inspect the undersides of leaves regularly.',
            'affected_parts': 'leaf',
        }

    if 'rust' in lowered:
        return {
            'description': f'{disease_label} represents a rust infection pattern that forms powdery pustules on leaves.',
            'cause': 'Rust spores spread in cool, damp weather and can move quickly through a crop.',
            'symptoms': 'Orange, brown, or cinnamon-colored pustules and gradual yellowing.',
            'remedy': 'Remove infected debris and follow a fungicide plan recommended for the crop.',
            'prevention': 'Use resistant varieties, reduce leaf wetness, and rotate crops.',
            'affected_parts': 'leaf',
        }

    if 'mildew' in lowered:
        return {
            'description': f'{disease_label} is a powdery growth pattern that develops on the leaf surface.',
            'cause': 'Shaded, humid canopies make powdery growth more likely.',
            'symptoms': 'White or gray powder on leaves, with slow weakening of the plant.',
            'remedy': 'Increase airflow and follow a crop-specific disease treatment plan.',
            'prevention': 'Space plants properly and avoid excess humidity around the foliage.',
            'affected_parts': 'leaf',
        }

    if 'mosaic' in lowered:
        return {
            'description': f'{disease_label} is a viral-looking mosaic pattern that reduces vigor and leaf quality.',
            'cause': 'Virus spread is often linked to insect vectors or contaminated tools.',
            'symptoms': 'Mottled leaves, uneven color, and reduced growth.',
            'remedy': 'Remove severely affected plants and control insect vectors promptly.',
            'prevention': 'Use clean seed and sanitize tools between plants.',
            'affected_parts': 'leaf',
        }

    if 'curl' in lowered:
        return {
            'description': f'{disease_label} causes distorted leaves and reduced growth.',
            'cause': 'Virus pressure and pest vectors can trigger strong curling symptoms.',
            'symptoms': 'Rolled or twisted leaves and stunted shoots.',
            'remedy': 'Remove badly affected plants and manage the pest pressure early.',
            'prevention': 'Keep vectors under control and monitor new growth often.',
            'affected_parts': 'leaf',
        }

    if 'rot' in lowered:
        return {
            'description': f'{disease_label} is a decay pattern that affects fruit, roots, or stems depending on the crop.',
            'cause': 'Excess moisture and poor drainage encourage tissue breakdown and rot.',
            'symptoms': 'Soft, dark, collapsing tissue and a rapid decline in plant health.',
            'remedy': 'Remove damaged tissue and improve drainage and sanitation around the plant.',
            'prevention': 'Avoid overwatering and keep infected debris away from healthy plants.',
            'affected_parts': 'fruit, root, stem',
        }

    if 'mite' in lowered:
        return {
            'description': f'{disease_label} reflects feeding damage from mite pressure.',
            'cause': 'Hot, dry conditions often let mites multiply quickly on leaf undersides.',
            'symptoms': 'Speckled foliage, webbing, and dull bronzing on leaves.',
            'remedy': 'Use an integrated pest management plan and check adjacent plants.',
            'prevention': 'Inspect the underside of leaves and keep plants from becoming drought stressed.',
            'affected_parts': 'leaf',
        }

    return {
        'description': f'{disease_label} is one of the labels used by the trained model for this crop.',
        'cause': 'This entry keeps the API catalog aligned with the classifier output.',
        'symptoms': f'Observable disease markers associated with {disease_label.lower()}.',
        'remedy': 'Follow crop-specific treatment guidance and keep the plant under active monitoring.',
        'prevention': 'Keep the crop clean, well spaced, and regularly inspected.',
        'affected_parts': 'leaf',
    }


def _remove_media_subdirectories():
    media_root = Path(settings.MEDIA_ROOT)
    for relative_path in (
        'detections/uploads',
        'detections/gradcam',
        'plants',
        'diseases',
    ):
        target = media_root / relative_path
        if target.exists():
            shutil.rmtree(target)


class Command(BaseCommand):
    help = 'Clear the plant/disease/detection catalog and reseed it from the trained model labels.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--keep-media',
            action='store_true',
            help='Keep uploaded images and Grad-CAM outputs in media/ while clearing the database.',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        Detection.objects.all().delete()
        Disease.objects.all().delete()
        Plant.objects.all().delete()

        if not options['keep_media']:
            _remove_media_subdirectories()

        plants_by_name = {}
        for class_name in CLASS_NAMES:
            plant_name = _plant_display_name(class_name)
            if plant_name in plants_by_name:
                continue

            metadata = PLANT_METADATA.get(plant_name, {})
            plant = Plant.objects.create(
                name=plant_name,
                scientific_name=metadata.get('scientific_name', ''),
                family=metadata.get('family', ''),
                description=(
                    f'{plant_name} records are synchronized with the trained Midori model ' 
                    'so each prediction can resolve to a clean plant catalog entry.'
                ),
                origin=metadata.get('origin', ''),
                growing_season=metadata.get('growing_season', ''),
                ideal_climate=metadata.get('ideal_climate', ''),
                common_uses=metadata.get('common_uses', ''),
            )
            plants_by_name[plant_name] = plant

        diseases_created = 0
        for class_name in CLASS_NAMES:
            plant_name = _plant_display_name(class_name)
            plant = plants_by_name[plant_name]
            traits = _disease_traits(class_name)

            Disease.objects.create(
                plant=plant,
                name=class_name,
                description=traits['description'],
                cause=traits['cause'],
                symptoms=traits['symptoms'],
                remedy=traits['remedy'],
                prevention=traits['prevention'],
                severity=_severity_for(class_name),
                affected_parts=traits['affected_parts'],
            )
            diseases_created += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Reset {len(plants_by_name)} plants, {diseases_created} diseases, and all detection rows.'
            )
        )