"""Read the WoW chat log and show DeepL translations in a separate overlay."""

from __future__ import annotations

import json
import os
import queue
import re
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, ttk
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


TIMESTAMP_RE = re.compile(r"^\d{1,2}/\d{1,2}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?\s+")
WOW_LINK_RE = re.compile(r"\|H[^|]*\|h(.*?)\|h")
WOW_COLOR_RE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r")
TARGET_LANGUAGES = {
    "English": "EN-US",
    "Russian": "RU",
    "Chinese": "ZH",
    "Korean": "KO",
    "Spanish": "ES",
}


def parse_chat_line(line: str) -> str | None:
    """Return the message part of a standard WoWChatLog line, if present."""
    body = TIMESTAMP_RE.sub("", line.strip(), count=1)
    if not body:
        return None

    separator = body.find(": ")
    if separator < 1:
        return None

    message = body[separator + 2 :].strip()
    message = WOW_LINK_RE.sub(r"\1", message)
    message = WOW_COLOR_RE.sub("", message)
    return message or None


class DeepLClient:
    def __init__(self, auth_key: str) -> None:
        if not auth_key:
            raise ValueError("Set DEEPL_AUTH_KEY before starting the overlay.")
        self.auth_key = auth_key
        self.endpoint = (
            "https://api-free.deepl.com/v2/translate"
            if auth_key.endswith(":fx")
            else "https://api.deepl.com/v2/translate"
        )

    def translate(self, text: str, target_lang: str) -> str:
        payload = urlencode({"text": text, "target_lang": target_lang}).encode("utf-8")
        request = Request(
            self.endpoint,
            data=payload,
            headers={
                "Authorization": "DeepL-Auth-Key " + self.auth_key,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=15) as response:
                data = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            raise RuntimeError(f"DeepL returned HTTP {error.code}.") from None
        except URLError as error:
            raise RuntimeError(f"Could not reach DeepL: {error.reason}") from None
        except TimeoutError:
            raise RuntimeError("The request to DeepL timed out.") from None
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise RuntimeError("DeepL returned an invalid response.") from None

        if not isinstance(data, dict):
            raise RuntimeError("DeepL returned an invalid response.")
        translations = data.get("translations")
        if not isinstance(translations, list) or not translations:
            raise RuntimeError("DeepL returned no translation.")
        if not isinstance(translations[0], dict):
            raise RuntimeError("DeepL returned an invalid translation.")
        translated = translations[0].get("text")
        if not isinstance(translated, str) or not translated:
            raise RuntimeError("DeepL returned an empty translation.")
        return translated


class ChatOverlay:
    def __init__(self, root: tk.Tk, log_path: str | None = None) -> None:
        self.root = root
        self.root.title("WoW Chat Translator")
        self.root.geometry("560x420")
        self.root.attributes("-topmost", True)

        self.result_queue: queue.Queue[tuple[str, str, str]] = queue.Queue()
        self.messages: queue.Queue[tuple[str, str]] = queue.Queue()
        self.log_file = None
        self.log_path = tk.StringVar(value=log_path or "")
        self.target_name = tk.StringVar(value="Russian")
        self.status = tk.StringVar(value="Choose WoWChatLog.txt and start watching.")
        self.client = None

        try:
            self.client = DeepLClient(os.environ.get("DEEPL_AUTH_KEY", "").strip())
            self.status.set("Ready. New chat lines will be sent to DeepL.")
        except ValueError as error:
            self.status.set(str(error))

        self._build_ui()
        threading.Thread(target=self._translation_worker, daemon=True).start()
        self.root.after(100, self._drain_results)

    def _build_ui(self) -> None:
        controls = ttk.Frame(self.root, padding=8)
        controls.pack(fill="x")

        ttk.Label(controls, text="Chat log:").grid(row=0, column=0, sticky="w")
        ttk.Entry(controls, textvariable=self.log_path).grid(
            row=0, column=1, sticky="ew", padx=6
        )
        ttk.Button(controls, text="Browse…", command=self._browse).grid(row=0, column=2)

        ttk.Label(controls, text="Translate to:").grid(
            row=1, column=0, sticky="w", pady=(8, 0)
        )
        ttk.Combobox(
            controls,
            textvariable=self.target_name,
            values=tuple(TARGET_LANGUAGES),
            state="readonly",
            width=14,
        ).grid(row=1, column=1, sticky="w", padx=6, pady=(8, 0))
        self.watch_button = ttk.Button(
            controls, text="Start watching", command=self._start_watching
        )
        self.watch_button.grid(row=1, column=2, pady=(8, 0))
        controls.columnconfigure(1, weight=1)

        self.output = tk.Text(self.root, wrap="word", state="disabled", padx=8, pady=8)
        self.output.pack(fill="both", expand=True, padx=8)
        ttk.Label(self.root, textvariable=self.status, padding=(8, 5)).pack(fill="x")

    def _browse(self) -> None:
        selected = filedialog.askopenfilename(
            title="Select WoWChatLog.txt",
            filetypes=(("WoW chat log", "WoWChatLog.txt"), ("Text files", "*.txt")),
        )
        if selected:
            self.log_path.set(selected)

    def _start_watching(self) -> None:
        if not self.client:
            self.status.set("Set DEEPL_AUTH_KEY, then restart the overlay.")
            return
        path = Path(self.log_path.get()).expanduser()
        try:
            file = path.open("r", encoding="utf-8", errors="replace")
            file.seek(0, os.SEEK_END)
        except OSError as error:
            self.status.set(f"Cannot open chat log: {error}")
            return

        if self.log_file:
            self.log_file.close()
        self.log_file = file
        self.watch_button.configure(text="Watching", state="disabled")
        self.status.set(f"Watching {path}. Only new chat lines are translated.")
        self.root.after(250, self._read_log)

    def _read_log(self) -> None:
        if not self.log_file:
            return
        try:
            line = self.log_file.readline()
            while line:
                message = parse_chat_line(line)
                if message:
                    self.messages.put((message, TARGET_LANGUAGES[self.target_name.get()]))
                line = self.log_file.readline()
        except OSError as error:
            self.status.set(f"Cannot read chat log: {error}")
        self.root.after(250, self._read_log)

    def _translation_worker(self) -> None:
        while True:
            item = self.messages.get()
            if self.client is None:
                self.result_queue.put(("", "", "DeepL is not configured."))
                continue
            text, target_lang = item
            try:
                translated = self.client.translate(text, target_lang)
                self.result_queue.put((text, translated, ""))
            except RuntimeError as error:
                self.result_queue.put((text, "", str(error)))

    def _drain_results(self) -> None:
        while True:
            try:
                result = self.result_queue.get_nowait()
            except queue.Empty:
                break
            original, translated, error = result
            if error:
                self.status.set(error)
            else:
                self.output.configure(state="normal")
                self.output.insert(
                    "end",
                    f"{original}\n→ {translated}\n\n",
                )
                self.output.see("end")
                self.output.configure(state="disabled")
                self.status.set("Translation received from DeepL.")
        self.root.after(100, self._drain_results)

    def close(self) -> None:
        if self.log_file:
            self.log_file.close()
        self.root.destroy()


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", help="Path to WoWChatLog.txt")
    args = parser.parse_args()

    root = tk.Tk()
    app = ChatOverlay(root, args.log)
    root.protocol("WM_DELETE_WINDOW", app.close)
    root.mainloop()


if __name__ == "__main__":
    main()
