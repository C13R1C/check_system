from flask import Blueprint, abort, current_app
from app.services.email_service import send_verification_email
from app.utils.authz import min_role_required

bp = Blueprint("test_controller", __name__)

@bp.route("/test-email")
@min_role_required("ADMIN")
def test_email():
    if not current_app.debug:
        abort(404)

    result = send_verification_email(
        "santiagogonzalezcoba007@gmail.com",
        "https://coyolabs.com"
    )
    print("EMAIL RESULT:", result)
    return "correo enviado"
