# app/__init__.py
import os
import secrets
import threading
import time
from pathlib import Path, PurePosixPath

from flask import (
    Flask,
    abort,
    current_app,
    g,
    redirect,
    request,
    send_file,
    session,
    url_for,
)
from flask_login import current_user

from .config import Config
from .extensions import db, login_manager, migrate
from app.models.notification import Notification
from app.models.user import User
from app.utils.landing import resolve_landing_endpoint
from app.utils.roles import (
    ROLE_STUDENT,
    ROLE_TEACHER,
    is_admin_role,
    is_staff_role,
    normalize_role,
)

HEADER_NOTIFICATIONS_CACHE_TTL_SECONDS = 5
_header_notifications_cache_lock = threading.Lock()
_header_notifications_cache: dict[int, dict] = {}
_CSP_DIRECTIVES = {
    "default-src": ["'self'"],
    "script-src": ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
    "style-src": ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "https://fonts.googleapis.com"],
    "img-src": ["'self'", "data:", "blob:"],
    "font-src": ["'self'", "data:", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "https://fonts.gstatic.com"],
    "connect-src": ["'self'"],
    "frame-src": ["'self'"],
    "media-src": ["'self'", "blob:"],
}


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    app.jinja_env.globals.update(
        is_admin_role=is_admin_role,
        is_staff_role=is_staff_role,
    )

    from app.utils.text import (
        flash_category_label,
        normalize_spaces,
        role_label,
        smart_title,
        status_label,
    )

    app.jinja_env.filters["smart_title"] = smart_title
    app.jinja_env.filters["normalize_spaces"] = normalize_spaces
    app.jinja_env.filters["role_label"] = role_label
    app.jinja_env.filters["status_label"] = status_label
    app.jinja_env.filters["flash_category_label"] = flash_category_label

    db.init_app(app)
    migrate.init_app(app, db)

    # IMPORTAR MODELOS PARA QUE ALEMBIC LOS DETECTE
    from .models.user import User as _UserModel  # noqa: F401
    from . import models  # noqa: F401

    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(user_id):
        try:
            return db.session.get(User, int(user_id))
        except (TypeError, ValueError):
            return None

    def _ensure_csrf_token() -> str:
        token = session.get("_csrf_token")
        if not token:
            token = secrets.token_urlsafe(32)
            session["_csrf_token"] = token
        return token

    from app.controllers.home_controller import home_bp
    app.register_blueprint(home_bp)

    from app.controllers.test_controller import bp as test_bp
    app.register_blueprint(test_bp)

    from app.controllers.resend_webhook import bp as resend_webhook_bp
    app.register_blueprint(resend_webhook_bp)

    from app.controllers.dashboard_controller import dashboard_bp
    app.register_blueprint(dashboard_bp)

    from app.controllers.notifications_controller import notifications_bp
    app.register_blueprint(notifications_bp)

    from .controllers.auth_controller import auth_bp
    app.register_blueprint(auth_bp)

    from app.controllers.profile_controller import profile_bp
    app.register_blueprint(profile_bp)

    from app.controllers.inventory_controller import inventory_bp
    app.register_blueprint(inventory_bp)

    from app.controllers.inventory_requests_controller import inventory_requests_bp
    app.register_blueprint(inventory_requests_bp)

    from app.controllers.api_controller import api_bp
    app.register_blueprint(api_bp)

    from app.controllers.debts_controller import debts_bp
    app.register_blueprint(debts_bp)

    from app.controllers.reservations_controller import reservations_bp
    app.register_blueprint(reservations_bp)

    from app.controllers.lostfound_controller import lostfound_bp
    app.register_blueprint(lostfound_bp)

    from app.controllers.software_controller import software_bp
    app.register_blueprint(software_bp)

    from app.controllers.print3d_controller import print3d_bp
    app.register_blueprint(print3d_bp)

    from app.controllers.reports_controller import reports_bp
    app.register_blueprint(reports_bp)

    from app.controllers.ra_client_controller import ra_client_bp
    app.register_blueprint(ra_client_bp)

    from app.controllers.users_controller import users_bp
    app.register_blueprint(users_bp)

    from app.controllers.forum_controller import forum_bp
    app.register_blueprint(forum_bp)

    from app.controllers.admin_extra_requests_controller import admin_extra_requests_bp
    app.register_blueprint(admin_extra_requests_bp)

    from app.controllers.legal_controller import legal_bp
    app.register_blueprint(legal_bp)

    @app.get("/")
    def root_home():
        if not current_user.is_authenticated:
            return redirect(url_for("auth.auth_page"))
        return redirect(url_for(resolve_landing_endpoint(current_user.role)))

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.context_processor
    def inject_notifications():
        from app.services.notification_realtime_service import get_unread_count

        if not current_user.is_authenticated:
            return {
                "header_notifications": [],
                "header_unread_notifications": 0,
            }

        cached_payload = getattr(g, "_header_notifications_payload", None)
        if cached_payload is not None:
            return cached_payload

        now = time.monotonic()
        with _header_notifications_cache_lock:
            user_cached_payload = _header_notifications_cache.get(current_user.id)
            if user_cached_payload and now - user_cached_payload["ts"] < HEADER_NOTIFICATIONS_CACHE_TTL_SECONDS:
                g._header_notifications_payload = user_cached_payload["payload"]
                return user_cached_payload["payload"]

        notifications = (
            Notification.query
            .filter(Notification.user_id == current_user.id)
            .order_by(Notification.created_at.desc())
            .limit(5)
            .all()
        )

        unread_count = get_unread_count(current_user.id)

        payload = {
            "header_notifications": notifications,
            "header_unread_notifications": int(unread_count),
        }
        with _header_notifications_cache_lock:
            _header_notifications_cache[current_user.id] = {"ts": now, "payload": payload}
        g._header_notifications_payload = payload
        return payload

    @app.context_processor
    def inject_csrf_token():
        return {"csrf_token": _ensure_csrf_token()}

    @app.before_request
    def enforce_profile_completion():
        _ensure_csrf_token()

        if not current_user.is_authenticated:
            return None

        if not getattr(current_user, "is_verified", False):
            return None

        if getattr(current_user, "profile_completed", False):
            return None

        if normalize_role(getattr(current_user, "role", None)) not in {ROLE_STUDENT, ROLE_TEACHER}:
            return None

        endpoint = request.endpoint or ""
        allowed_endpoints = {
            "profile.complete_profile",
            "auth.logout",
            "static",
        }

        if endpoint in allowed_endpoints:
            return None

        return redirect(url_for("profile.complete_profile"))

    @app.route("/uploads/<path:filename>")
    def upload_file(filename):
        if not current_user.is_authenticated:
            abort(403)

        normalized = filename.replace("\\", "/").replace("uploads/", "").lstrip("/")
        if not normalized:
            abort(404)

        posix_path = PurePosixPath(normalized)
        if posix_path.is_absolute() or ".." in posix_path.parts:
            abort(404)

        allowed_roots = [
            Path(current_app.root_path) / "uploads",
            Path(os.path.dirname(current_app.root_path)) / "uploads",
            Path(current_app.root_path) / "static" / "uploads",
        ]

        for root in allowed_roots:
            root_resolved = root.resolve()
            candidate = (root / normalized).resolve()

            try:
                candidate.relative_to(root_resolved)
            except ValueError:
                continue

            if candidate.is_file():
                return send_file(str(candidate))

        abort(404)

    @app.before_request
    def enforce_csrf():
        if request.method not in {"POST", "PUT", "PATCH", "DELETE"}:
            return None

        endpoint = request.endpoint or ""
        if endpoint.startswith("api."):
            return None

        sent_token = request.form.get("csrf_token") or request.headers.get("X-CSRFToken")
        session_token = session.get("_csrf_token")

        if not session_token or not sent_token or sent_token != session_token:
            abort(400, description="CSRF token inválido o faltante.")

        return None

    @app.teardown_appcontext
    def cleanup_db_session(_exception=None):
        try:
            db.session.rollback()
        except Exception:
            pass
        db.session.remove()

    @app.after_request
    def apply_security_headers(response):
        csp_header_value = "; ".join(
            f"{directive} {' '.join(sources)}"
            for directive, sources in _CSP_DIRECTIVES.items()
        )
        response.headers.setdefault("Content-Security-Policy", csp_header_value)
        return response

    return app
