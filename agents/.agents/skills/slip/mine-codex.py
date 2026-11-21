#!/usr/bin/env python3
"""Extract user-correction signals from Codex transcripts.

Prints JSON: one record per matched user prompt, with the preceding assistant
message as context, so the caller can judge what the correction was about.
"""

import os
import argparse
import json
import pathlib
import re
import sys

# Phrases where the user is redirecting, correcting, or restating a preference.
SIGNALS = [
    (r"\b(no|nope|nah)\b[,.! ]", "rejection"),
    (
        r"\b(don'?t|do not|stop|never)\s+(do|use|add|write|create|change|touch|make|assume)",
        "prohibition",
    ),
    (
        r"\b(i (already )?(told|said)|as i said|like i said|again[,:]|i asked for)\b",
        "repeat",
    ),
    (
        r"\b(that'?s (not|wrong)|not what i|incorrect|you (misunderstood|missed))\b",
        "misunderstanding",
    ),
    (
        r"\b(always|from now on|going forward|in future|every time|by default)\b",
        "standing-rule",
    ),
    (
        r"\b(too (verbose|long|complex|much)|over-?engineer|simplify|shorter|keep it simple)\b",
        "over-engineering",
    ),
    (
        r"\b(why (did|are) you|who (asked|told you))\b",
        "frustration",
    ),
    (
        r"^\s*(actually|wait|hold on|hmm)\b",
        "course-correction",
    ),
    (
        r"\[Request interrupted by user",
        "interrupt",
    ),
]
SIGNALS = [(re.compile(p, re.IGNORECASE), label) for p, label in SIGNALS]

# These records are supplied by the host rather than typed by the user.
NOISE = re.compile(
    r"^\s*(<(environment_context|permissions instructions|collaboration_mode|turn_aborted|system-reminder)\b|# (AGENTS\.md instructions|Instructions for))",
    re.IGNORECASE,
)


def scan(path):
    previous = ""
    cwd = ""
    hits = []
    with path.open(errors="replace") as stream:
        for line in stream:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            payload = record.get("payload", {})
            if not isinstance(payload, dict):
                continue
            if record.get("type") == "session_meta":
                cwd = payload.get("cwd", "")
                continue
            if record.get("type") != "response_item" or payload.get("type") != "message":
                continue
            body = "\n".join(
                item.get("text", "") for item in payload.get("content", [])
                if isinstance(item, dict) and item.get("type") in ("input_text", "output_text", "text")
                and not NOISE.match(item.get("text", ""))
            )
            if payload.get("role") == "assistant":
                if body.strip():
                    previous = body
                continue
            if payload.get("role") != "user" or not body.strip():
                continue
            signals = sorted({label for pattern, label in SIGNALS if pattern.search(body[:1500])})
            if signals:
                hits.append({
                    "signals": signals, "cwd": cwd, "timestamp": record.get("timestamp", ""),
                    "transcript": str(path), "user": body[:1200], "assistant_before": previous[-800:],
                })
    return hits


def main():
    parser = argparse.ArgumentParser()
    home = pathlib.Path(os.environ.get("CODEX_HOME") or pathlib.Path.home() / ".codex")
    parser.add_argument("--root", default=str(home / "sessions"))
    parser.add_argument("--since", default="")
    parser.add_argument("--project", default="", help="Substring filter on session cwd")
    parser.add_argument("--limit", type=int, default=400)
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")
    root = pathlib.Path(args.root).expanduser()
    if not root.is_dir():
        parser.error(f"Transcript directory does not exist: {root}")
    files = sorted(root.rglob("rollout-*.jsonl"))
    hits = [hit for path in files for hit in scan(path)
            if hit["timestamp"] >= args.since and args.project in hit["cwd"]]
    hits.sort(key=lambda hit: hit["timestamp"], reverse=True)
    counts = {}
    for hit in hits:
        for signal in hit["signals"]:
            counts[signal] = counts.get(signal, 0) + 1
    json.dump({"scanned_files": len(files), "total_hits": len(hits),
               "signal_counts": dict(sorted(counts.items(), key=lambda item: -item[1])),
               "truncated_to": min(len(hits), args.limit), "hits": hits[:args.limit]}, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
