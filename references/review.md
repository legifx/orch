# Review protocol

The review is where /orch earns its keep. Workers regularly report "all tests pass" after running a
*different* command than the one asked for. Only execution evidence counts.

## Order (don't skip ahead)

1. **Status gate**: read the final message (`orch log <w> --tail 5`) and the `ORCH_STATUS`.
2. **Reproduce**: run every definition-of-done command yourself, exactly as written, from a clean shell
   in the worker's cwd. Then the full test suite, build, lint and typecheck. Diff the results
   against the baseline in `PLAN.md`. Pre-existing failures are not the worker's fault; new ones are.
3. **Held-out checks**: run the edge cases and probes you wrote down and never showed the worker.
4. **Diff read** (`orch diff <w>`): read every hunk in scope. For tests: new tests are good, but they
   must assert real behaviour. Changed or removed assertions need a reason.
5. **Spec compliance**: definition-of-done item → PASS/FAIL + evidence. **Any FAIL → REVISE**; skip the
   quality review until the spec passes.
6. **Quality**: correctness (edge cases, errors, concurrency, resource cleanup), security (injection,
   secrets, authz, unsafe deserialisation), simplicity (dead code, needless abstraction, duplication),
   consistency (naming, patterns, error style of the codebase), maintainability (tests readable, no magic).
7. **Documentation**: see below.
8. **Verdict + feedback**.

## Severity scale

| Severity | Meaning | Examples |
|---|---|---|
| critical | wrong or dangerous result; data loss; security hole | failing acceptance test, SQL injection, deleted user data |
| high | the requirement is only partly met, or there is a likely production bug | edge case crashes, error swallowed, race condition |
| medium | a real weakness that doesn't break the definition of done | missing input validation, test that asserts too little, confusing API |
| low | polish | naming, small duplication, comment typo |

## Acceptance bar per strictness

| | 1 Draft | 2 Standard | 3 Strict | 4 Paranoid |
|---|---|---|---|---|
| Definition-of-done items | happy path runs | all PASS, reproduced by you | all PASS | all PASS |
| Test suite | no new crash | green (vs baseline) | green + held-out checks | green + held-out + adversarial probes |
| Open findings allowed | anything below critical | no high or critical | no medium or higher | none (lows fixed or explicitly waived) |
| Independent reviewer | – | – | fresh-context subagent | subagent + cross-model harness reviewer |
| Worklog | exists | complete and accurate | accurate and kept up during the run | accurate, and Verification reproduces exactly |
| Max feedback rounds | 1 | 2 | 3 | 5 |

Verdicts: **ACCEPT** (meets the bar), **REVISE** (fixable, rounds left), **REPLACE** (no progress over 2
rounds, poisoned context, or the model is out of its depth → fresh worker with a better brief or a
stronger model), **ESCALATE** (rounds exhausted, or it needs a human decision).

## Independent reviewer subagent (strictness ≥3)

Spawn it with the `Agent` tool (general-purpose) in a fresh context. Don't pass it your opinion. Prompt:

```
You are a skeptical senior reviewer. Your job is to find defects, not to praise.
Repository: <cwd>. Change under review: `git diff <base_commit>` (plus new files listed by
`git ls-files --others --exclude-standard`).
Requirements (definition of done):
<paste DoD>
Do NOT modify files. You may run read-only commands, builds and tests.
Report up to 10 findings, most severe first, each with: severity (critical/high/medium/low),
file:line, what is wrong, concrete evidence (a command + output, or reasoning with a
counter-example input), and the fix. If you find nothing, say which risky areas you checked.
```

Confirm every finding before using it: reproduce it, or read the code yourself. Drop what you can't confirm.

What made reviewers effective in practice: give them the **interface contract** and the **timing/ID tables**
from the plan, tell them which commands produce *evidence* (renders, debug dumps, measurement probes), and
name the risk classes to hunt (state leaks between frames/requests, contract breaks at call sites, geometry or
data that "looks fine" but is measurably off). With that, a reviewer found in each part several real
defects the worker's own checks had missed (e.g. an object driving through the camera, feet sunk into the
ground, a baked-in wrong screen image). For visual work, confirm each finding on the image before sending it.

## Cross-model reviewer (strictness 4)

Same-family judges prefer their own family's output, so use a different model family from the worker:

```
orch start rev-<w> -H <other harness> -m <model> --read-only --cwd <worker cwd> --task-file <review brief>
```

The review brief is the prompt above. The reviewer writes its findings to its own worklog and final
message. Two independent reviewers agreeing on a finding is strong evidence. When they disagree,
check the code yourself.

## Documentation review

Run `orch doc <w>` and check:
- **Status / Done**: do they match the diff? No invented work, no missing changes.
- **Decisions**: are assumptions recorded? Were any of them product decisions the user should make?
  Surface those to the user.
- **Verification**: re-run the listed commands. Do they give the claimed results? (Mismatches are common.)
- **Open issues**: honest? Anything you found that isn't listed there?
- **Handoff**: could a stranger run and test it from this?
- **User docs** (README, docs/, --help, changelog): updated for behaviour changes, and correct.

Fix small errors (wrong command, missing line, stale statement) **yourself** directly in the worklog
or docs, and note "doc fixed by orchestrator" in the review log. Send larger gaps (undocumented feature,
missing section) back as feedback. An untouched worklog is a blocking finding at strictness ≥2.

## Writing feedback (templates/feedback.md)

- Blocking items first, numbered, each with **evidence** and the **expected behaviour**.
- Name what is *good* in one line only if it must be kept ("keep the parser structure").
- A "Do not" list of approaches that were rejected, so the worker won't retry them.
- Ask for the verification commands to be re-run and the worklog updated.
- Keep it under about 40 lines. More than that usually means the brief was wrong, so rewrite the brief instead.
