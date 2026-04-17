import re

from flask import Blueprint, flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required
from sqlalchemy import func
from sqlalchemy.orm import joinedload

from app.extensions import db
from app.models.academic_level import AcademicLevel
from app.models.career import Career
from app.models.debt import Debt
from app.models.inventory_request_ticket import InventoryRequestTicket
from app.models.reservation import Reservation
from app.models.teacher_academic_load import TeacherAcademicLoad
from app.services.audit_service import log_event
from app.utils.landing import resolve_landing_endpoint
from app.utils.validators import normalize_and_validate_group_code, normalize_and_validate_phone
from app.utils.roles import ROLE_TEACHER, ROLE_STUDENT, ROLE_STAFF, normalize_role
from app.utils.text import normalize_upper

profile_bp = Blueprint("profile", __name__, url_prefix="/profile")


def _build_profile_catalog_options() -> tuple[list[Career], list[AcademicLevel], dict[int, list[int]]]:
    careers = Career.query.order_by(Career.name.asc()).all()

    academic_levels = (
        AcademicLevel.query
        .filter(
            AcademicLevel.is_active.is_(True),
            func.upper(AcademicLevel.code).in_(("TSU", "ING", "LIC")),
        )
        .order_by(AcademicLevel.name.asc())
        .all()
    )

    all_level_ids = [level.id for level in academic_levels]
    career_level_map: dict[int, list[int]] = {
        career.id: all_level_ids[:] for career in careers
    }

    return careers, academic_levels, career_level_map


def _is_professor_role(role: str | None) -> bool:
    normalized = normalize_role(role)
    return normalized == ROLE_TEACHER


def _is_staff_role(role: str | None) -> bool:
    normalized = normalize_role(role)
    return normalized == ROLE_STAFF


def _requires_profile_completion(role: str | None) -> bool:
    normalized = normalize_role(role)
    return normalized in {ROLE_STUDENT, ROLE_TEACHER, ROLE_STAFF}


def _has_min_real_chars(value: str, minimum: int = 3) -> bool:
    normalized = re.sub(r"\s+", "", value or "")
    return len(normalized) >= minimum


def _normalize_group_name(raw_group_name: str | None) -> tuple[str | None, str | None]:
    group_name = normalize_upper(raw_group_name) or ""
    if not group_name:
        return None, None
    if len(group_name) > 80:
        return None, "El grupo no puede exceder 80 caracteres."
    return group_name, None


def _extract_matricula_from_email(email: str | None) -> str | None:
    email_normalized = (email or "").strip().lower()
    if not email_normalized.endswith("@utpn.edu.mx"):
        return None

    local_part = email_normalized.split("@", 1)[0]
    digits = re.sub(r"\D", "", local_part)

    if len(digits) == 8:
        return digits

    return None


def _normalize_subject_name(raw_subject_name: str | None) -> tuple[str | None, str | None]:
    subject_name = " ".join((raw_subject_name or "").strip().split()).upper()
    if not subject_name:
        return None, "La materia es obligatoria."
    if len(subject_name) > 160:
        return None, "La materia no puede exceder 160 caracteres."
    return subject_name, None


def _build_teacher_subject_blocks(loads: list[TeacherAcademicLoad]) -> list[dict]:
    grouped: dict[str, list[TeacherAcademicLoad]] = {}
    for load in loads:
        subject_name = (load.subject_name or "").strip().upper()
        if not subject_name:
            continue
        grouped.setdefault(subject_name, []).append(load)

    blocks: list[dict] = []
    for subject_name in sorted(grouped.keys()):
        groups = sorted(
            grouped[subject_name],
            key=lambda item: ((item.group_code or "").upper(), item.id),
        )
        blocks.append(
            {
                "subject_name": subject_name,
                "groups": groups,
            }
        )
    return blocks


def _normalize_and_validate_utpn_email(email: str | None) -> tuple[str | None, str | None]:
    normalized = (email or "").strip().lower()
    if not normalized:
        return None, "El correo institucional es obligatorio."
    if not normalized.endswith("@utpn.edu.mx"):
        return None, "Debes usar un correo institucional @utpn.edu.mx."
    return normalized, None


