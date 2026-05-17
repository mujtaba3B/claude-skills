---
name: expert-review
description: Deprecated alias. The expert-review skill has been merged into `/second-opinion` (with four modes: claude, codex, gemini, panel). Invoke `/second-opinion panel` for the original three-LLM behavior. This shim exists to preserve slash-command muscle memory. Trigger on "/expert-review" or anyone still typing "expert review" by habit.
---

# Expert Review (deprecated, forwards to `/second-opinion`)

This skill has been consolidated into `/second-opinion`, which supports four modes: `claude`, `codex`, `gemini`, and `panel`. The original three-LLM behavior is `/second-opinion panel`.

## What to do when invoked

1. Tell the user, in one line, that `/expert-review` has moved to `/second-opinion panel` and that this shim is forwarding.
2. Read `/Users/mujtaba/dev/public-claude-skills/second-opinion/SKILL.md` and execute it with mode pre-set to `panel`. Carry forward any inline hint the user passed (e.g., `/expert-review focus on security` becomes `/second-opinion panel focus on security`).
3. Skip the `AskUserQuestion` step in `second-opinion`. The mode is fixed as `panel` for this entry point.

That is the whole shim. The full design, prompt-composition rules, em-dash rule, anti-sycophancy line, synthesis templates, and anti-patterns all live in `second-opinion/SKILL.md`. This file should never grow beyond a forwarder.
