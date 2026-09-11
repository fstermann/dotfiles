# Deterministic detector measurements

This file records the evidence behind `precision`, `n`, and `hook_safe` values in rule
frontmatter. It belongs in the repository because those values affect whether a deterministic
finding is safe to surface without LLM adjudication.

## Certification policy

A deterministic sniffer is `hook_safe` when it reaches at least 0.90 precision over at least 25
hand-labelled candidates. Precision and severity are separate: certification establishes detector
reliability, while configured severity determines whether a finding warns or blocks.

Existing certifications must not change without recording a new measurement here.

## Certification run

- Date: 2026-09-09
- Corpus: 2,874 requirement sentences from 18 public SRS documents in the PURE XML dataset
- Method: center each candidate on its matched span and hand-label at least 25 hits when enough
  candidates exist

| Rule | Precision | n | Result |
|---|---:|---:|---|
| `lex-ambiguous-adverb` | ~1.00 | 30 | certified |
| `lex-open-ended` | ~1.00 | 30 | certified |
| `lex-vague-quantifier` | ~0.95 | 30 | certified |
| `lex-loophole` | ~0.95 | 19 | insufficient sample |
| `lex-subjective` | 0.76 | 29 | below threshold |

`lex-subjective` false positives were contextual: defined terms, proper nouns, and citation titles.
`lex-loophole` met the precision threshold but did not have the required sample size.

## Exploratory findings

Earlier measurements used nine polished Markdown files from this repository and approximately
91 KB of assistant prose from three non-private Claude Code sessions. Those corpora showed:

- lexical detectors can discriminate well on ordinary prose, but documentation about writing
  creates many mention-versus-use false positives;
- broad patterns for `log-negation-only`, `log-universal-quantifier`, and `ref-passive-actor`
  produced near-zero precision outside LLM adjudication, so those rules became model-only;
- `ref-passive-actor` improved to roughly 0.30 precision on the PURE specification corpus, which
  was still too low for deterministic use;
- the original `lex-open-ended` pattern matched the ETCS acronym, leading to the narrower
  `\betc\b` pattern.

These exploratory runs are not certifications. Re-run certification against an appropriate,
smell-dense corpus before changing any `hook_safe` value.
