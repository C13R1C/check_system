import os
import re
from typing import Dict

import qrcode
from PIL import Image, ImageDraw, ImageFont

from flask import current_app


# =========================
# Config
# =========================
OUTPUT_DIR = os.path.join("uploads", "qrs", "materials")

CANVAS_WIDTH = 700
CANVAS_HEIGHT = 900
QR_SIZE = 420


# =========================
# Utils
# =========================
def build_material_qr_value(material_id: int) -> str:
    # SOLO ID
    return str(material_id)


def sanitize_filename(value: str) -> str:
    value = (value or "").lower().strip()
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"[^a-z0-9\-]", "", value)
    return value[:50] or "material"


def _get_output_paths(material_id: int, name: str) -> tuple[str, str]:
    safe_name = sanitize_filename(name)
    filename = f"material_{material_id}_{safe_name}.png"

    rel_path = os.path.join(OUTPUT_DIR, filename)
    abs_path = os.path.join(current_app.root_path, "static", rel_path)

    os.makedirs(os.path.dirname(abs_path), exist_ok=True)
    return rel_path, abs_path


def _load_font(size: int):
    try:
        return ImageFont.truetype("arial.ttf", size)
    except Exception:
        return ImageFont.load_default()


def _measure_text(draw: ImageDraw.ImageDraw, text: str, font) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


# =========================
# Core
# =========================
def generate_material_qr_label(material) -> Dict[str, str]:
    qr_value = build_material_qr_value(material.id)

    qr = qrcode.QRCode(
        version=None,
        box_size=10,
        border=4,
    )
    qr.add_data(qr_value)
    qr.make(fit=True)

    qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    qr_img = qr_img.resize((QR_SIZE, QR_SIZE))

    canvas = Image.new("RGB", (CANVAS_WIDTH, CANVAS_HEIGHT), "white")
    draw = ImageDraw.Draw(canvas)

    font_title = _load_font(32)
    font_footer = _load_font(24)

    title = (material.name or "MATERIAL").upper()
    if len(title) > 28:
        title = title[:28] + "..."

    text_w, text_h = _measure_text(draw, title, font_title)
    draw.text(((CANVAS_WIDTH - text_w) / 2, 40), title, fill="black", font=font_title)

    qr_x = (CANVAS_WIDTH - QR_SIZE) // 2
    qr_y = 150
    canvas.paste(qr_img, (qr_x, qr_y))

    footer = f"ID: {material.id}"
    footer_w, footer_h = _measure_text(draw, footer, font_footer)
    draw.text(
        ((CANVAS_WIDTH - footer_w) / 2, CANVAS_HEIGHT - 120),
        footer,
        fill="black",
        font=font_footer,
    )

    rel_path, abs_path = _get_output_paths(material.id, material.name)
    canvas.save(abs_path, "PNG")

    return {
        "qr_value": qr_value,
        "qr_image_path": rel_path,
    }


def regenerate_material_qr(material) -> Dict[str, str]:
    delete_material_qr_file(material.qr_image_path)
    return generate_material_qr_label(material)


def delete_material_qr_file(relative_path: str | None):
    if not relative_path:
        return

    abs_path = os.path.join(current_app.root_path, "static", relative_path)
    if os.path.exists(abs_path):
        try:
            os.remove(abs_path)
        except Exception:
            pass