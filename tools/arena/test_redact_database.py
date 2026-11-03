import string
import unittest

from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

settings.register_profile("arena", deadline=None, suppress_health_check=[HealthCheck.too_slow])
settings.load_profile("arena")

from redact_database import EMAIL, redact

word = st.text(string.ascii_letters + string.digits, min_size=1, max_size=8)
emails = st.builds("{}@{}.{}".format, word, word, word)
around = st.text("\"\\ ,:{}[]", max_size=6)


class RedactTests(unittest.TestCase):
    def test_account_id_inside_escaped_json_is_redacted(self):
        line = '{"error":"auth file \\"claude-a1b2c3d4-someone@example.edu.json\\" refused"}'
        self.assertEqual(redact(line), '{"error":"auth file \\"[redacted]\\" refused"}')

    @given(around, emails, around)
    def test_an_email_is_replaced_and_its_surroundings_are_kept(self, before, email, after):
        self.assertEqual(redact(before + email + after), before + "[redacted]" + after)

    @given(st.text(string.printable))
    def test_no_email_survives_and_redacting_twice_changes_nothing(self, text):
        once = redact(text)
        self.assertIsNone(EMAIL.search(once))
        self.assertEqual(redact(once), once)

    @given(st.text(string.printable).filter(lambda text: "@" not in text))
    def test_text_without_an_at_sign_is_untouched(self, text):
        self.assertEqual(redact(text), text)


if __name__ == "__main__":
    unittest.main()
