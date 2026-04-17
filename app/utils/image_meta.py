import os

from flask import current_app
from PIL import Image, UnidentifiedImageError


HORIZONTAL_THRESHOLD = 1.15


def orientation_from_size(width: int, height: int) -> str:
    if width > height * HORIZONTAL_THRESHOLD:
        return "horizontal"
    if height > width * HORIZONTAL_THRESHOLD:
        return "vertical"
    return "square"


def extract_image_metadata(abs_path: str) -> dict | None:
    if not abs_path or not os.path.exists(abs_path):
        return None
    try:
        with Image.open(abs_path) as img:
            width, height = img.size
    except (UnidentifiedImageError, OSError, ValueError):
        return None

    if width <= 0 or height <= 0:
        return None

    return {
        "image_width": width,
        "image_height": height,
        "image_orientation": orientation_from_size(width, height),
        "image_aspect_ratio": round(width / height, 6),
    }


def material_image_metadata(image_ref: str | None) -> dict:
    if not image_ref:
        return {
            "image_width": None,
            "image_height": None,
            "image_orientation": "square",
            "image_aspect_ratio": None,
        }

    clean_ref = image_ref.lstrip("/")
    abs_path = os.path.join(current_app.root_path, "static", clean_ref)
    metadata = extract_image_metadata(abs_path)
    if metadata:
        return metadata
    return {
        "image_width": None,
        "image_height": None,
        "image_orientation": "square",
        "image_aspect_ratio": None,
    }
