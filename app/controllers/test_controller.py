from flask import Blueprint
from app.services.email_service import send_verification_email

bp = Blueprint("test_controller", __name__)

@bp.route("/test-email")
def test_email():
    result = send_verification_email(
        "santiagogonzalezcoba007@gmail.com",
        "https://coyolabs.com"
    )
    print("EMAIL RESULT:", result)
    return "correo enviado"