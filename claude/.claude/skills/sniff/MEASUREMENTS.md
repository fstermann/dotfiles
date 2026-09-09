# sniff: measurements

Precision of the deterministic sniffers, hand-labeled. Deterministic-trigger precision is the
number that gates `hook_safe`, because the hook runs the pattern with no model to adjudicate.

## Run 1

- Date: 2026-09-09
- Corpus: 9 Markdown files in this dotfiles repo (README, CLAUDE.md, two output-styles, five skills).
- Method: ran every deterministic pattern with `grep -niE`, hand-labeled each hit CONFIRMED (a real
  smell in an instruction) or REJECTED, using the rule's "Not a finding when" clause.

| sniffer | hits | labeled | confirmed | precision | dominant reject reason |
|---|---|---|---|---|---|
| lex-loophole | 1 | 1 | 1 | 1.00 | — |
| lex-subjective | 2 | 2 | 0 | 0.00 | meta: banned-word list |
| lex-hedge-stack | 2 | 2 | 0 | 0.00 | meta / quoted example |
| lex-vague-quantifier | 1 | 1 | 0 | 0.00 | meta: word cited as example |
| lex-ambiguous-adverb | 2 | 2 | 0 | 0.00 | quoted example / not an instruction |
| lex-comparative | 5 | 5 | 0 | 0.00 | baseline present in context |
| ref-vague-pronoun | 6 | 6 | 0 | 0.00 | antecedent clear |
| log-leading-frame | 1 | 1 | 0 | 0.00 | quoted / not leading |
| log-negation-only | 40 | 16 | 0 | ~0.00 | specific prohibition or positive target present |
| log-universal-quantifier | 20 | 10 | 0 | ~0.00 | universal is enforceable |
| ref-passive-actor | 18 | 10 | 0 | ~0.00 | descriptive doc / quoted / actor clear |
| lex-open-ended | 0 | — | — | — | — |
| lex-superlative | 0 | — | — | — | — |
| lex-politeness-padding | 0 | — | — | — | — |
| ref-incomplete | 0 | — | — | — | — |
| ref-scope-ambiguity | 0 | — | — | — | — |

Total: 98 candidates, 56 labeled, **1 confirmed**.

## Reading

The number measures the corpus, not the rules. Two corpus properties dominate:

1. The docs are deliberately terse and edited to a house style, so they contain almost no real
   smells. One true finding is a clean-repo signal, not a rule failure.
2. Four of the nine files are writing-guidance docs. They cite smell words as examples, so the
   lexical sniffers fire on mentions, not uses. This is the docs-about-writing self-trip.

What is a rule signal: the broad `log-negation-only`, `log-universal-quantifier` and
`ref-passive-actor` triggers fire on many legitimate specific instructions. Even after a
code-fence/quote stripper removes the meta and quoted hits, these three stay low-precision as
deterministic signals. They are model-pass rules, not hook rules.

## Consequence

Deterministic-trigger precision on clean real docs is about 1% (1/98). No rule approaches a hook
bar. This confirms the design's prediction: nothing is `hook_safe`, and the model pass does the
real filtering.

To set a real per-sniffer bar, the next run needs a smell-dense corpus: draft prompts, specs or
PRDs before editing, not polished config. Recording per-sniffer precision into rule frontmatter is
deferred until such a corpus produces non-degenerate numbers; a 0.00 from this corpus would
misread as a bad rule.

## Run 2

- Date: 2026-09-09
- Corpus: assistant prose extracted from 3 real Claude Code session transcripts (non-private
  projects), 286 text blocks, ~91 KB. No writing-guidance docs, so words appear as uses, not
  citations. Genre is conversational explanation, not specs, which matters below.