def _normalize_and_validate_matricula(
    raw_matricula: str | None,
    role: str | None,
    email: str | None,
) -> tuple[str | None, str | None]:
    normalized_role = normalize_role(role)

    if normalized_role != ROLE_STUDENT:
        return None, None

    matricula_from_email = _extract_matricula_from_email(email)
    if matricula_from_email:
        return matricula_from_email, None

    matricula = re.sub(r"\s+", "", raw_matricula or "")
    if not matricula:
        return None, "No se pudo obtener la matrícula desde el correo institucional."
    if not matricula.isdigit():
        return None, "La matrícula debe contener solo números."
    if len(matricula) != 8:
        return None, "La matrícula debe tener exactamente 8 dígitos."
    return matricula, None


@profile_bp.route("/", methods=["GET"])
@login_required
def my_profile():
    reservations = (
        Reservation.query
        .filter(Reservation.user_id == current_user.id)
        .order_by(Reservation.created_at.desc())
        .all()
    )

    material_requests = (
        InventoryRequestTicket.query
        .filter(InventoryRequestTicket.user_id == current_user.id)
        .order_by(InventoryRequestTicket.request_date.desc(), InventoryRequestTicket.created_at.desc())
        .all()
    )

    debts = (
        Debt.query
        .options(joinedload(Debt.material))
        .filter(Debt.user_id == current_user.id)
        .order_by(Debt.created_at.desc())
        .all()
    )

    teacher_loads = []
    teacher_subject_blocks = []
    if _is_professor_role(current_user.role):
        teacher_loads = (
            TeacherAcademicLoad.query
            .options(joinedload(TeacherAcademicLoad.subject))
            .filter(TeacherAcademicLoad.teacher_id == current_user.id)
            .order_by(func.upper(TeacherAcademicLoad.subject_name).asc(), TeacherAcademicLoad.group_code.asc())
            .all()
        )
        teacher_subject_blocks = _build_teacher_subject_blocks(teacher_loads)

    return render_template(
        "profile/my_profile.html",
        reservations=reservations,
        material_requests=material_requests,
        debts=debts,
        active_page="profile",
        is_professor=_is_professor_role(current_user.role),
        teacher_loads=teacher_loads,
        teacher_subject_blocks=teacher_subject_blocks,
    )


@profile_bp.route("/teaching-load/add", methods=["POST"])
@login_required
def add_teaching_load():
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    normalized_subject_name, subject_error = _normalize_subject_name(request.form.get("subject_name"))
    group_code, group_error = normalize_and_validate_group_code(request.form.get("group_code"))

    if subject_error:
        flash(subject_error, "error")
        return redirect(url_for("profile.my_profile"))

    if group_error:
        flash(group_error, "error")
        return redirect(url_for("profile.my_profile"))

    existing = (
        TeacherAcademicLoad.query
        .filter(TeacherAcademicLoad.teacher_id == current_user.id)
        .filter(func.lower(TeacherAcademicLoad.subject_name) == normalized_subject_name.lower())
        .filter(TeacherAcademicLoad.group_code == (group_code or "").upper())
        .first()
    )
    if existing:
        flash("Esa asignación ya existe.", "warning")
        return redirect(url_for("profile.my_profile"))

    load = TeacherAcademicLoad(
        teacher_id=current_user.id,
        subject_name=normalized_subject_name,
        group_code=(group_code or "").upper(),
    )
    db.session.add(load)
    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_LOAD_ADDED",
        user_id=current_user.id,
        entity_label=f"TeacherLoad #{load.id}",
        description=f"Carga agregada: {normalized_subject_name} · grupo {group_code}",
        metadata={"load_id": load.id, "subject_name": normalized_subject_name, "group_code": group_code},
    )
    db.session.commit()

    flash("Carga académica agregada.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/teaching-load/subject/update", methods=["POST"])
