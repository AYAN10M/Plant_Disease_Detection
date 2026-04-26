import random
from diseases.models import Disease


def run_prediction(image_path, plant_id):
    """
    MOCK — replace this entire function with real ML model later.

    Returns:
        disease_id  : int or None
        confidence  : float (0.0 to 1.0)
    """
    diseases = Disease.objects.filter(plant_id=plant_id)

    if not diseases.exists():
        return None, 0.0

    # randomly pick a disease + random confidence for now
    disease    = random.choice(list(diseases))
    confidence = round(random.uniform(0.40, 0.99), 2)

    return disease.id, confidence


def generate_gradcam(image_path):
    """
    MOCK — replace with real Grad-CAM logic later.
    Real version will use your CNN model's activation maps.

    Returns:
        gradcam_path : str path to saved heatmap image, or None
    """
    # For now just return None — no heatmap generated
    return None