- Method: as Run 1. Each hit labeled as if the line were instructional text (the fair test of the
  rule's discriminative power).

| sniffer | hits | labeled | confirmed | precision | note |
|---|---|---|---|---|---|
| lex-subjective | 4 | 4 | 4 | 1.00 | "elegant", "clean" as real adjectives |
| lex-open-ended | 1 | 1 | 1 | 1.00 | "etc." in an enumeration |
| lex-ambiguous-adverb | 1 | 1 | 1 | 1.00 | "commit it properly" |
| lex-superlative | 7 | 7 | 3 | 0.43 | borderline: "cleanest fix: <concrete X>" rejects |
| lex-comparative | 8 | 7 | 2 | ~0.25 | most have a baseline in context |
| ref-vague-pronoun | 9 | — | — | — | not relabeled; Run 1 showed clear antecedents |
| log-universal-quantifier | 16 | 12 | 0 | ~0.00 | universals are enforceable/actionable |
| log-negation-only | 26 | 15 | 0 | ~0.00 | descriptive "never/no" or positive target present |
| ref-passive-actor | 37 | 15 | 0 | ~0.00 | descriptive prose, not instructions; -ed slop |

Total: 109 candidates, ~62 labeled, **~11 confirmed** (all lexical).

## Reading, both runs

1. **Lexical wordlist rules discriminate on real prose.** `lex-subjective`, `lex-open-ended`,
   `lex-ambiguous-adverb` were 1.00 in Run 2. `lex-superlative` is borderline (a "cleanest fix: X"
   that then names X is not unbounded). `lex-comparative` is weak (context usually supplies a
   baseline). Run 1's zeros for these were the meta-mention artifact, not the rule.
2. **The three broad triggers are ~0% deterministic precision in both corpora.**
   `log-negation-only`, `log-universal-quantifier`, `ref-passive-actor` fire overwhelmingly on
   descriptive prose and specific, enforceable, actionable negations. This is robust across genres.
   They are model-pass rules and can never be hook rules.
   Action taken 2026-09-09: `log-negation-only`, `log-universal-quantifier` and
   `ref-passive-actor` had their deterministic sniffer removed and are now model-only.
   `lex-comparative` kept its trigger at `confidence: low`.
3. **Genre caveat.** `ref-passive-actor` and `ref-missing-actor` are spec smells. Conversational
   prose under-measures them, because a passive there is usually just description. Measuring them
   fairly needs a spec corpus (PURE, 79 real SRS docs, is the target for a future spec-pack run).

## Run 3

- Date: 2026-09-09
- Corpus: PURE dataset, XML subset. 18 public SRS documents, 2874 requirement sentences extracted
  from `<req>` and `<text_body>` elements. This is the `spec` genre the referential/logical rules
  target.
- Method: `./sniff.sh /tmp/pure_corpus.txt spec`, then hand-labeled a spread sample (~14 per rule)
  plus matched-span tallies. Removed patterns re-run manually to test spec-genre signal.

| sniffer | hits | sampled n | precision | verdict |
|---|---|---|---|---|
| lex-vague-quantifier | 58 | 14 | ~0.90 | strong on specs ("sufficient" x37) |
| lex-ambiguous-adverb | 41 | 14 | ~0.90 | strong (quickly, adequately, properly) |
| lex-open-ended | 84 | 10 | ~0.95 | strong ("etc." in a spec) |
| lex-loophole | 18 | — | ~0.90 | canonical spec loophole; n<25 |
| lex-subjective | 24 | 12 | ~0.85 | strong; occasional defined term ("flexible") |
| ref-scope-ambiguity | 57 | 10 | undetermined | needs full-context labeling |
| ref-vague-pronoun | 209 | 10 | ~low | expletive "It shall be possible" FPs; model filters |
| lex-comparative | 30 | — | undetermined | low confidence trigger |
| lex-superlative | 6 | — | — | n too small |
| ref-incomplete | 12 | — | — | n too small |
| ref-passive-actor (model-only) | 1511 raw | 15 | ~0.30 | more signal than conversation, still sub-hook |
| log-negation-only (model-only) | 55 | — | low | verdict unchanged |
| log-universal-quantifier (model-only) | 24 | — | low | verdict unchanged |

## Reading, Run 3

1. **On real specs the lexical rules discriminate well.** `lex-vague-quantifier`,
   `lex-ambiguous-adverb`, `lex-open-ended` sampled ~0.90 and have >= 25 available hits;
   `lex-loophole` ~0.90 but only 18 hits; `lex-subjective` ~0.85. These are the first rules to
   approach the hook precision bar. They are `warning` today, so the `spec` pack (which can promote
   to `error`) is the path to hook eligibility. Certifying the bar needs a full >= 25-label pass;
   Run 3 sampled ~14 each.
2. **Bug fixed.** `lex-open-ended`'s `\betc\.?` matched "ETCS" (European Train Control System),
   75 of 158 hits. Changed to `\betc\b` (158 -> 84). Found only because a spec corpus is dense in
   that acronym.
3. **`ref-passive-actor` has ~0.30 on specs**, up from ~0.00 on conversation. Real actor-eliding
   passives ("the train shall be supervised") mix with correct rejects ("... retained *by the
   radio*", actor named) and -ed adjectives. It stays model-only; a spec-pack deterministic trigger
   with a "not followed by 'by'" filter is the candidate to revisit, not built now.
4. **Trigger-tightening candidate (not applied):** `ref-vague-pronoun` fires on expletive
   "It shall be possible / It is assumed", pervasive in specs. The D+ model pass rejects these, so
   final precision holds; tighten only if the trigger volume becomes a problem.

## Run 4: certification pass

- Date: 2026-09-09
- Corpus: PURE (same as Run 3). Each candidate hit centered on its matched span so no match hides
  in a long requirement line, then labeled to n >= 25 where the hit count allowed.

| rule | precision | n | verdict |
|---|---|---|---|
| lex-ambiguous-adverb | ~1.00 | 30 | certified: hook_safe true |
| lex-open-ended | ~1.00 | 30 | certified: hook_safe true |
| lex-vague-quantifier | ~0.95 | 30 | certified: hook_safe true |
| lex-loophole | ~0.95 | 19 | precision qualifies, n < 25; not promoted |
| lex-subjective | 0.76 | 29 | fails the 0.90 bar; not promoted |

`lex-subjective`'s misses were all context, not the wordlist: "flexible scheduling" as a defined
term, "Flexible" inside the proper noun FITS, and "State of the Art" in citation titles. Dropping
"flexible" or excluding title/proper-noun context would likely lift it over the bar; deferred.

Frontmatter now carries `precision` and `n` on these five sniffers, and `hook_safe: true` on the
three certified.

## hook_safe bar (refined)

`hook_safe` is the **precision gate**: a deterministic sniffer earns it at precision >= 0.90 on
>= 25 hand-labeled hits. It is separate from importance. When the hook runs a `hook_safe` rule,
`severity` decides the action: `error` blocks the commit, `warning` only warns. The three certified
rules are `hook_safe: true` at `severity: warning`, so a hook would warn on them, not block, until
someone deliberately promotes them to `error` (the `spec` pack is the place to do that).

Note: this refines the earlier bar, which folded `severity: error` into the gate. Precision and
importance are separate decisions; conflating them would have blocked commits on a warning-level
smell just because its pattern is precise.
