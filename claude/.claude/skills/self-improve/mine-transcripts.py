#!/usr/bin/env python3
"""Extract user-correction signals from Claude Code transcripts.

Prints JSON: one record per matched user prompt, with the preceding assistant
message as context, so the caller can judge what the correction was about.
"""

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

# Tool results carrying a user veto rather than an execution failure.
REJECT = re.compile(
    r"(user doesn'?t want to|user rejected|user declined|didn't want to take this action)",
    re.IGNORECASE,
)

# Injected wrappers, not things the user typed.
NOISE = re.compile(
    r"^\s*<(command-message|command-name|command-args|local-command|system-reminder|user-prompt-submit-hook)",
    re.IGNORECASE,
)


def text_of(msg):
    content = msg.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [
            b.get("text", "")
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        ]
        return "\n".join(parts)
    return ""


def describe(tool, inp):
    """One-line rendering of a tool call, enough to see what was being attempted."""
    if not isinstance(inp, dict):
        return tool
    for key in ("command", "file_path", "pattern", "query", "url", "prompt"):
        if key in inp:
            return f"{tool}: {' '.join(str(inp[key]).split())[:200]}"
    return tool


def scan(path):
    prev_assistant = ""
    pending = {}  # tool_use_id -> (name, rendered call)
    last_tool = None
    out, silent = [], []
    with path.open(errors="replace") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("isSidechain") or rec.get("isMeta"):
                continue
            kind = rec.get("type")
            if kind == "assistant":
                msg = rec.get("message", {})
                t = text_of(msg)
                if t:
                    prev_assistant = t
                for b in msg.get("content") or []:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        last_tool = (b.get("name", "?"), describe(b.get("name", "?"), b.get("input")))
                        pending[b.get("id")] = last_tool
                continue
            if kind != "user":
                continue
            msg = rec.get("message", {})
            common = {
                "project": path.parent.name,
                "timestamp": rec.get("timestamp", ""),
                "transcript": str(path),
            }

            # A vetoed tool call: the user said no without saying why.
            for b in msg.get("content") or []:
                if not isinstance(b, dict) or b.get("type") != "tool_result":
                    continue
                blob = json.dumps(b.get("content", ""))[:2000]
                if not REJECT.search(blob):
                    continue
                name, call = pending.get(b.get("tool_use_id"), ("?", "?"))
                silent.append(
                    {**common, "kind": "rejected", "tool": name, "call": call,
                     "assistant_before": prev_assistant[-500:]}
                )

            body = text_of(msg)
            # Tool results arrive as user records with no text; skip those and wrappers.
            if not body.strip() or NOISE.match(body):
                continue

            # An interrupt: what mattered is what was in flight, not the words.
            if "[Request interrupted by user" in body:
                name, call = last_tool or ("?", "?")
                silent.append(
                    {**common, "kind": "interrupt", "tool": name, "call": call,
                     "assistant_before": prev_assistant[-500:], "user_after": " ".join(body.split())[:300]}
                )

            hits = [label for pat, label in SIGNALS if pat.search(body[:1500])]
            if not hits:
                continue
            out.append(
                {
                    "signals": sorted(set(hits)),
                    "project": path.parent.name,
                    "cwd": rec.get("cwd", ""),
                    "timestamp": rec.get("timestamp", ""),
                    "transcript": str(path),
                    "user": body[:1200],
                    "assistant_before": prev_assistant[-800:],
                }
            )
    return out, silent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(pathlib.Path.home() / ".claude" / "projects"))
    ap.add_argument("--since", default="", help="ISO date lower bound, e.g. 2026-01-01")
    ap.add_argument(
        "--project", default="", help="substring filter on the project dir name"
    )
    ap.add_argument("--limit", type=int, default=400)
    args = ap.parse_args()

    files = sorted(pathlib.Path(args.root).rglob("*.jsonl"))
    if args.project:
        files = [f for f in files if args.project in f.parent.name]

    results, silent = [], []
    for f in files:
        hits, sig = scan(f)
        results.extend(hits)
        silent.extend(sig)

    if args.since:
        results = [r for r in results if r["timestamp"] >= args.since]
        silent = [r for r in silent if r["timestamp"] >= args.since]
    results.sort(key=lambda r: r["timestamp"], reverse=True)
    silent.sort(key=lambda r: r["timestamp"], reverse=True)

    counts = {}
    for r in results:
        for s in r["signals"]:
            counts[s] = counts.get(s, 0) + 1

    silent_counts = {}
    for r in silent:
        key = f"{r['kind']}:{r['tool']}"
        silent_counts[key] = silent_counts.get(key, 0) + 1

    json.dump(
        {
            "scanned_files": len(files),
            "total_hits": len(results),
            "signal_counts": dict(sorted(counts.items(), key=lambda kv: -kv[1])),
            "truncated_to": min(len(results), args.limit),
            "hits": results[: args.limit],
            "silent_counts": dict(sorted(silent_counts.items(), key=lambda kv: -kv[1])),
            "silent_signals": silent,
        },
        sys.stdout,
        indent=1,
    )


if __name__ == "__main__":
    main()
