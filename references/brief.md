# Worker brief template

Workers see none of your context. The brief (together with the worker contract that `orch` prepends)
is everything they know, so it must stand alone. Keep it to roughly 30–80 lines.

```markdown
# Task: <imperative title>

## Objective
<2-4 sentences: what to build or change, and why it matters to the user>

## Context
- Stack: <language, framework, versions>
- Relevant files: <path — one-line role each>
- Conventions to follow: <error handling style, naming, test framework, formatting tool>
- Baseline: <tests currently failing before your change, if any>

## Requirements
1. <concrete, testable>
2. …

## Out of scope
- <things that look related but must not be touched>

## Definition of done
- [ ] `<exact command>` → <expected result>
- [ ] `<exact command>` → <expected result>
- [ ] Docs: <which docs must describe the change>
- [ ] Worklog complete (Status, Done, Decisions, Verification, Open issues, Handoff)

## Hints (optional)
<pitfalls you already know about, approaches ruled out, API quirks>

<!-- strictness >= 3: -->
## Plan gate
First write your implementation plan into your worklog (under Status/Decisions: files to change,
approach, test strategy, risks). Then finish with `ORCH_STATUS: PLAN_READY` and wait. Don't write
code before the plan is approved.
```

Rules of thumb:
- One brief = one coherent deliverable. If a brief needs "and also …" three times, split it.
- Name exact commands, not "make sure tests pass".
- Keep held-out checks out of the brief. If a worker knows the exact probe, it can special-case it.
- For parallel workers, give each brief the other workers' scopes as "Out of scope".
- When re-briefing after a failed worker, add a `## Lessons so far` section listing what failed and why.