@login_required
def update_teaching_subject():
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    subject_name, subject_error = _normalize_subject_name(request.form.get("subject_name"))
    new_subject_name, new_subject_error = _normalize_subject_name(request.form.get("new_subject_name"))
    if subject_error:
        flash(subject_error, "error")
        return redirect(url_for("profile.my_profile"))
    if new_subject_error:
        flash(new_subject_error, "error")
        return redirect(url_for("profile.my_profile"))

    subject_loads = (
        TeacherAcademicLoad.query
        .filter(TeacherAcademicLoad.teacher_id == current_user.id)
        .filter(func.upper(TeacherAcademicLoad.subject_name) == subject_name)
        .all()
    )
    if not subject_loads:
        flash("No se encontró la materia seleccionada.", "error")
        return redirect(url_for("profile.my_profile"))

    for load in subject_loads:
        duplicate = (
            TeacherAcademicLoad.query
            .filter(TeacherAcademicLoad.teacher_id == current_user.id)
            .filter(func.upper(TeacherAcademicLoad.subject_name) == new_subject_name)
            .filter(TeacherAcademicLoad.group_code == load.group_code)
            .first()
        )
        if duplicate and duplicate.id != load.id:
            flash(
                f"No se puede renombrar: ya existe {new_subject_name} con grupo {load.group_code}.",
                "error",
            )
            return redirect(url_for("profile.my_profile"))

    for load in subject_loads:
        load.subject_name = new_subject_name

    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_SUBJECT_UPDATED",
        user_id=current_user.id,
        entity_label=f"Teacher #{current_user.id}",
        description=f"Materia actualizada: {subject_name} → {new_subject_name}",
        metadata={"subject_name": subject_name, "new_subject_name": new_subject_name, "groups_count": len(subject_loads)},
    )
    db.session.commit()

    flash("Materia actualizada.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/teaching-load/subject/remove", methods=["POST"])
@login_required
def remove_teaching_subject():
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    subject_name, subject_error = _normalize_subject_name(request.form.get("subject_name"))
    if subject_error:
        flash(subject_error, "error")
        return redirect(url_for("profile.my_profile"))

    subject_loads = (
        TeacherAcademicLoad.query
        .filter(TeacherAcademicLoad.teacher_id == current_user.id)
        .filter(func.upper(TeacherAcademicLoad.subject_name) == subject_name)
        .all()
    )
    if not subject_loads:
        flash("No se encontró la materia seleccionada.", "error")
        return redirect(url_for("profile.my_profile"))

    removed_groups = [load.group_code for load in subject_loads]
    for load in subject_loads:
        db.session.delete(load)

    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_SUBJECT_REMOVED",
        user_id=current_user.id,
        entity_label=f"Teacher #{current_user.id}",
        description=f"Materia eliminada: {subject_name}",
        metadata={"subject_name": subject_name, "groups": removed_groups},
    )
    db.session.commit()

    flash("Materia y grupos eliminados.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/teaching-load/group/add", methods=["POST"])
@login_required
def add_teaching_group():
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    normalized_subject_name, subject_error = _normalize_subject_name(request.form.get("subject_name"))
    group_code, group_error = normalize_and_validate_group_code(request.form.get("group_code"))
    if subject_error:
        flash(subject_error, "error")
        return redirect(url_for("profile.my_profile"))
    if group_error:
        flash(group_error, "error")
        return redirect(url_for("profile.my_profile"))

    existing = (
        TeacherAcademicLoad.query
        .filter(TeacherAcademicLoad.teacher_id == current_user.id)
        .filter(func.upper(TeacherAcademicLoad.subject_name) == normalized_subject_name)
        .filter(TeacherAcademicLoad.group_code == (group_code or "").upper())
        .first()
    )
    if existing:
        flash("Ese grupo ya está registrado para la materia seleccionada.", "warning")
        return redirect(url_for("profile.my_profile"))

    load = TeacherAcademicLoad(
        teacher_id=current_user.id,
        subject_name=normalized_subject_name,
        group_code=(group_code or "").upper(),
    )
    db.session.add(load)
    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_GROUP_ADDED",
        user_id=current_user.id,
        entity_label=f"TeacherLoad #{load.id}",
        description=f"Grupo agregado: {normalized_subject_name} · {load.group_code}",
        metadata={"load_id": load.id, "subject_name": normalized_subject_name, "group_code": load.group_code},
    )
    db.session.commit()

    flash("Grupo agregado a la materia.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/teaching-load/group/<int:load_id>/update", methods=["POST"])
