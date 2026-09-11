# sniff: M6 eval

The milestone that shows the tool matters. For one smell class, take matched prompt pairs that
differ only in the smell, run both through a model, and measure an objective downstream outcome.
A rule whose smell moves no outcome gets demoted to `suggestion`.

Status: not executed in the authoring session. Live model calls were blocked there. The scorer is
verified on sample data; run `run.sh` where the Messages API is reachable, then `score.py`.

## Design

Matched pairs hold the task and the target constant and vary only the smell, so any outcome
difference is attributable to the smell, not the task.

Two smell classes, each with an objective metric computable without a model grader:

- `log-negation-only`. Smelly instruction is a prohibition with no positive target ("Don't be
  verbose"); fixed states the target ("Answer in one sentence"). Outcome: word-count control,
  measured as the standard deviation of output length across samples. Prediction (Jang et al.
  2022, negated prompts): the negation-only variant produces less controlled length.
- `log-contradiction`. Smelly instruction pairs conflicting constraints ("detailed but concise");
  fixed states one ("in three sentences"). Outcome: sentences per output and hit rate against the
  intended length. Prediction: the contradictory variant blends and misses more often.

## Run

```sh
# needs a reachable Messages API. K samples per variant.
ANTHROPIC_MODEL=claude-haiku-4-5-20251001 K=5 ./run.sh pairs.jsonl outputs.jsonl
python3 score.py outputs.jsonl
```

`run.sh` reads `pairs.jsonl`, calls the model K times for each variant, and appends one line per
sample to `outputs.jsonl` as `{id, smell, variant, text}`. `score.py` computes the metric per smell
and variant and applies the decision rule.

## Decision rule

Per smell class, compare fixed vs smelly on the metric:

- `log-negation-only`: keep the rule if fixed cuts length standard deviation by >= 20%.
- `log-contradiction`: keep the rule if fixed raises the intended-length hit rate by >= 20 points.

A smell that moves its metric by less than that in a run of K >= 5 over >= 6 pairs is demoted:
set its rule `severity: suggestion` and note the null result here. No claim is made that a smell
matters until this run shows it.

## Threats to validity

Single model, small pair set, one metric per smell. Treat a first run as indicative. A rule is
demoted only on a null result that holds across a second run with a different model.
