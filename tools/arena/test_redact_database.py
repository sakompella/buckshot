import os
import sqlite3
import string
import tempfile
import unittest

from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

settings.register_profile("arena", deadline=None, suppress_health_check=[HealthCheck.too_slow])
settings.load_profile("arena")

from redact_database import EMAIL, main, redact

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

    def test_a_committed_email_in_any_text_column_is_redacted_while_it_is_still_in_the_wal(self):
        d = tempfile.mkdtemp()
        source = sqlite3.connect(os.path.join(d, "src.sqlite"))
        source.execute("PRAGMA journal_mode = WAL")
        source.execute("PRAGMA wal_autocheckpoint = 0")
        source.execute("CREATE TABLE match_seats (provenance_json TEXT)")
        source.execute("CREATE TABLE calls (response_text TEXT)")
        source.execute("INSERT INTO calls VALUES ('mail someone@example.com')")
        source.commit()
        main(os.path.join(d, "src.sqlite"), os.path.join(d, "out.sqlite"))
        source.close()
        out = sqlite3.connect(os.path.join(d, "out.sqlite"))
        self.assertEqual(out.execute("SELECT response_text FROM calls").fetchall(), [("mail [redacted]",)])


if __name__ == "__main__":
    unittest.main()