@login_required
def update_teaching_group(load_id: int):
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    load = TeacherAcademicLoad.query.get_or_404(load_id)
    if load.teacher_id != current_user.id:
        flash("No autorizado.", "error")
        return redirect(url_for("profile.my_profile"))

    new_group_code, group_error = normalize_and_validate_group_code(request.form.get("group_code"))
    if group_error:
        flash(group_error, "error")
        return redirect(url_for("profile.my_profile"))

    new_group_code = (new_group_code or "").upper()
    duplicate = (
        TeacherAcademicLoad.query
        .filter(TeacherAcademicLoad.teacher_id == current_user.id)
        .filter(func.upper(TeacherAcademicLoad.subject_name) == (load.subject_name or "").upper())
        .filter(TeacherAcademicLoad.group_code == new_group_code)
        .first()
    )
    if duplicate and duplicate.id != load.id:
        flash("Ese grupo ya existe para la materia seleccionada.", "error")
        return redirect(url_for("profile.my_profile"))

    old_group_code = load.group_code
    load.group_code = new_group_code
    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_GROUP_UPDATED",
        user_id=current_user.id,
        entity_label=f"TeacherLoad #{load.id}",
        description=f"Grupo actualizado: {load.subject_name} · {old_group_code} → {new_group_code}",
        metadata={"load_id": load.id, "subject_name": load.subject_name, "old_group_code": old_group_code, "new_group_code": new_group_code},
    )
    db.session.commit()

    flash("Grupo actualizado.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/teaching-load/<int:load_id>/remove", methods=["POST"])
@login_required
def remove_teaching_load(load_id: int):
    if not _is_professor_role(current_user.role):
        flash("Solo profesores pueden gestionar carga académica.", "error")
        return redirect(url_for("profile.my_profile"))

    load = TeacherAcademicLoad.query.get_or_404(load_id)
    if load.teacher_id != current_user.id:
        flash("No autorizado.", "error")
        return redirect(url_for("profile.my_profile"))

    subject_name = load.subject_name or (load.subject.name if load.subject else f"Materia #{load.subject_id}")
    group_code = load.group_code

    db.session.delete(load)
    db.session.commit()
    log_event(
        module="PROFILE",
        action="TEACHING_LOAD_REMOVED",
        user_id=current_user.id,
        entity_label=f"TeacherLoad #{load_id}",
        description=f"Carga eliminada: {subject_name} · grupo {group_code}",
        metadata={"load_id": load_id, "subject_id": load.subject_id, "subject_name": load.subject_name, "group_code": group_code},
    )
    db.session.commit()

    flash("Asignación eliminada.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/request-update", methods=["POST"])
@login_required
def request_profile_update():
    legacy_phone = (request.form.get("requested_phone") or "").strip()
    if legacy_phone:
        flash("Redirigiendo al flujo principal de cambio de teléfono.", "info")
        return request_phone_change()
    flash("La actualización de perfil ahora es autoservicio. No se generan solicitudes de perfil.", "info")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/phone-change/request", methods=["POST"])
@login_required
def request_phone_change():
    phone, phone_error = normalize_and_validate_phone(request.form.get("requested_phone"))
    if phone_error:
        flash(phone_error, "error")
        return redirect(url_for("profile.my_profile"))

    old_phone = current_user.phone
    current_user.phone = phone
    db.session.commit()
    log_event(
        module="PROFILE",
        action="PHONE_UPDATED_DIRECT",
        user_id=current_user.id,
        entity_label=f"User #{current_user.id}",
        description="Teléfono actualizado directamente por el usuario",
        metadata={
            "old_phone": old_phone,
            "new_phone": phone,
            "source": "request_phone_change",
        },
    )
    db.session.commit()
    flash("Teléfono actualizado.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/phone/update", methods=["POST"])
