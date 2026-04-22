import re
import unicodedata

UTPN_DOMAIN = "utpn.edu.mx"
EMAIL_MAX_LENGTH = 254

# Permite:
# - matrícula exacta de 8 dígitos
# - o cuenta institucional con caracteres ASCII comunes
LOCAL_PART_RE = re.compile(r"^(?:\d{8}|[a-z0-9][a-z0-9._%+\-]{0,63})$")


def normalize_email(value: str | None) -> str:
    if value is None:
        return ""

    value = unicodedata.normalize("NFKC", str(value))
    value = re.sub(r"[\u00A0\u2000-\u200D\u202F\u205F\u3000\s]+", "", value)
    value = value.strip().lower()
    return value


def split_email(email: str) -> tuple[str | None, str | None]:
    if not email or "@" not in email:
        return None, None

    parts = email.split("@")
    if len(parts) != 2:
        return None, None

    local, domain = parts[0], parts[1]

    if not local or not domain:
        return None, None

    return local, domain


def is_valid_utpn_email(value: str | None) -> bool:
    email = normalize_email(value)

    if not email:
        return False

    if len(email) > EMAIL_MAX_LENGTH:
        return False

    local, domain = split_email(email)
    if local is None or domain is None:
        return False

    if domain != UTPN_DOMAIN:
        return False

    if local.startswith(".") or local.endswith(".") or ".." in local:
        return False

    if not LOCAL_PART_RE.fullmatch(local):
        return False

    return True


def normalize_utpn_email(value: str | None) -> str:
    email = normalize_email(value)
    if not is_valid_utpn_email(email):
        return ""
    return email


def normalize_and_validate_phone(value: str | None) -> tuple[str | None, str | None]:
    if value is None:
        return None, "El teléfono es obligatorio."

    normalized = unicodedata.normalize("NFKC", str(value)).strip()
    digits = re.sub(r"\D", "", normalized)

    if not digits:
        return None, "El teléfono debe contener números."

    if len(digits) < 10:
        return None, "El teléfono debe tener al menos 10 dígitos."

    if len(digits) > 15:
        return None, "El teléfono no puede exceder 15 dígitos."

    return digits, None


def normalize_and_validate_group_code(value: str | None) -> tuple[str | None, str | None]:
    if value is None:
        return None, None

    normalized = unicodedata.normalize("NFKC", str(value))
    normalized = re.sub(r"\s+", "", normalized).upper().strip()

    if not normalized:
        return None, None

    if len(normalized) > 20:
        return None, "El código de grupo no puede exceder 20 caracteres."

    return normalized, None