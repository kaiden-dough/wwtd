import io
import json
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.db import Base
from app.models import Profile
from app.config import settings
from app.supabase_auth import google_profile, link_google


class GoogleAuthTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.user = {"id": "12345678-1234-1234-1234-123456789012",
            "email": "player@example.com", "email_confirmed_at": "2026-01-01",
            "identities": [{"provider": "google"}]}
        self.config = patch.multiple(settings, supabase_url="https://example.supabase.co",
            supabase_publishable_key="public-key")
        self.config.start()

    def tearDown(self):
        self.config.stop()
        self.db.close()
        self.engine.dispose()

    def verify(self):
        with patch("app.supabase_auth.urlopen", return_value=io.BytesIO(json.dumps(self.user).encode())):
            return google_profile("token", self.db)

    def test_provisions_once(self):
        first = self.verify()
        self.assertEqual(first.id, self.user["id"])
        self.assertEqual(self.verify().id, first.id)
        self.assertEqual(self.db.query(Profile).count(), 1)

    def test_email_collision_preserves_existing_account(self):
        self.db.add(Profile(id="legacy", email=self.user["email"], balance_points=42))
        self.db.commit()
        with self.assertRaises(HTTPException) as caught:
            self.verify()
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(self.db.get(Profile, "legacy").balance_points, 42)

    def test_requires_google_and_verified_email(self):
        for field, value, code in [("email_confirmed_at", None, 401), ("identities", [], 403)]:
            original = self.user[field]
            self.user[field] = value
            with self.assertRaises(HTTPException) as caught:
                self.verify()
            self.assertEqual(caught.exception.status_code, code)
            self.user[field] = original

    def test_link_preserves_profile_and_balance(self):
        profile = Profile(id="legacy", username="player", balance_points=42)
        self.db.add(profile)
        self.db.commit()
        with patch("app.supabase_auth.verify_google_session", return_value=self.user):
            linked = link_google("google-token", profile, self.db)
        self.assertEqual(linked.id, "legacy")
        self.assertEqual(self.verify().id, "legacy")
        self.assertEqual(self.verify().balance_points, 42)

    def test_cannot_link_another_players_google_account(self):
        self.verify()
        profile = Profile(id="legacy", username="other", balance_points=42)
        self.db.add(profile)
        self.db.commit()
        with patch("app.supabase_auth.verify_google_session", return_value=self.user):
            with self.assertRaises(HTTPException) as caught:
                link_google("google-token", profile, self.db)
        self.assertEqual(caught.exception.status_code, 409)

    def test_invalid_session(self):
        with patch("app.supabase_auth.urlopen", side_effect=HTTPError("url", 401, "expired", {}, None)):
            with self.assertRaises(HTTPException) as caught:
                google_profile("expired", self.db)
        self.assertEqual(caught.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
