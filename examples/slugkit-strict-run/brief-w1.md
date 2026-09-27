# Task: Transliterate accented characters in slugify() and add max_length truncation

## Objective
`slugify()` in `slugkit/__init__.py` currently drops any character outside `[a-z0-9]` after
lowercasing — accented Latin letters just disappear instead of being converted to their plain
ASCII equivalent. Fix it so accents are transliterated, not dropped (e.g. "Crème Brûlée" ->
"creme-brulee", "Straße" -> "strasse"). Also add an optional `max_length` parameter that truncates
the result at a word boundary — never mid-word, and never leaving a trailing hyphen. Expose this
on the CLI as `--max-length N`.

## Context
- Stack: Python 3, stdlib only, no external dependencies, no build step.
- Relevant files:
  - `slugkit/__init__.py` — the whole `slugify(text)` function (8 lines). This is what you change.
  - `slugkit/__main__.py` — CLI entry point. Currently just joins `sys.argv[1:]` and prints the slug.
  - `tests/test_slug.py` — unittest-based tests. Add new cases here; do not weaken the 2 existing ones.
- Conventions: plain stdlib (no argparse currently, but you may introduce `argparse` in
  `__main__.py` if that's the cleanest way to add `--max-length`), no type hints currently used,
  unittest for tests.
- Baseline: `python3 -m unittest discover -s tests -t .` — both existing tests pass. Keep them passing.

## Requirements
1. `slugify(text)` must transliterate accented/special Latin characters to their closest ASCII
   equivalent instead of dropping them. Concretely: `slugify("Crème Brûlée")` == `"creme-brulee"`,
   and `slugify("Straße")` == `"strasse"`. Note: Python's `unicodedata.normalize('NFKD', ...)`
   handles most accented letters (é, è, ü, ñ, ç, å, etc.) by decomposing them into a base letter +
   combining mark that you can then strip — but it does **not** decompose `ß` (German eszett) into
   anything; you need an explicit mapping for that case (`ß` -> `ss`) and similar non-decomposing
   letters if you choose to support them (not required beyond ß, but don't regress plain ASCII input).
2. `slugify(text, max_length=None)` — when `max_length` is given (an int), the returned slug must
   be at most `max_length` characters, truncated at a word (hyphen) boundary — never cutting a word
   in half, and never leaving a trailing hyphen. If truncating strictly at the boundary leaves
   nothing (e.g. the first word alone already exceeds `max_length`), return an empty string rather
   than a partial word.
3. CLI: add a `--max-length N` flag to `slugkit/__main__.py` that passes `N` through to `slugify`'s
   `max_length` parameter. `python3 -m slugkit --max-length 5 "Hello World"` must print `hello`.
4. Add test cases to `tests/test_slug.py` covering: at least one accented-character transliteration
   example, the `ß` case, and at least one `max_length` truncation example (word-boundary, no
   trailing hyphen).

## Out of scope
- Don't rewrite existing tests' assertions — only add new ones.
- Don't add a general i18n/transliteration library dependency (stdlib only).
- Don't change the public behavior of `slugify` for plain ASCII input.

## Definition of done
- [ ] `python3 -m unittest discover -s tests -t .` → all tests pass (existing + new).
- [ ] `python3 -c "from slugkit import slugify; print(slugify('Crème Brûlée'))"` → `creme-brulee`
- [ ] `python3 -c "from slugkit import slugify; print(slugify('Straße'))"` → `strasse`
- [ ] `python3 -c "from slugkit import slugify; print(slugify('Hello World', max_length=5))"` → `hello`
- [ ] `python3 -m slugkit --max-length 5 "Hello World"` → `hello`
- [ ] Worklog complete: Status, Done, Decisions, Verification (paste actual command output), Open issues, Handoff.

## Hints
- `unicodedata.normalize('NFKD', text)` then filtering out characters where
  `unicodedata.combining(ch)` is true, then `.encode('ascii', 'ignore').decode('ascii')` is a
  standard, dependency-free way to strip accents from decomposable characters. Apply your `ß`-style
  manual replacements *before* that NFKD step (since `ß` won't decompose).
- For the truncation, a simple approach: slice the full slug to `max_length` chars, then cut back to
  the last `-` in that slice (`rsplit('-', 1)[0]`) if the slice itself doesn't already end cleanly
  at a hyphen boundary, then `.strip('-')`.
- Keep it small — this is one function plus a CLI flag, not a new module.

## Worklog
Write your status, decisions and verification output into a worklog file (create
`.orch/runs/20260927-133542-slugify-transliterate/worklog-w1.md` if no other location is given to
you) as you go, and keep it current.
