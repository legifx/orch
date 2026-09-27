# Orchestration plan — 20260927-133542-slugify-transliterate
Strictness: 3 (strict)

## Goal
`slugify()` in `slugkit/__init__.py` currently drops any character outside `[a-z0-9]` after
lowercasing, so accented Latin letters just vanish (e.g. "Crème Brûlée" -> "cr-me-br-l-e",
"Straße" -> "stra-e"). It must instead transliterate them to plain ASCII (e.g. "creme-brulee",
"strasse"). It must also gain an optional `max_length` parameter that truncates the result at a
word boundary (never mid-word, never leaving a trailing hyphen). The CLI (`slugkit/__main__.py`)
must expose this as `--max-length N`.

## Context found
- Stack: Python 3 (tested on 3.14), stdlib only, no dependencies/build step.
- Relevant files:
  - `slugkit/__init__.py` — the `slugify(text)` function (8 lines, whole file).
  - `slugkit/__main__.py` — CLI entry point, currently `python3 -m slugkit "text"` with no flags.
  - `tests/test_slug.py` — unittest, 2 existing tests.
- Conventions: plain stdlib, no argparse currently used in `__main__.py` (just `sys.argv` joined),
  no type hints in use, docstring on `slugify`, unittest for tests.
- Test/run commands:
  - `python3 -m unittest discover -s tests -t .` (from repo root)
  - `python3 -m slugkit "some text"` (CLI)
- Baseline: both existing tests pass before any change (`test_basic`, `test_symbols`).

## Definition of done (acceptance contract)
1. `python3 -m unittest discover -s tests -t .` → all tests pass, including existing ones (do not weaken them).
2. `python3 -c "from slugkit import slugify; print(slugify('Crème Brûlée'))"` → `creme-brulee`
3. `python3 -c "from slugkit import slugify; print(slugify('Straße'))"` → `strasse`
4. `python3 -c "from slugkit import slugify; print(slugify('Hello World', max_length=5))"` → `hello` (word boundary, no trailing hyphen)
5. CLI: `python3 -m slugkit --max-length 5 "Hello World"` → `hello`
6. New unittest cases added to `tests/test_slug.py` covering transliteration and `max_length`.
7. Worklog complete (Status, Done, Decisions, Verification, Open issues, Handoff).

## Held-out checks (orchestrator only — never shown to workers)
- `slugify("café naïve")` → `cafe-naive` (NFKD-decomposable accents)
- `slugify("Ångström")` → `angstrom`
- `slugify("hello-world", max_length=6)` → `hello` (cut lands exactly on the hyphen after "hello-"; must strip trailing hyphen, not return `hello-`)
- `slugify("Hello World", max_length=11)` → `hello-world` (max_length == exact slug length, unchanged)
- `slugify("Hello World", max_length=3)` → `""` (first word alone already exceeds max_length; must not cut mid-word "hel")
- `slugify("Hello", max_length=100)` → `hello` (max_length larger than slug, no-op)
- CLI: `python3 -m slugkit --max-length 3 "Hello World"` → empty line (same as above)
- Re-run `python3 -m unittest discover -s tests -t .` after merge — must still be green, and diff
  the two existing tests to confirm assertions weren't weakened.
- Check `ß` (eszett) is NOT decomposed by `unicodedata.normalize('NFKD', ...)` alone — worker must
  special-case it (or similar), confirms they didn't just bolt on NFKD and call it done.

## Work split
| worker | harness/model | scope (globs) | protected (read-only) | depends on |
|---|---|---|---|---|
| w1 | claude/haiku, effort low | `slugkit/**`, `tests/test_slug.py` | none | — |

## Task ledger
- Verified: baseline tests pass (2/2), repo is clean git tree, no build step.
- Guess to check: worker's transliteration approach (NFKD + ASCII encode + manual map for ß/æ/œ/ø/etc.) — verify at review with held-out checks above.
- Risk: worker may implement truncation that counts word count instead of char length, or that permits mid-word cuts — verify explicitly with `max_length=6` and `max_length=3` cases above.

## Progress ledger
<!-- one line per watch/review cycle: time · worker · progressing? looping? · action taken -->

## Review log
Round 1 (w1): **REVISE**. Spec items 2-5 passed as literally written, but held-out checks and a
fresh-context reviewer subagent both found real defects:
- [HIGH] `text.replace("Ã", "ss")` in `slugkit/__init__.py` is bogus — "Ã" (capital A-tilde) has
  nothing to do with ß. `slugify("Ã")` → `"ss"` instead of `"a"`; `slugify("MAÇÃ")` → `"macss"`.
- [HIGH] Truncation logic drops an extra whole word when the cut lands exactly on a hyphen boundary
  but earlier hyphens exist in the prefix: `slugify("ab cd ef", max_length=5)` → `"ab"` instead of
  `"ab-cd"`. Confirmed independently by reviewer subagent with a second example.
- [MEDIUM] Negative `max_length` falls through to Python's negative-slice semantics:
  `slugify("creme-brulee", max_length=-1)` → `"creme"` (silently drops last char, nonsensical).
- [LOW, not blocking] Non-NFKD-decomposable letters (æ, œ, ø, đ, ł) still get dropped, not
  transliterated — out of spec scope (only ß was required), noted for awareness only.
Feedback sent to w1 requesting fixes for the 3 blocking items above.

Round 2 (w1): **ACCEPT**. All 3 blocking bugs fixed correctly (verified independently, not just
via worker's claims):
- `slugify("Ã")` → `"a"`, `slugify("MAÇÃ")` → `"maca"` (bogus replacement removed)
- `slugify("ab cd ef", max_length=5)` → `"ab-cd"` (boundary check reordered: checks
  `text[max_length] == '-'` / end-of-string first, before falling back to rsplit)
- `slugify(x, max_length=-1)` → raises `ValueError` (worker's choice, documented in worklog)
- Full suite: 10/10 tests pass (2 original untouched + 8 new, none weakened)
- All definition-of-done commands re-run by me directly: pass
- All held-out checks re-run by me directly: pass (café naïve, Ångström, hyphen-exact-boundary,
  max_length==len, max_length shorter than first word, max_length larger than slug, CLI --max-length 3)
- I added a short README note on transliteration + `--max-length` (worker's worklog covered
  verification but not user docs; small gap, fixed directly rather than sent back for a 3rd round).
