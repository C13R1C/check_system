# app/controllers/dashboard_controller.py
"""Dashboard administrativo principal para ADMIN/SUPERADMIN."""

from datetime import datetime, timedelta

from flask import Blueprint, jsonify, render_template, request, url_for
from flask_login import current_user
from sqlalchemy import func
from sqlalchemy.orm import joinedload

from app.constants import ROLE_PENDING
from app.extensions import db
from app.models.debt import Debt
from app.models.inventory_request_item import InventoryRequestItem
from app.models.inventory_request_ticket import InventoryRequestTicket
from app.models.material import Material
from app.models.notification import Notification
from app.models.print3d_job import Print3DJob
from app.models.reservation import Reservation
from app.models.software import Software
from app.models.user import User
from app.utils.authz import min_role_required
from app.utils.statuses import (
    DebtStatus,
    InventoryRequestStatus,
    Print3DJobStatus,
    ReservationStatus,
)

dashboard_bp = Blueprint("dashboard", __name__, url_prefix="/dashboard")


def _search_reports_base() -> list[dict]:
    return [
        {
            "title": "Inventario general",
            "description": "Materiales por laboratorio, estado, código y ubicación.",
            "tags": "inventario materiales laboratorio estado código ubicación",
            "link": url_for("reports.report_inventory_view"),
        },
        {
            "title": "Adeudos",
            "description": "Seguimiento de adeudos activos y cerrados.",
            "tags": "adeudos deudas pagos",
            "link": url_for("reports.report_debts_view"),
        },
        {
            "title": "LOGS",
            "description": "Eventos administrativos y de operación.",
            "tags": "bitácora auditoría eventos logs",
            "link": url_for("reports.report_logbook_view"),
        },
        {
            "title": "Reservaciones",
            "description": "Reservas por salón, docente, grupo y estado.",
            "tags": "reservaciones calendario salones",
            "link": url_for("reports.report_reservations_view"),
        },
        {
            "title": "Objetos perdidos",
            "description": "Incidencias y estado de objetos reportados.",
            "tags": "objetos perdidos encontrados",
            "link": url_for("reports.report_lostfound_view"),
        },
        {
            "title": "Software",
            "description": "Inventario de software y seguimiento técnico.",
            "tags": "software licencias versiones seguimiento",
            "link": url_for("reports.report_software_view"),
        },
    ]


def _coerce_int(value) -> int:
    return int(value or 0)


def _build_summary_counts(today, week_start, week_end) -> dict:
    row = db.session.query(
        db.select(func.count(Reservation.id))
        .where(Reservation.status == ReservationStatus.PENDING)
        .scalar_subquery()
        .label("pending_reservations"),

        db.select(func.count(InventoryRequestTicket.id))
        .where(
            InventoryRequestTicket.status.in_(
                [InventoryRequestStatus.OPEN, InventoryRequestStatus.READY]
            )
        )
        .scalar_subquery()
        .label("active_material_requests"),

        db.select(func.count(InventoryRequestTicket.id))
        .where(InventoryRequestTicket.status == InventoryRequestStatus.OPEN)
        .scalar_subquery()
        .label("open_material_requests"),

        db.select(func.count(InventoryRequestTicket.id))
        .where(InventoryRequestTicket.status == InventoryRequestStatus.READY)
        .scalar_subquery()
        .label("ready_material_requests"),

        db.select(func.count(Debt.id))
        .where(Debt.status == DebtStatus.PENDING)
        .scalar_subquery()
        .label("open_debts"),

        db.select(func.count(Print3DJob.id))
        .where(Print3DJob.status == Print3DJobStatus.REQUESTED)
        .scalar_subquery()
        .label("pending_print3d_jobs"),

        db.select(func.count(Material.id))
        .scalar_subquery()
        .label("total_inventory"),

        db.select(func.count(Material.id))
        .where(
            Material.pieces_qty.isnot(None),
            Material.pieces_qty <= 3,
        )
        .scalar_subquery()
        .label("low_stock_count"),

        db.select(func.count(User.id))
        .where(User.role == ROLE_PENDING)
        .scalar_subquery()
        .label("pending_users_count"),

        db.select(func.count(Reservation.id))
        .where(
            Reservation.date >= week_start,
            Reservation.date <= week_end,
        )
        .scalar_subquery()
        .label("weekly_reservations"),

        db.select(func.count(Reservation.id))
        .where(Reservation.date == today)
        .scalar_subquery()
        .label("reservations_today"),

        db.select(func.count(Reservation.id))
        .where(
            Reservation.date == today,
            Reservation.status == ReservationStatus.APPROVED,
        )
        .scalar_subquery()
        .label("approved_today"),

        db.select(func.count(Reservation.id))
        .where(
            Reservation.date == today,
            Reservation.status == ReservationStatus.PENDING,
        )
        .scalar_subquery()
        .label("pending_today"),
    ).one()

    return {
        "pending_reservations": _coerce_int(row.pending_reservations),
        "active_material_requests": _coerce_int(row.active_material_requests),
        "open_material_requests": _coerce_int(row.open_material_requests),
        "ready_material_requests": _coerce_int(row.ready_material_requests),
        "open_debts": _coerce_int(row.open_debts),
        "pending_print3d_jobs": _coerce_int(row.pending_print3d_jobs),
        "total_inventory": _coerce_int(row.total_inventory),
        "low_stock_count": _coerce_int(row.low_stock_count),
        "pending_users_count": _coerce_int(row.pending_users_count),
        "weekly_reservations": _coerce_int(row.weekly_reservations),
        "reservations_today": _coerce_int(row.reservations_today),
        "approved_today": _coerce_int(row.approved_today),
        "pending_today": _coerce_int(row.pending_today),
    }


