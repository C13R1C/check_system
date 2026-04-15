from datetime import datetime

from app.services.reservation_service import expire_unapproved_reservations


def test_expire_unapproved_reservations_is_disabled_and_returns_zero():
    now = datetime(2026, 4, 12, 7, 0, 0)
    assert expire_unapproved_reservations(now_dt=now) == 0


def test_expire_unapproved_reservations_accepts_missing_now_arg():
    assert expire_unapproved_reservations() == 0