@login_required
def update_phone():
    phone, phone_error = normalize_and_validate_phone(request.form.get("phone"))
    if phone_error:
        flash(phone_error, "error")
        return redirect(url_for("profile.my_profile"))

    old_phone = current_user.phone
    current_user.phone = phone
    db.session.commit()
    log_event(
        module="PROFILE",
        action="PHONE_UPDATED_DIRECT",
        user_id=current_user.id,
        entity_label=f"User #{current_user.id}",
        description="Teléfono actualizado directamente por el usuario",
        metadata={"old_phone": old_phone, "new_phone": phone},
    )
    db.session.commit()
    flash("Teléfono actualizado.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/password/change", methods=["POST"])
@login_required
def change_password():
    current_password = request.form.get("current_password") or ""
    new_password = request.form.get("new_password") or ""
    confirm_new_password = request.form.get("confirm_new_password") or ""

    if not current_password or not new_password or not confirm_new_password:
        flash("Completa todos los campos para cambiar tu contraseña.", "error")
        return redirect(url_for("profile.my_profile"))

    if not current_user.check_password(current_password):
        flash("La contraseña actual es incorrecta.", "error")
        return redirect(url_for("profile.my_profile"))

    if new_password != confirm_new_password:
        flash("La nueva contraseña y su confirmación no coinciden.", "error")
        return redirect(url_for("profile.my_profile"))

    if current_password == new_password:
        flash("La nueva contraseña debe ser distinta a la actual.", "error")
        return redirect(url_for("profile.my_profile"))

    if len(new_password) < 6:
        flash("La nueva contraseña debe tener al menos 6 caracteres.", "error")
        return redirect(url_for("profile.my_profile"))

    current_user.set_password(new_password)
    db.session.commit()
    log_event(
        module="PROFILE",
        action="PASSWORD_CHANGED",
        user_id=current_user.id,
        entity_label=f"User #{current_user.id}",
        description="Cambio de contraseña realizado por el usuario",
        metadata={"self_service": True},
    )
    db.session.commit()
    flash("Contraseña actualizada correctamente.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/group/update", methods=["POST"])
@login_required
def update_group_name():
    if normalize_role(current_user.role) != ROLE_STUDENT:
        flash("Solo estudiantes pueden actualizar su grupo desde este formulario.", "error")
        return redirect(url_for("profile.my_profile"))

    group_name, group_error = _normalize_group_name(request.form.get("group_name"))
    if group_error:
        flash(group_error, "error")
        return redirect(url_for("profile.my_profile"))

    old_group_name = (current_user.group_name or "").strip() or None
    if old_group_name == group_name:
        flash("No detectamos cambios en tu grupo.", "info")
        return redirect(url_for("profile.my_profile"))

    current_user.group_name = group_name
    db.session.commit()
    log_event(
        module="PROFILE",
        action="GROUP_NAME_UPDATED",
        user_id=current_user.id,
        entity_label=f"User #{current_user.id}",
        description="Grupo actualizado por el estudiante desde Mi perfil",
        metadata={"old_group_name": old_group_name, "new_group_name": group_name},
    )
    db.session.commit()
    flash("Tu grupo se actualizó correctamente.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/update-basic", methods=["POST"])