def _build_operational_snapshot(
    activity_limit: int = 8,
    *,
    today=None,
    week_start=None,
    week_end=None,
    summary_counts: dict | None = None,
) -> dict:
    if today is None:
        today = datetime.now().date()
    if week_start is None:
        week_start = today - timedelta(days=today.weekday())
    if week_end is None:
        week_end = week_start + timedelta(days=6)

    counts = summary_counts or _build_summary_counts(today, week_start, week_end)

    pending_reservations = (
        Reservation.query
        .options(joinedload(Reservation.user))
        .filter(Reservation.status == ReservationStatus.PENDING)
        .order_by(Reservation.created_at.asc())
        .limit(activity_limit)
        .all()
    )

    active_material_requests = (
        InventoryRequestTicket.query
        .options(joinedload(InventoryRequestTicket.user))
        .filter(
            InventoryRequestTicket.status.in_(
                [InventoryRequestStatus.OPEN, InventoryRequestStatus.READY]
            )
        )
        .order_by(InventoryRequestTicket.created_at.asc())
        .limit(activity_limit)
        .all()
    )

    ready_request_items = (
        InventoryRequestItem.query
        .options(
            joinedload(InventoryRequestItem.ticket).joinedload(InventoryRequestTicket.user),
            joinedload(InventoryRequestItem.material),
        )
        .join(InventoryRequestTicket, InventoryRequestItem.ticket_id == InventoryRequestTicket.id)
        .filter(InventoryRequestTicket.status == InventoryRequestStatus.READY)
        .order_by(InventoryRequestItem.id.desc())
        .limit(activity_limit)
        .all()
    )

    open_debts_recent = (
        Debt.query
        .options(joinedload(Debt.user), joinedload(Debt.material))
        .filter(Debt.status == DebtStatus.PENDING)
        .order_by(Debt.created_at.desc())
        .limit(activity_limit)
        .all()
    )

    pending_print3d_recent = (
        Print3DJob.query
        .filter(Print3DJob.status == Print3DJobStatus.REQUESTED)
        .order_by(Print3DJob.created_at.desc())
        .limit(activity_limit)
        .all()
    )

    recent_activity = (
        Notification.query
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(activity_limit)
        .all()
    )

    return {
        "counts": {
            "pending_reservations": counts["pending_reservations"],
            "active_material_requests": counts["active_material_requests"],
            "ready_material_requests": counts["ready_material_requests"],
            "open_debts": counts["open_debts"],
            "pending_print3d_jobs": counts["pending_print3d_jobs"],
        },
        "pending_reservations": [
            {
                "id": r.id,
                "user": r.user.email if r.user else "-",
                "room": r.room,
                "date": str(r.date),
                "time": f"{r.start_time}-{r.end_time}",
                "link": "/reservations/admin",
            }
            for r in pending_reservations
        ],
        "active_material_requests": [
            {
                "id": t.id,
                "status": t.status,
                "user": t.user.email if t.user else "-",
                "request_date": str(t.request_date),
                "link": f"/inventory-requests/admin/{t.id}",
            }
            for t in active_material_requests
        ],
        "ready_material_requests": [
            {
                "ticket_id": item.ticket_id,
                "material": item.material.name if item.material else f"ID {item.material_id}",
                "quantity_requested": item.quantity_requested,
                "user": item.ticket.user.email if item.ticket and item.ticket.user else "-",
                "link": f"/inventory-requests/admin/{item.ticket_id}",
            }
            for item in ready_request_items
        ],
        "open_debts_recent": [
            {
                "id": d.id,
                "user": d.user.email if d.user else "-",
                "material": d.material.name if d.material else "-",
                "created_at": str(d.created_at),
                "link": "/debts/admin",
            }
            for d in open_debts_recent
        ],
        "pending_print3d_recent": [
            {
                "id": job.id,
                "title": job.title,
                "status": job.status,
                "created_at": str(job.created_at),
                "link": "/prints3d/admin",
            }
            for job in pending_print3d_recent
        ],
        "recent_activity": [
            {
                "title": n.title,
                "message": n.message,
                "created_at": str(n.created_at),
                "link": n.link or "/notifications",
            }
            for n in recent_activity
        ],
        "summary": {
            "total_inventory": counts["total_inventory"],
            "reservations_today": counts["reservations_today"],
            "approved_today": counts["approved_today"],
            "pending_today": counts["pending_today"],
            "open_material_requests": counts["open_material_requests"],
            "ready_material_requests": counts["ready_material_requests"],
            "open_debts": counts["open_debts"],
            "low_stock_count": counts["low_stock_count"],
            "pending_users_count": counts["pending_users_count"],
            "weekly_reservations": counts["weekly_reservations"],
            "pending_print3d_jobs": counts["pending_print3d_jobs"],
        },
    }


