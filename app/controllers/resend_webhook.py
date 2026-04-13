from flask import Blueprint, request, jsonify
import json

bp = Blueprint("resend_webhook", __name__)

@bp.route("/webhooks/resend", methods=["POST"])
def resend_webhook():
    raw_body = request.get_data(as_text=True)

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