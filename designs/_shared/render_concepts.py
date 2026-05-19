#!/usr/bin/env python3
"""Render each design folder's three Concept artboards to PNG via Playwright + system Chrome.

Serves the designs/ directory over a local HTTP server because the React+Babel pages
use XMLHttpRequest to fetch the .jsx files, which Chrome blocks under file:// (CORS).
"""
import os
import socket
import sys
import threading
import urllib.parse
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler

from playwright.sync_api import sync_playwright

DESIGNS = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FOLDERS = ["Settings", "Folding", "SyntaxHighlighting", "Completion",
           "LSP", "SmartEditing", "Annotations"]
CONCEPTS = ["a", "b", "c"]
LABELS = {"a": "Concept A", "b": "Concept B", "c": "Concept C"}


def find_html(folder_path: str) -> str:
    for name in os.listdir(folder_path):
        if name.lower().endswith(".html"):
            return name
    raise FileNotFoundError(f"No .html in {folder_path}")


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args, **_kwargs):  # silence access log
        pass


def start_server() -> tuple[HTTPServer, int]:
    handler = partial(QuietHandler, directory=DESIGNS)
    # Bind to ephemeral port to avoid clashing with anything else.
    httpd = HTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd, httpd.server_address[1]


def render():
    httpd, port = start_server()
    base = f"http://127.0.0.1:{port}"
    print(f"serving {DESIGNS} at {base}", flush=True)
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(channel="chrome", headless=True)
            ctx = browser.new_context(
                viewport={"width": 1800, "height": 1400},
                device_scale_factor=2,
            )
            for folder in FOLDERS:
                folder_path = os.path.join(DESIGNS, folder)
                html_name = find_html(folder_path)
                url = f"{base}/{urllib.parse.quote(folder)}/{urllib.parse.quote(html_name)}"
                print(f"→ {folder}/{html_name}", flush=True)

                page = ctx.new_page()
                page.on("pageerror", lambda exc: print(f"    [pageerror] {exc}", flush=True))
                page.goto(url, wait_until="load")
                page.wait_for_function(
                    "document.querySelectorAll('[data-dc-slot] .dc-card').length >= 3",
                    timeout=60_000,
                )
                page.evaluate(
                    "async () => { try { await document.fonts.ready; } catch (e) {} }"
                )
                page.wait_for_timeout(800)  # settle async art (icons, layout)

                for cid in CONCEPTS:
                    el = page.locator(f'[data-dc-slot="{cid}"] .dc-card')
                    el.wait_for(state="visible", timeout=15_000)
                    out = os.path.join(folder_path, f"{LABELS[cid]}.png")
                    el.screenshot(path=out)
                    size = os.path.getsize(out)
                    print(f"    {LABELS[cid]}.png  ({size//1024} KB)", flush=True)

                page.close()
            browser.close()
    finally:
        httpd.shutdown()


if __name__ == "__main__":
    try:
        render()
    except Exception as e:
        print(f"FAILED: {e}", file=sys.stderr)
        sys.exit(1)
