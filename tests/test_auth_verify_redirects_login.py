import unittest
from unittest.mock import MagicMock, patch

from flask import Flask

from app.controllers.auth_controller import auth_bp
from app.extensions import login_manager


class VerifyRedirectTests(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.app.config["SECRET_KEY"] = "test-secret"
        self.app.config["TESTING"] = True
        login_manager.init_app(self.app)

        @login_manager.user_loader
        def _load_user(_user_id):
            return None

        self.app.register_blueprint(auth_bp)
        self.client = self.app.test_client()

    def _assert_redirect_to_login_and_flash(self, response, expected_message: str):
        self.assertEqual(response.status_code, 302)
        self.assertIn("/auth/?mode=login", response.location)
        with self.client.session_transaction() as sess:
            flashes = sess.get("_flashes", [])
        messages = [msg for _cat, msg in flashes]
        self.assertIn(expected_message, messages)

    @patch("app.controllers.auth_controller._clear_pending_verify_session")
    @patch("app.controllers.auth_controller.db")
    @patch("app.controllers.auth_controller.User")
    @patch("app.controllers.auth_controller.confirm_verify_token")
    def test_valid_token_verifies_and_redirects_to_login(self, confirm_mock, user_cls, db_mock, clear_mock):
        confirm_mock.return_value = {"email": "profe@utpn.edu.mx", "token_version": 2}

        user = MagicMock()
        user.is_verified = False
        user.verify_token_version = 2

        query = MagicMock()
        query.first.return_value = user
        user_cls.query.filter_by.return_value = query

        response = self.client.get("/auth/verify/ok-token", follow_redirects=False)

        self._assert_redirect_to_login_and_flash(response, "Correo verificado. Ya puedes iniciar sesión.")
        db_mock.session.commit.assert_called_once()
        clear_mock.assert_called_once()

    @patch("app.controllers.auth_controller.peek_verify_token", return_value={"email": "x@utpn.edu.mx", "token_version": 1})
    @patch("app.controllers.auth_controller.confirm_verify_token", return_value=None)
    def test_expired_token_redirects_to_login(self, _confirm_mock, _peek_mock):
        response = self.client.get("/auth/verify/expired-token", follow_redirects=False)
        self._assert_redirect_to_login_and_flash(response, "El enlace de verificación expiró. Solicita uno nuevo.")

    @patch("app.controllers.auth_controller.peek_verify_token", return_value=None)
    @patch("app.controllers.auth_controller.confirm_verify_token", return_value=None)
    def test_invalid_token_redirects_to_login(self, _confirm_mock, _peek_mock):
        response = self.client.get("/auth/verify/invalid-token", follow_redirects=False)
        self._assert_redirect_to_login_and_flash(response, "El enlace de verificación no es válido.")

    @patch("app.controllers.auth_controller._clear_pending_verify_session")
    @patch("app.controllers.auth_controller.db")
    @patch("app.controllers.auth_controller.User")
    @patch("app.controllers.auth_controller.confirm_verify_token")
    def test_already_verified_redirects_to_login(self, confirm_mock, user_cls, db_mock, clear_mock):
        confirm_mock.return_value = {"email": "staff@utpn.edu.mx", "token_version": 5}

        user = MagicMock()
        user.is_verified = True
        user.verify_token_version = 5

        query = MagicMock()
        query.first.return_value = user
        user_cls.query.filter_by.return_value = query

        response = self.client.get("/auth/verify/already-token", follow_redirects=False)

        self._assert_redirect_to_login_and_flash(response, "Tu correo ya estaba verificado. Inicia sesión.")
        db_mock.session.commit.assert_not_called()
        clear_mock.assert_called_once()


if __name__ == "__main__":
    unittest.main()