@dashboard_bp.route("/", methods=["GET"])
@min_role_required("ADMIN")
def dashboard_home():
    today = datetime.now().date()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    summary_counts = _build_summary_counts(today, week_start, week_end)

    recent_reservations = (
        Reservation.query
        .options(joinedload(Reservation.user))
        .order_by(Reservation.created_at.desc())
        .limit(5)
        .all()
    )

    recent_material_requests = (
        InventoryRequestTicket.query
        .options(joinedload(InventoryRequestTicket.user))
        .order_by(InventoryRequestTicket.created_at.desc())
        .limit(5)
        .all()
    )

    recent_debts = (
        Debt.query
        .options(joinedload(Debt.user), joinedload(Debt.material))
        .order_by(Debt.created_at.desc())
        .limit(5)
        .all()
    )

    top_materials = (
        db.session.query(
            Material.name,
            func.coalesce(func.sum(InventoryRequestItem.quantity_requested), 0).label("total"),
        )
        .join(InventoryRequestItem, InventoryRequestItem.material_id == Material.id)
        .group_by(Material.id, Material.name)
        .order_by(func.sum(InventoryRequestItem.quantity_requested).desc())
        .limit(5)
        .all()
    )

    top_debtors = (
        db.session.query(
            User.email,
            func.count(Debt.id).label("total_open"),
        )
        .join(Debt, Debt.user_id == User.id)
        .filter(Debt.status == DebtStatus.PENDING)
        .group_by(User.id, User.email)
        .order_by(func.count(Debt.id).desc())
        .limit(5)
        .all()
    )

    top_rooms = (
        db.session.query(
            Reservation.room,
            func.count(Reservation.id).label("total"),
        )
        .group_by(Reservation.room)
        .order_by(func.count(Reservation.id).desc())
        .limit(5)
        .all()
    )

    ops_snapshot = _build_operational_snapshot(
        today=today,
        week_start=week_start,
        week_end=week_end,
        summary_counts=summary_counts,
    )

    return render_template(
        "dashboard/home.html",
        active_page="dashboard",
        total_inventory=summary_counts["total_inventory"],
        reservations_today=summary_counts["reservations_today"],
        approved_today=summary_counts["approved_today"],
        pending_today=summary_counts["pending_today"],
        open_material_requests=summary_counts["open_material_requests"],
        ready_material_requests=summary_counts["ready_material_requests"],
        open_debts=summary_counts["open_debts"],
        low_stock_count=summary_counts["low_stock_count"],
        pending_users_count=summary_counts["pending_users_count"],
        weekly_reservations=summary_counts["weekly_reservations"],
        recent_reservations=recent_reservations,
        recent_material_requests=recent_material_requests,
        recent_debts=recent_debts,
        top_materials=top_materials,
        top_debtors=top_debtors,
        top_rooms=top_rooms,
        ops_snapshot=ops_snapshot,
    )


@dashboard_bp.route("/ops-feed", methods=["GET"])
@min_role_required("ADMIN")
def dashboard_ops_feed():
    today = datetime.now().date()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    summary_counts = _build_summary_counts(today, week_start, week_end)
    snapshot = _build_operational_snapshot(
        today=today,
        week_start=week_start,
        week_end=week_end,
        summary_counts=summary_counts,
    )
    return jsonify(snapshot)


@dashboard_bp.route("/search", methods=["GET"])
@min_role_required("ADMIN")
def dashboard_quick_search():
    search_text = (request.args.get("q") or "").strip()

    inventory_items = (
        Material.query
        .options(joinedload(Material.career), joinedload(Material.lab))
        .order_by(Material.created_at.desc())
        .limit(30)
        .all()
    )

    software_items = (
        Software.query
        .options(joinedload(Software.lab))
        .order_by(Software.created_at.desc())
        .limit(30)
        .all()
    )

    report_items = _search_reports_base()

    return render_template(
        "dashboard/search.html",
        inventory_items=inventory_items,
        software_items=software_items,
        report_items=report_items,
        search_text=search_text,
        active_page="dashboard",
    )