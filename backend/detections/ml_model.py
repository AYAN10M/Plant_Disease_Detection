from functools import lru_cache
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps
from tensorflow import keras


MODEL_PATH = Path(__file__).resolve().parent / 'plant_disease_vgg16.keras.h5'

# Keras directory-order classes from the training dataset.
CLASS_NAMES = (
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Blueberry___healthy',
    'Cherry_(including_sour)___Powdery_mildew',
    'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight',
    'Corn_(maize)___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Rice__Bacterialblight',
    'Rice__Blast',
    'Rice__Brownspot',
    'Rice__Tungro',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
)


@lru_cache(maxsize=1)
def _get_model():
    return keras.models.load_model(MODEL_PATH)


@lru_cache(maxsize=1)
def _get_input_size():
    model = _get_model()
    height, width = model.input_shape[1], model.input_shape[2]
    return int(height), int(width)


def _preprocess_image(image_path):
    height, width = _get_input_size()
    image = keras.utils.load_img(image_path, target_size=(height, width))
    image_array = keras.utils.img_to_array(image)
    image_array = np.expand_dims(image_array, axis=0)
    return keras.applications.vgg16.preprocess_input(image_array)


def _load_original_image(image_path):
    with Image.open(image_path) as image:
        return image.convert('RGB')


def _find_last_conv_layer(model):
    for layer in reversed(model.layers):
        if isinstance(layer, keras.layers.Conv2D):
            return layer.name

        if hasattr(layer, 'layers'):
            nested_name = _find_last_conv_layer(layer)
            if nested_name is not None:
                return nested_name

    return None


def _predict_top_class(image_path):
    model = _get_model()
    image_batch = _preprocess_image(image_path)
    probabilities = model.predict(image_batch, verbose=0)[0]
    class_index = int(np.argmax(probabilities))
    confidence = float(probabilities[class_index])

    if class_index >= len(CLASS_NAMES):
        return None, 0.0

    return CLASS_NAMES[class_index], confidence


def _resolve_disease(class_name, plant_id=None):
    from diseases.models import Disease

    if plant_id is not None:
        disease = Disease.objects.filter(plant_id=plant_id, name=class_name).first()
        if disease is not None:
            return disease

    disease = Disease.objects.filter(name=class_name).first()
    if disease is not None:
        return disease

    return None


def run_prediction(image_path, plant_id=None):
    """
    Run the trained VGG16 model on the uploaded image.

    Returns:
        disease_id  : int or None
        confidence  : float (0.0 to 1.0)
        class_name   : str or None
    """
    try:
        class_name, confidence = _predict_top_class(image_path)
    except Exception:
        return None, 0.0, None

    if not class_name:
        return None, 0.0, None

    disease = _resolve_disease(class_name, plant_id)
    if disease is None:
        return None, confidence, class_name

    return disease.id, confidence, class_name


def generate_gradcam(image_path, class_name):
    """
    Generate a Grad-CAM overlay for the predicted class and save it to media.
    """
    try:
        model = _get_model()
        last_conv_layer_name = _find_last_conv_layer(model)
        if last_conv_layer_name is None or class_name not in CLASS_NAMES:
            return None

        grad_model = keras.models.Model(
            inputs=model.inputs,
            outputs=[model.get_layer(last_conv_layer_name).output, model.output],
        )

        image_batch = _preprocess_image(image_path)
        original_image = _load_original_image(image_path)
        class_index = CLASS_NAMES.index(class_name)

        with tf.GradientTape() as tape:
            conv_outputs, predictions = grad_model(image_batch)
            class_score = predictions[:, class_index]

        gradients = tape.gradient(class_score, conv_outputs)
        pooled_gradients = tf.reduce_mean(gradients, axis=(0, 1, 2))

        conv_outputs = conv_outputs[0].numpy()
        pooled_gradients = pooled_gradients.numpy()

        for index in range(conv_outputs.shape[-1]):
            conv_outputs[:, :, index] *= pooled_gradients[index]

        heatmap = np.mean(conv_outputs, axis=-1)
        heatmap = np.maximum(heatmap, 0)
        max_heatmap = np.max(heatmap)
        if max_heatmap == 0:
            return None

        heatmap /= max_heatmap
        heatmap = np.uint8(255 * heatmap)

        heatmap_image = Image.fromarray(heatmap).resize(original_image.size)
        heatmap_image = ImageOps.colorize(
            heatmap_image.convert('L'),
            black='black',
            white='red',
        ).convert('RGB')

        overlay = Image.blend(original_image, heatmap_image, alpha=0.45)

        output_dir = Path(__file__).resolve().parent.parent / 'media' / 'detections' / 'gradcam'
        output_dir.mkdir(parents=True, exist_ok=True)

        output_name = f'{Path(image_path).stem}_gradcam.jpg'
        output_path = output_dir / output_name
        overlay.save(output_path, format='JPEG', quality=92)

        return f'detections/gradcam/{output_name}'
    except Exception:
        return None