@login_required
def update_basic_profile():
    normalized_role = normalize_role(current_user.role)
    if normalized_role not in {"ADMIN", "SUPERADMIN"}:
        flash("Solo cuentas ADMIN/SUPERADMIN pueden editar estos datos directamente.", "error")
        return redirect(url_for("profile.my_profile"))

    full_name = normalize_upper(request.form.get("full_name")) or ""
    phone, phone_error = normalize_and_validate_phone(request.form.get("phone"))

    if not full_name or not _has_min_real_chars(full_name, minimum=3):
        flash("El nombre completo es obligatorio y debe tener al menos 3 caracteres reales.", "error")
        return redirect(url_for("profile.my_profile"))

    if phone_error:
        flash(phone_error, "error")
        return redirect(url_for("profile.my_profile"))

    blocked_attempts = []
    restricted_fields = {
        "matricula": current_user.matricula or "",
        "career": current_user.career or "",
        "academic_level": current_user.academic_level or "",
    }
    for field_name, current_value in restricted_fields.items():
        submitted_value = (request.form.get(field_name) or "").strip()
        if submitted_value and submitted_value != str(current_value):
            blocked_attempts.append(field_name)

    changed_fields = []
    if full_name != (current_user.full_name or ""):
        changed_fields.append("full_name")
    if phone != (current_user.phone or ""):
        changed_fields.append("phone")

    current_user.full_name = full_name
    current_user.phone = phone
    db.session.commit()

    log_event(
        module="PROFILE",
        action="PROFILE_UPDATED",
        user_id=current_user.id,
        entity_label=f"User #{current_user.id}",
        description="Actualización de perfil por el usuario",
        metadata={
            "changed_fields": changed_fields,
            "blocked_fields_attempted": blocked_attempts,
        },
    )
    db.session.commit()

    if blocked_attempts:
        flash("Se guardaron tus cambios permitidos. Los datos académicos solo pueden modificarse por administración.", "warning")
        return redirect(url_for("profile.my_profile"))

    if not changed_fields:
        flash("No detectamos cambios en tu perfil.", "info")
        return redirect(url_for("profile.my_profile"))

    flash("Tu perfil se actualizó correctamente.", "success")
    return redirect(url_for("profile.my_profile"))


