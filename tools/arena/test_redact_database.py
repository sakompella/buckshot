import unittest

from redact_database import redact


class RedactTests(unittest.TestCase):
    def test_account_id_inside_escaped_json_is_redacted(self):
        line = '{"error":"auth file \\"claude-a1b2c3d4-someone@example.edu.json\\" refused"}'
        self.assertEqual(redact(line), '{"error":"auth file \\"[redacted]\\" refused"}')

    def test_plain_json_string_and_text_without_email_are_kept_apart(self):
        self.assertEqual(redact('{"a":"x.y@mail.example.com","b":"no at sign"}'), '{"a":"[redacted]","b":"no at sign"}')


if __name__ == "__main__":
    unittest.main()
