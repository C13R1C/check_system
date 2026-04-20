import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from flask import Flask

from app.controllers.api_controller import api_bp


class RaBackendQrTests(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.app.config["TESTING"] = True
        self.app.register_blueprint(api_bp)
        self.client = self.app.test_client()

        self.current_user_patcher = patch("app.utils.security.current_user")
        self.rate_limit_patcher = patch("app.utils.security._rate_limit_exceeded", return_value=False)
        self.current_user_mock = self.current_user_patcher.start()
        self.rate_limit_patcher.start()
        self.current_user_mock.is_authenticated = True
        self.current_user_mock.id = 1

    def tearDown(self):
        self.current_user_patcher.stop()
        self.rate_limit_patcher.stop()

    @patch("app.controllers.api_controller.ra_material_to_dict", return_value={"id": 2, "name": "Osciloscopio"})
    @patch("app.controllers.api_controller._can_user_access_ra_material", return_value=(True, None))
    @patch("app.controllers.api_controller.Material")
    @patch("app.controllers.api_controller._resolve_ra_user")
    def test_get_material_from_qr_valid_format(self, resolve_user_mock, material_cls, _access_mock, _to_dict_mock):
        resolve_user_mock.return_value = (SimpleNamespace(email="student@utpn.edu.mx"), None)

        query = MagicMock()
        query.get.return_value = SimpleNamespace(id=2)
        material_cls.query = query

        response = self.client.get("/api/ra/materials?qr=material:2")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json().get("ok"))

    def test_get_material_from_qr_invalid_format(self):
        response = self.client.get("/api/ra/materials?qr=material:2:3")
        self.assertEqual(response.status_code, 400)
        self.assertIn("material_id inválido", response.get_json().get("error", ""))

    @patch("app.controllers.api_controller.Material")
    @patch("app.controllers.api_controller._resolve_ra_user")
    def test_get_material_from_qr_not_found(self, resolve_user_mock, material_cls):
        resolve_user_mock.return_value = (SimpleNamespace(email="student@utpn.edu.mx"), None)

        query = MagicMock()
        query.get.return_value = None
        material_cls.query = query

        response = self.client.get("/api/ra/materials?qr=/materials/999")

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.get_json(), {"error": "Material no encontrado"})

    @patch("app.controllers.api_controller._resolve_ra_user")
    def test_get_material_from_qr_permission_denied(self, resolve_user_mock):
        resolve_user_mock.return_value = (None, ({"error": "rol no autorizado para RA"}, 403))

        response = self.client.get("/api/ra/materials?qr=2")

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.get_json(), {"error": "rol no autorizado para RA"})

    @patch("app.controllers.api_controller.log_event")
    @patch("app.controllers.api_controller.db")
    @patch("app.controllers.api_controller._can_user_access_ra_material", return_value=(True, None))
    @patch("app.controllers.api_controller.Material")
    @patch("app.controllers.api_controller._resolve_ra_user")
    def test_ra_event_accepts_material_id_equals_format(self, resolve_user_mock, material_cls, _access_mock, db_mock, _log_mock):
        resolve_user_mock.return_value = (SimpleNamespace(id=1, email="student@utpn.edu.mx"), None)

        query = MagicMock()
        query.get.return_value = SimpleNamespace(id=2)
        material_cls.query = query

        response = self.client.post(
            "/api/ra/events",
            json={"event_type": "scan", "material_id": "material_id=2", "user_email": "student@utpn.edu.mx"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json().get("ok"), True)
        db_mock.session.commit.assert_called_once()


if __name__ == "__main__":
    unittest.main()
