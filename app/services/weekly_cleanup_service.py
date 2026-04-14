from __future__ import annotations

from pathlib import Path, PurePosixPath

from flask import current_app

from app.extensions import db
from app.models.forum_comment import ForumComment
from app.models.forum_post import ForumPost
from app.models.lost_found import LostFound
from app.services.audit_service import log_event

RETURNED_EQUIVALENT_STATUSES = {
    "RETURNED",
    "DELIVERED",
    "RESOLVED",
    "RETURNED_TO_OWNER",
}


def _resolve_safe_lostfound_image_path(evidence_ref: str | None) -> Path | None:
    if not evidence_ref:
        return None

    normalized = str(evidence_ref).replace("\\", "/").strip()
    if not normalized:
        return None

    # No aceptar rutas absolutas
    if normalized.startswith("/"):
        return None

    # Solo aceptar refs dentro de lostfound
    if "lostfound/" not in normalized:
        return None

    tail = normalized.split("lostfound/", 1)[1].lstrip("/")
    if not tail:
        return None

    rel_posix = PurePosixPath("uploads/lostfound") / PurePosixPath(tail)
    if rel_posix.is_absolute() or ".." in rel_posix.parts:
        return None

    expected_root = (
        Path(current_app.root_path) / "static" / "uploads" / "lostfound"
    ).resolve()
    candidate = (Path(current_app.root_path) / "static" / rel_posix).resolve()

    try:
        candidate.relative_to(expected_root)
    except ValueError:
        return None

    return candidate


def run_weekly_hard_cleanup() -> dict[str, int]:
    summary = {
        "forum_posts_deleted": 0,
        "forum_comments_deleted": 0,
        "lost_found_deleted": 0,
        "lost_found_images_deleted": 0,
    }

    try:
        # 1) Foro: borrar comentarios primero, luego posts
        summary["forum_comments_deleted"] = int(
            ForumComment.query.delete(synchronize_session=False) or 0
        )
        summary["forum_posts_deleted"] = int(
            ForumPost.query.delete(synchronize_session=False) or 0
        )

        # 2) Lost & Found: solo entregados/devueltos
        returned_items = (
            LostFound.query
            .filter(db.func.upper(LostFound.status).in_(RETURNED_EQUIVALENT_STATUSES))
            .all()
        )

        for item in returned_items:
            image_path = _resolve_safe_lostfound_image_path(item.evidence_ref)

            if image_path and image_path.exists() and image_path.is_file():
                try:
                    image_path.unlink(missing_ok=True)
                    summary["lost_found_images_deleted"] += 1
                except Exception as exc:
                    current_app.logger.warning(
                        "No se pudo borrar imagen de lost_found '%s': %s",
                        image_path,
                        exc,
                    )

            db.session.delete(item)
            summary["lost_found_deleted"] += 1

        log_event(
            module="SYSTEM",
            action="WEEKLY_HARD_CLEANUP",
            entity_label="Forum + LostFound",
            description=(
                "Limpieza automática semanal: "
                f"posts={summary['forum_posts_deleted']}, "
                f"comments={summary['forum_comments_deleted']}, "
                f"lost_found={summary['lost_found_deleted']}, "
                f"images={summary['lost_found_images_deleted']}"
            ),
            metadata=summary,
        )

        db.session.commit()
        current_app.logger.info("weekly_hard_cleanup executed: %s", summary)
        return summary

    except Exception:
        db.session.rollback()
        current_app.logger.exception("weekly_hard_cleanup failed")
        raise
