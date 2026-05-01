#!/usr/bin/env python3
"""Tiny stub of Anthropic's messages API for the demo recording.

Streams a fixed assistant reply and sets the rate-limit response headers
that Claude Code reads to populate the statusline. No external deps.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import sys
import time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787


def rate_headers():
    now = int(time.time())
    return {
        # Per-window rate limits — values pick up in the statusline pills.
        "anthropic-ratelimit-unified-5h-status": "allowed",
        "anthropic-ratelimit-unified-5h": "64",
        "anthropic-ratelimit-unified-5h-reset": str(now + 14400),    # 4h left
        "anthropic-ratelimit-unified-7d-status": "allowed",
        "anthropic-ratelimit-unified-7d": "26",
        "anthropic-ratelimit-unified-7d-reset": str(now + 172800),   # 2d left
        # Token window (used for context-percent pill).
        "anthropic-ratelimit-tokens-limit": "1000000",
        "anthropic-ratelimit-tokens-remaining": "970000",
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_a, **_kw):
        pass

    def _send_headers(self, status=200, content_type="application/json"):
        self.send_response(status)
        for k, v in rate_headers().items():
            self.send_header(k, v)
        self.send_header("content-type", content_type)
        self.end_headers()

    def _json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        for k, v in rate_headers().items():
            self.send_header(k, v)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _stream(self):
        events = [
            ("message_start", {
                "type": "message_start",
                "message": {
                    "id": "msg_demo",
                    "type": "message",
                    "role": "assistant",
                    "model": "claude-opus-4-7-20251201",
                    "content": [],
                    "stop_reason": None,
                    "stop_sequence": None,
                    "usage": {
                        "input_tokens": 12,
                        "output_tokens": 0,
                        "cache_creation_input_tokens": 0,
                        "cache_read_input_tokens": 0,
                    },
                },
            }),
            ("content_block_start", {
                "type": "content_block_start", "index": 0,
                "content_block": {"type": "text", "text": ""},
            }),
            ("content_block_delta", {
                "type": "content_block_delta", "index": 0,
                "delta": {"type": "text_delta", "text": "Hi! "},
            }),
            ("content_block_delta", {
                "type": "content_block_delta", "index": 0,
                "delta": {"type": "text_delta", "text": "This is a local demo."},
            }),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {
                "type": "message_delta",
                "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                "usage": {"output_tokens": 8},
            }),
            ("message_stop", {"type": "message_stop"}),
        ]
        self._send_headers(content_type="text/event-stream")
        for ev, data in events:
            try:
                self.wfile.write(f"event: {ev}\ndata: {json.dumps(data)}\n\n".encode())
                self.wfile.flush()
            except BrokenPipeError:
                return
            time.sleep(0.04)

    def do_POST(self):
        length = int(self.headers.get("content-length", 0) or 0)
        if length:
            self.rfile.read(length)
        if self.path.endswith("/count_tokens"):
            self._json({"input_tokens": 12})
        elif "/v1/messages" in self.path:
            self._stream()
        else:
            self._json({"ok": True})

    def do_GET(self):
        self._json({"ok": True})


if __name__ == "__main__":
    print(f"mock anthropic listening on http://127.0.0.1:{PORT}", file=sys.stderr)
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