@profile_bp.route("/complete", methods=["GET", "POST"])
@login_required
def complete_profile():
    if not _requires_profile_completion(current_user.role):
        if not current_user.profile_completed:
            current_user.profile_completed = True
            current_user.profile_data_confirmed = True
            current_user.profile_confirmed_at = db.func.now()
            db.session.commit()
        return redirect(url_for(resolve_landing_endpoint(current_user.role)))

    if current_user.profile_completed:
        flash("Tu perfil ya está completo.")
        return redirect(url_for(resolve_landing_endpoint(current_user.role)))

    is_professor = _is_professor_role(current_user.role)
    is_student = normalize_role(current_user.role) == ROLE_STUDENT
    is_staff = _is_staff_role(current_user.role)

    if request.method == "POST":
        full_name = normalize_upper(request.form.get("full_name")) or ""
        matricula_raw = request.form.get("matricula")
        career_id = request.form.get("career_id", type=int)
        academic_level_id = request.form.get("academic_level_id", type=int)
        phone = (request.form.get("phone") or "").strip()
        group_name_raw = request.form.get("group_name")
        confirm_data = request.form.get("confirm_data") == "1"
        submitted_institutional_email = (request.form.get("institutional_email") or current_user.email or "").strip()

        if not full_name or not _has_min_real_chars(full_name, minimum=3):
            flash("El nombre completo es obligatorio y debe tener al menos 3 caracteres reales.")
            return redirect(url_for("profile.complete_profile"))

        phone_normalized = None
        if not is_professor:
            phone_normalized, phone_error = normalize_and_validate_phone(phone)
            if phone_error:
                flash(phone_error)
                return redirect(url_for("profile.complete_profile"))

        institutional_email, institutional_email_error = _normalize_and_validate_utpn_email(submitted_institutional_email)
        if (is_professor or is_staff) and institutional_email_error:
            flash(institutional_email_error)
            return redirect(url_for("profile.complete_profile"))
        if (is_professor or is_staff) and institutional_email != (current_user.email or "").strip().lower():
            flash("El correo institucional no coincide con tu cuenta actual.")
            return redirect(url_for("profile.complete_profile"))

        matricula, matricula_error = _normalize_and_validate_matricula(
            matricula_raw,
            current_user.role,
            current_user.email,
        )
        if matricula_error:
            flash(matricula_error)
            return redirect(url_for("profile.complete_profile"))

        if is_student and not career_id:
            flash("La carrera es obligatoria.")
            return redirect(url_for("profile.complete_profile"))

        if is_professor and not career_id:
            flash("El área de especialización es obligatoria.")
            return redirect(url_for("profile.complete_profile"))

        group_name, group_name_error = _normalize_group_name(group_name_raw)
        if group_name_error:
            flash(group_name_error)
            return redirect(url_for("profile.complete_profile"))
        group_name = normalize_upper(group_name) or None
        if is_student and not group_name:
            flash("El grupo es obligatorio para estudiantes.")
            return redirect(url_for("profile.complete_profile"))

        if not confirm_data:
            flash("Debes confirmar que tus datos son correctos para continuar.")
            return redirect(url_for("profile.complete_profile"))

        careers, _, career_level_map = _build_profile_catalog_options()

        career_obj = None
        if is_student or is_professor:
            career_obj = next((career for career in careers if career.id == career_id), None)
            if not career_obj:
                flash("La opción seleccionada no existe.")
                return redirect(url_for("profile.complete_profile"))

        if is_student and not academic_level_id:
            flash("El nivel académico es obligatorio para estudiantes.")
            return redirect(url_for("profile.complete_profile"))

        level_obj = AcademicLevel.query.get(academic_level_id) if academic_level_id else None

        if is_student and academic_level_id and not level_obj:
            flash("El nivel académico seleccionado no existe.")
            return redirect(url_for("profile.complete_profile"))

        if is_student and level_obj and level_obj.code.upper() not in {"TSU", "ING", "LIC"}:
            flash("El nivel académico seleccionado no está habilitado.")
            return redirect(url_for("profile.complete_profile"))

        if is_student and level_obj:
            allowed_level_ids = set(career_level_map.get(career_obj.id, []))
            if level_obj.id not in allowed_level_ids:
                flash("La combinación de carrera y nivel no es válida.")
                return redirect(url_for("profile.complete_profile"))

        current_user.full_name = full_name
        if not is_professor:
            current_user.phone = phone_normalized

        if is_student:
            current_user.matricula = matricula
            current_user.career_id = career_obj.id
            current_user.career = normalize_upper(career_obj.name)
            current_user.academic_level_id = level_obj.id if level_obj else None
            current_user.academic_level = level_obj.code if level_obj else None
            current_user.group_name = group_name
            current_user.professor_subjects = None
        elif is_professor:
            current_user.matricula = None
            current_user.career_id = career_obj.id
            current_user.career = normalize_upper(career_obj.name)
            current_user.academic_level_id = None
            current_user.academic_level = None
            current_user.group_name = None
        elif is_staff:
            current_user.matricula = None
            current_user.career_id = None
            current_user.career = None
            current_user.academic_level_id = None
            current_user.academic_level = None
            current_user.group_name = None

        current_user.career_year = None
        current_user.profile_completed = True
        current_user.profile_data_confirmed = True
        current_user.profile_confirmed_at = db.func.now()

        db.session.commit()
        log_event(
            module="PROFILE",
            action="PROFILE_COMPLETED",
            user_id=current_user.id,
            entity_label=f"User #{current_user.id}",
            description="Perfil completado por el usuario",
            metadata={
                "career_id": current_user.career_id,
                "academic_level_id": current_user.academic_level_id,
                "role": current_user.role,
                "profile_identifier": matricula if is_student else institutional_email,
            },
        )
        db.session.commit()

        flash("Perfil completado correctamente.")
        return redirect(url_for(resolve_landing_endpoint(current_user.role)))

    careers, academic_levels, career_level_map = _build_profile_catalog_options()
    return render_template(
        "profile/complete.html",
        is_professor=is_professor,
        is_student=is_student,
        is_staff=is_staff,
        careers=careers,
        academic_levels=academic_levels,
        career_level_map=career_level_map,
    )
