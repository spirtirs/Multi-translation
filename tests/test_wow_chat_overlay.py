import unittest
from unittest.mock import patch
from urllib.parse import parse_qs

from Bridge.wow_chat_overlay import DeepLClient, parse_chat_line


class ParseChatLineTests(unittest.TestCase):
    def test_extracts_message_from_wow_chat_log(self):
        self.assertEqual(
            parse_chat_line("11/12 17:49:39.052  [Guild] Player-Realm: Привет"),
            "Привет",
        )

    def test_removes_wow_links_and_color_codes(self):
        line = (
            "11/12 17:49:39.052  [Say] Player: "
            "|cffffffff|Hitem:123|h[Sword]|h|r"
        )
        self.assertEqual(parse_chat_line(line), "[Sword]")

    def test_ignores_non_chat_lines(self):
        self.assertIsNone(parse_chat_line("11/12 17:49:39.052  You leave the group."))
        self.assertIsNone(parse_chat_line(""))


class DeepLClientTests(unittest.TestCase):
    def test_selects_free_endpoint_for_free_auth_key(self):
        self.assertEqual(
            DeepLClient("test-key:fx").endpoint,
            "https://api-free.deepl.com/v2/translate",
        )

    def test_selects_pro_endpoint_for_other_auth_key(self):
        self.assertEqual(
            DeepLClient("test-key").endpoint,
            "https://api.deepl.com/v2/translate",
        )

    @patch("Bridge.wow_chat_overlay.urlopen")
    def test_sends_text_and_target_language(self, urlopen):
        response = unittest.mock.MagicMock()
        response.__enter__.return_value.read.return_value = (
            b'{"translations":[{"text":"Hello"}]}'
        )
        urlopen.return_value = response

        translated = DeepLClient("test-key:fx").translate("Hola", "EN-US")

        self.assertEqual(translated, "Hello")
        request = urlopen.call_args.args[0]
        self.assertEqual(
            parse_qs(request.data.decode("utf-8")),
            {"text": ["Hola"], "target_lang": ["EN-US"]},
        )
        self.assertEqual(
            request.get_header("Authorization"),
            "DeepL-Auth-Key test-key:fx",
        )


if __name__ == "__main__":
    unittest.main()
