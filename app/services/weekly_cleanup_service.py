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

    if normalized.startswith("/"):
        return None

    if "lostfound/" not in normalized:
        return None

    tail = normalized.split("lostfound/", 1)[1].lstrip("/")
    if not tail:
        return None

    rel_posix = PurePosixPath("uploads/lostfound") / PurePosixPath(tail)
    if rel_posix.is_absolute() or ".." in rel_posix.parts:
        return None

    expected_root = (Path(current_app.root_path) / "static" / "uploads" / "lostfound").resolve()
    candidate = (Path(current_app.root_path) / "static" / rel_posix).resolve()

    try:
        candidate.relative_to(expected_root)
    except ValueError:
        return None

    return candidate


def run_weekly_hard_cleanup() -> dict[str, int]:
    forum_comments_deleted = ForumComment.query.delete(synchronize_session=False)
    forum_posts_deleted = ForumPost.query.delete(synchronize_session=False)

    returned_items = (
        LostFound.query
        .filter(db.func.upper(LostFound.status).in_(RETURNED_EQUIVALENT_STATUSES))
        .all()
    )

    lost_found_deleted = 0
    images_deleted = 0
    for item in returned_items:
        image_path = _resolve_safe_lostfound_image_path(item.evidence_ref)
        if image_path and image_path.exists() and image_path.is_file():
            image_path.unlink(missing_ok=True)
            images_deleted += 1

        db.session.delete(item)
        lost_found_deleted += 1

    summary = {
        "forum_posts_deleted": int(forum_posts_deleted or 0),
        "forum_comments_deleted": int(forum_comments_deleted or 0),
        "lost_found_deleted": int(lost_found_deleted),
        "lost_found_images_deleted": int(images_deleted),
    }

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
