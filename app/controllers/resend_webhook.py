import base64
import hashlib
import hmac
import json
import time

from flask import Blueprint, current_app, request, jsonify

bp = Blueprint("resend_webhook", __name__)


def _verify_resend_signature(raw_body: str) -> bool:
    secret = (current_app.config.get("RESEND_WEBHOOK_SECRET") or "").strip()
    if not secret:
        return current_app.config.get("ENV") in {"development", "dev", "local", "test", "testing"}

    webhook_id = request.headers.get("svix-id", "")
    timestamp = request.headers.get("svix-timestamp", "")
    signature_header = request.headers.get("svix-signature", "")
    if not webhook_id or not timestamp or not signature_header:
        return False

    try:
        timestamp_int = int(timestamp)
    except ValueError:
        return False
    if abs(int(time.time()) - timestamp_int) > 300:
        return False

    secret_value = secret.removeprefix("whsec_")
    try:
        secret_bytes = base64.b64decode(secret_value)
    except Exception:
        return False

    signed_payload = f"{webhook_id}.{timestamp}.{raw_body}".encode("utf-8")
    expected = base64.b64encode(
        hmac.new(secret_bytes, signed_payload, hashlib.sha256).digest()
    ).decode("ascii")

    signatures = [
        part.split(",", 1)[1] if part.startswith("v1,") else part
        for part in signature_header.split()
    ]
    return any(hmac.compare_digest(expected, signature) for signature in signatures)


@bp.route("/webhooks/resend", methods=["POST"])
def resend_webhook():
    raw_body = request.get_data(as_text=True)
    if not _verify_resend_signature(raw_body):
        return jsonify({"ok": False}), 401

    try:
        payload = json.loads(raw_body)
    except Exception:
        print("❌ Payload inválido")
        return jsonify({"ok": False}), 400

    event_type = payload.get("type")
    data = payload.get("data", {})

    email_id = data.get("email_id")
    to_list = data.get("to") or []
    recipient = to_list[0] if to_list else None
    subject = data.get("subject")

    print("\n==============================")
    print("📩 EVENTO RESEND")
    print("==============================")
    print("Tipo:", event_type)
    print("Email ID:", email_id)
    print("Para:", recipient)
    print("Asunto:", subject)

    if event_type == "email.delivered":
        print("✅ ENTREGADO")

    elif event_type == "email.bounced":
        print("❌ REBOTADO")

    elif event_type == "email.failed":
        print("⚠️ FALLÓ")

    elif event_type == "email.complained":
        print("🚨 SPAM / QUEJA")

    else:
        print("Evento no manejado:", event_type)

    print("==============================\n")

    return jsonify({"ok": True}), 200
