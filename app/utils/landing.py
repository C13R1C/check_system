def resolve_landing_endpoint(role: str | None) -> str:
    normalized = (role or "").strip().upper()

    if normalized in {"ADMIN", "SUPERADMIN"}:
        return "dashboard.dashboard_home"

    if normalized == "STAFF":
        return "home.staff_dashboard"

    return "home.student_dashboard"  # ✅ ESTE ES EL FIX