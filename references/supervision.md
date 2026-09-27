# Supervision playbook

## The watch loop

```
while any worker running:
    out = orch watch                # returns on activity/alert/finish or after the profile interval
    for alert in out: act per table below
    every 2-3 cycles: orch doc <w>  # is the worklog being kept?
    append one line to PLAN.md "Progress ledger": time · worker · progressing? looping? · action
```

Watch intervals per strictness: 180 s / 120 s / 75 s / 45 s (`--timeout` overrides). Keep a single
`watch` call under the Bash timeout (≤ 540 s).

Ask the Magentic-One ledger questions on every cycle:
1. Is the request fully satisfied? → then stop watching and review.
2. Is the worker **looping** (same action, same error, same file churned)?
3. Is it **making progress** (new files, tests going from red to green, worklog advancing)?
4. What's the **single next instruction**, if any?

After 2 cycles with no progress, **replan**: rewrite the brief, split the task, or change model.
Don't keep nudging.

## Alert → action

| Alert | Meaning | Default action |
|---|---|---|
| `DANGER` | risky command (push, force, reset --hard, rm -rf, sudo, curl\|sh, publish …) | Strictness ≥2: `stop` immediately, check the damage (`git status`, `diff`), resume with an explicit prohibition. 1: steer. |
| `SCOPE` | edit outside assigned globs (may have been blocked already) | Legitimate need → widen the scope in the plan and tell the worker. Otherwise steer: "Revert X, stay inside Y." |
| `CHEAT?` | skip/ignore/stub/`|| true` pattern written | Inspect the edit (`log --full`). If it games a check: level-2 correction, and note it for the review. |
| `TEST_EDIT` | a test file changed | Read that hunk. New tests = fine. Changed assertions or expectations = justify or revert. |
| `LOOP` | same command ≥ N times recently | Steer with a *different* hypothesis or a diagnostic step. Twice → stop + re-brief. |
| `FAIL_STREAK` | N failing commands in a row | Look at the last error. Environment problem (missing dependency, wrong command)? Hand over the fix. Otherwise let it work one more cycle. |
| `CHURN` | same file edited ≥ 8× | Usually thrashing: ask for a written hypothesis in the worklog before the next edit. |
| `STALE_DOC` | code edits but no worklog update | Nudge: "Update your worklog now (Status, Done, Verification)." |
| `IDLE` | no events for a long time | Check `status`/`log --stderr`: waiting on a prompt, a network hang, or a long build? Hung → stop + resume. |
| `ERROR` / `TURN_FAILED` | harness or API error | Check stderr. Transient → `resume "continue"`. Auth/model problem → fix the settings or escalate. |
| `QUESTION` / `WORKER_NEEDS_CONTEXT` | worker asks something | Answer precisely with `resume`. Record the decision in the plan. |
| `WORKER_BLOCKED` | worker gives up | Read its worklog "tried" list. Unblock with information, re-scope, or replace. |
| `WORKER_PLAN_READY` | plan gate | Review the plan against the definition of done. Approve it or correct it via `resume`. |
| `NO_STATUS` | finished without the contract line | Treat as unfinished: `resume "Finish the task and end with the ORCH_STATUS line."` |

What the feed shows and alerts do not flag, which you should still catch:
- a solution that drifts from the brief's approach or architecture
- mocks or fakes of the unit under test; hard-coded return values that match the test inputs
- "I'll just…" rewrites of unrelated code; new dependencies nobody asked for
- claims in `»` messages that contradict the command output just above them

## Writing steering messages

- ≤3 sentences, imperative, one topic: `STOP editing tests/api.test.ts — the assertion is correct; the bug is in src/api.ts:42 (off-by-one in pagination). Fix the source instead.`
- Include the **evidence** (file:line, the command output) and the **alternative**.
- Never "maybe consider…": workers skim hedged feedback, and feedback friction is real.
- State approaches you have already rejected, so the worker won't retry them.
- Hook harnesses (Claude) get the message after their next tool call; the Stop hook also delivers it
  if they try to finish. Soft harnesses read the inbox file after their current step. Use `--mode hard`
  when waiting would waste real work or cause damage.

## When to replace instead of repair

- 2 feedback rounds without real progress on the same blocking item
- the context is poisoned (long thrashing, the worker keeps defending a wrong approach)
- the model is visibly out of its depth → a stronger model with the same brief plus a "lessons so far" section

`start <w>-2 --task-file <brief + lessons>`. Stop the old worker first. With a worktree, you can
discard its branch.
