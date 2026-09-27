# Harness cheatsheet (September 2026)

`orch` hides these differences. This page is for picking a harness and for debugging a failed
`orch smoke`. ✅ = verified end-to-end with `orch`; the rest come from official docs and source code
and haven't been run by the author.

| Harness | Headless call `orch` builds | Live events | Resume | Steering in `orch` | Native steering the CLI offers |
|---|---|---|---|---|---|
| **Claude Code** ✅ | `claude -p --output-format stream-json --verbose --model M --effort E --permission-mode bypassPermissions --settings <hooks> --append-system-prompt <contract>` | yes | `--resume <id>` | **hook**: PreToolUse guard, PostToolUse inbox injection, Stop hook (inbox + worklog gate) | stdin `--input-format stream-json` (mid-turn injection + `control_request interrupt`, verified) |
| **Antigravity** (`agy`) ✅ | `agy --output-format stream-json --dangerously-skip-permissions --model M --effort E -p <prompt>` | yes (`step_update`) | `--conversation <id>` | soft inbox / hard interrupt+resume | `--input-format stream-json` (one turn per message) |
| **Hermes** ✅ | `hermes chat -Q --yolo -m M --provider P --reasoning E -q <prompt>` | final text only (diff pulse) | `--resume <id>` (id read from stderr) | soft / hard | `hermes acp` with `/steer <msg>` |
| **Command Code** ✅ | `command-code --trust --skip-onboarding --output-format json --yolo --tools-all -m M --effort E -p <prompt>` | yes (`event` envelope) | `--resume <id>` | soft / hard | – |
| Codex CLI | `codex exec --json -m M -c model_reasoning_effort=E -s workspace-write [resume <id>] <prompt>` | yes (`thread/item/turn`) | `exec resume <thread_id>` | soft / hard | `codex app-server`: `turn/steer`, `turn/interrupt` |
| Gemini CLI | `gemini -o stream-json -m M --approval-mode yolo -p <prompt>` | yes | `--resume <uuid>` | soft / hard | `--acp` (cancel + prompt) |
| Qwen Code | `qwen --output-format stream-json --approval-mode yolo --model M -p <prompt>` | yes (Claude-style) | `--resume <id>` | soft / hard | `--input-format stream-json` + control requests |
| opencode | `opencode run --format json --auto -m provider/model --variant E <prompt>` | yes | `-s <id>` | soft / hard | `opencode serve`: abort + `prompt_async` |
| Cursor CLI | `cursor-agent -p --output-format stream-json --trust --force --model M <prompt>` | yes | `--resume <id>` | soft / hard | `agent acp` |
| Copilot CLI | `copilot -p <prompt> -s --output-format json --no-ask-user --allow-all --model M --effort E` | partly | `--resume=<id>` | soft / hard | SDK `session.send({mode:"immediate"})` |
| Amp | `amp --stream-json --dangerously-allow-all -m <mode> -x <prompt>` | yes (Claude-style) | `threads continue <T-id>` | soft / hard | `--stream-json-input` with `"steer": true` |
| Factory Droid | `droid exec -o json --auto high -m M -r E <prompt>` | final only (diff pulse) | `-s <id>` | soft / hard | `stream-jsonrpc` `add_user_message` |
| Goose | `GOOSE_MODE=auto goose run --output-format stream-json -n <name> -t <prompt>` | yes | `--resume -n <name>` | soft / hard | `goose acp` |
| Crush | `crush run -y -m provider/model <prompt>` | text only (diff pulse) | `-s <id>` | soft only | server queue |
| Kiro CLI | `kiro-cli chat --no-interactive --output-format stream-json --trust-all-tools <prompt>` | yes | `--resume-id <id>` | soft / hard | `kiro-cli acp` |
| Aider | `aider --yes-always --no-stream --no-auto-commits --message <prompt>` | text only (diff pulse) | `--restore-chat-history` | soft / hard | – |

## Steering channels, from fastest to slowest

1. **hook** (Claude Code): `orch steer` appends to the worker's inbox. The PostToolUse hook injects it
   as `additionalContext` right after the worker's next tool call. If the worker is about to finish,
   the Stop hook blocks and hands it the message. The same hooks give you **hard guards**: writes to
   `--protect` paths and reads of orchestrator-private files are denied *before* they run.
2. **soft** (every other harness): the message goes into `<cwd>/.orch/INBOX-<worker>.md`, and the
   contract tells the worker to re-read it after each step. This depends on the worker's discipline;
   most models follow it within 1–2 steps.
3. **hard**: SIGINT → SIGTERM, then resume the same session with the message
   ("You were interrupted by your supervisor …"). Works everywhere a session id exists and costs one
   context reload.

## Quirks

- **Codex** `workspace-write` blocks network by default. Tests that need the network fail; use
  `--permission-mode yolo` only inside a disposable sandbox or container.
- **Gemini/Qwen** have no effort flag; set `thinkingConfig` in their settings.
- **Hermes** `-z` doesn't print a session id, so `orch` uses `chat -Q`, which writes `session_id:` to stderr.
- **agy** `-p` takes the prompt as its value; `orch` always puts it last.
- **Goose** doesn't stream a session id; `orch` names the session `orch-<worker>-<ts>`.
- Harnesses without live events (Hermes, Droid, Crush, Aider) are watched through **diff pulses**:
  `watch` shows files that changed since the last poll.
- Nested Claude: `orch` removes `CLAUDECODE` from the environment so that `claude -p` starts inside a
  Claude Code session.

## Adding a harness

Subclass `Harness` in `bin/orch`: set `name`/`bins`, implement `build(w, prompt, resume)` → argv and
`parse(obj)` → normalized events (`init`, `say`, `think`, `shell`, `edit`, `read`, `tool`, `result`,
`error`, `done`), then add it to `HARNESSES`. Test it with `orch smoke <name>`.
