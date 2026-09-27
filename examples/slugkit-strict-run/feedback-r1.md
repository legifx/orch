Round 1 review: the definition-of-done commands passed, but I ran additional checks and found 3
real bugs. Fix all three; don't just patch the exact examples below — fix the underlying logic.

## 1. [BLOCKING] Bogus `"Ã" -> "ss"` replacement in `slugkit/__init__.py`
You added `text = text.replace("Ã", "ss")` alongside the `ß -> ss` fix, apparently guessing it was
an "uppercase eszett variant". It is not — "Ã" (U+00C3) is capital A with tilde, unrelated to ß.
This corrupts real input:
- `slugify("Ã")` → `"ss"`, should be `"a"`
- `slugify("MAÇÃ")` → `"macss"`, should be `"maca"`
Remove that line entirely. If you were trying to handle the actual uppercase eszett (U+1E9E, "ẞ"),
map that specific character, not "Ã" — but it's not required by the spec, so simplest is to just
delete the bogus line and let NFKD + the lowercase `ß` mapping handle everything else.

## 2. [BLOCKING] Truncation drops an extra whole word at some exact boundaries
`slugify("ab cd ef", max_length=5)` → `"ab"`, but the correct answer is `"ab-cd"` — "ab-cd" is
exactly 5 characters and ends right at a real word boundary (the next character in the full slug
is a hyphen), so it fits the constraint ("truncate at a word boundary, never mid-word") without
losing "cd".

Root cause: your code checks `if '-' in truncated` before checking whether the cut itself already
lands cleanly on a boundary. When the prefix contains an earlier hyphen (from a prior word) *and*
the character right after the cut is also a hyphen, you're incorrectly rsplitting on that earlier
hyphen instead of recognizing the cut is already valid.

Fix the order of checks: first determine whether `text[max_length]` is `'-'` (or `max_length >=
len(text)`) — if so, the prefix `text[:max_length]` is already a clean boundary, use it as-is
(no further rsplit needed). Only fall back to `rsplit('-', 1)` when the cut lands strictly inside a
word (i.e., `text[max_length]` is not `'-'` and not end-of-string).

Verify with: `slugify("ab cd ef", max_length=5)` → `"ab-cd"`, and re-check your own existing test
`slugify("The Quick Brown Fox", max_length=10)` still gives `"the-quick"` (it should, but only by
accident with the current buggy logic — the new fix must produce it for the *right* reason).

## 3. [BLOCKING] Negative `max_length` produces nonsensical output
`slugify("creme-brulee", max_length=-1)` → `"creme"` (Python's negative-slice semantics silently
kick in). A negative `max_length` doesn't make sense for "maximum length" — either treat it as 0
(empty result, if you want to keep the function total) or raise `ValueError`. Pick one, document
the choice in the worklog's Decisions section, and add a small test for it.

## Not blocking, just noted
Letters that NFKD doesn't decompose (æ, œ, ø, đ, ł, capital ẞ) still get dropped rather than
transliterated. This is out of the original spec (only ß was required) — no action needed, but
don't introduce new bogus replacements chasing this; leave it as-is.

## What's already good, keep it
- ß → ss, NFKD accent stripping, the CLI `--max-length` wiring, and the new test additions
  (test_accented_characters, test_eszett, etc.) are all correct and should stay as they are —
  just fix the 3 issues above and add regression tests for cases 1 and 2 (case 3 per your choice above).
