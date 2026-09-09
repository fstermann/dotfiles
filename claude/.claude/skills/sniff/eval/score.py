#!/usr/bin/env python3
"""Score M6 eval outputs. Objective metrics only, no model grader.

Input: outputs.jsonl, one line per sample: {id, smell, variant, text}
  variant is "smelly" or "fixed".

Metrics:
  log-negation-only:  length control = stdev of word count per variant.
                      keep the rule if fixed cuts stdev by >= 20%.
  log-contradiction:  sentences per output and hit rate against intended length (3).
                      keep the rule if fixed raises hit rate by >= 20 points.
"""
import sys, json, re, statistics
from collections import defaultdict

def words(t): return len(re.findall(r"\S+", t))
def sentences(t): return max(1, len(re.findall(r"[.!?](?:\s|$)", t.strip())))

def main(path):
    by = defaultdict(lambda: defaultdict(list))  # smell -> variant -> [text]
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            o = json.loads(line)
            by[o["smell"]][o["variant"]].append(o["text"])

    for smell in sorted(by):
        sm, fx = by[smell].get("smelly", []), by[smell].get("fixed", [])
        print(f"\n== {smell} ==  n(smelly)={len(sm)} n(fixed)={len(fx)}")
        if not sm or not fx:
            print("  incomplete: need both variants"); continue

        if smell == "log-negation-only":
            s_sd = statistics.pstdev([words(t) for t in sm]) if len(sm) > 1 else 0.0
            f_sd = statistics.pstdev([words(t) for t in fx]) if len(fx) > 1 else 0.0
            drop = (s_sd - f_sd) / s_sd * 100 if s_sd else 0.0
            print(f"  word-count stdev: smelly={s_sd:.1f}  fixed={f_sd:.1f}  reduction={drop:.0f}%")
            keep = drop >= 20
            print(f"  verdict: {'KEEP (smell moves the outcome)' if keep else 'DEMOTE to suggestion (null)'}")

        elif smell == "log-contradiction":
            target = 3
            def hit(ts): return 100 * sum(sentences(t) == target for t in ts) / len(ts)
            s_hit, f_hit = hit(sm), hit(fx)
            s_mean = statistics.mean([sentences(t) for t in sm])
            f_mean = statistics.mean([sentences(t) for t in fx])
            print(f"  sentences (mean): smelly={s_mean:.1f}  fixed={f_mean:.1f}  (target {target})")
            print(f"  hit rate @ {target}: smelly={s_hit:.0f}%  fixed={f_hit:.0f}%  gain={f_hit-s_hit:.0f}pts")
            keep = (f_hit - s_hit) >= 20
            print(f"  verdict: {'KEEP (smell moves the outcome)' if keep else 'DEMOTE to suggestion (null)'}")
        else:
            print("  no metric defined for this smell")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: score.py outputs.jsonl")
    main(sys.argv[1])
