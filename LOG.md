# claude-skills . Project Log

Narrative + decision log for the `claude-skills` repo. For per-skill technical changes, see each skill's own history.

Format: date-headed sections, topic-tagged entries. One line per decision; expand inline if the *why* is non-obvious.

---

## 2026-05-17

### `[meta][release]` v2026.05.17 shipped: first CalVer release with `/second-opinion` and `/distill-question-and-answer-log-to-principles`
First tagged release of the repo. Establishes the CalVer convention going forward. Notes call out the `/expert-review` → `/second-opinion panel` alias and the new four-mode shape so muscle memory carries over. Release URL: https://github.com/mujtaba3B/claude-skills/releases/tag/v2026.05.17.

## 2026-05-16

### `[meta][release]` Adopted CalVer (`v2026.05.17` style) for releases; Claude prompts after every merge
Need: public repo with no release history yet; user wants people to be able to see when new skills come out. Considered SemVer (new skill = minor) vs SemVer-with-user-convention (new skill = major) vs CalVer.

Settled on CalVer. SemVer's main value is signaling breakage to library consumers planning upgrades; this is a flat pile of skills people copy-paste, where that signal is mostly wasted. CalVer makes the version number reinforce the "shipped recently" signal that the GitHub Releases page already carries, instead of competing with it.

Format: `v2026.05.17`. Suffix `.1`, `.2` if shipping twice in one day. Every merge to `main` triggers a release. Convention recorded in `CLAUDE.md` so Claude is required to prompt the user for a release after each merge; silent skip is not allowed.

### `[skill][second-opinion]` Added Step 3.5 CLI staleness check with 24h TTL
Need: user does not invoke `codex` or `gemini` often outside `/second-opinion`, so the CLIs drift behind upstream. Once before, an old `codex exec` produced a stdin-hang bug that a later version fixed. Wanted a way to catch drift without taxing every invocation.

Dogfooded `/second-opinion panel` on the design itself before building. Three-expert consensus shaped v1:
1. No unconditional per-invocation network check. 1-2s of pre-dispatch latency is paid 100% of the time to catch a once-a-quarter bug. Bad ratio.
2. 24-hour TTL via flag file (`~/.claude/.second-opinion-cli-check`) is the right cadence (Homebrew, gh follow this pattern). Hot path becomes a sub-millisecond `cat`; `npm view` only runs when the TTL has expired.
3. No background or auto upgrade. Synchronous-after-confirmation only. Global `npm install -g` mid-dispatch can change the binary the current run is about to use.
4. Fail silent on network errors. `timeout 2` plus empty-string check means a flaky registry results in "cannot determine staleness", not "skill cannot dispatch".

Steelman against the consensus (none of the three experts engaged with it): the user explicitly asked for the inline interactive upgrade offer. The convergent expert opinion was "no inline offer" based on warning-fatigue priors that assume high-frequency invocation. But the TTL gate solves the fatigue problem (the offer fires at most once per 24h), and for a user who rarely invokes these CLIs the inline offer is the most valuable moment to surface drift. Kept the inline offer, gated by the TTL.

Applies to all modes, including `claude`, because panel uses both CLIs and single-`claude` runs are often followed by single-codex/gemini follow-ups in the same session. Skipping the check in `claude` mode would leave a hole.

### `[skill][second-opinion]` Consolidated `/expert-review` into `/second-opinion` with four modes
Need: `/expert-review` only had one shape (panel of three). For many situations a single second opinion from a specific model (codex, gemini, or a Claude subagent) is the right tool. Spinning up two skills with overlapping triggers was the wrong split.

New skill at `second-opinion/` with modes `claude` / `codex` / `gemini` / `panel`. Reuses the existing prompt-composition rules (no em-dashes, evidence requirement, Claude-subagent anti-sycophancy line, fixed output contract) unchanged. Step 4 dispatch is mode-aware. Step 5 synthesis has two templates: panel (Converge / Steelman / Disagree / Adjustments) and single-expert (Thesis / Key risks / Adjustments / optional Steelman).

Dogfooded `/expert-review` on the design before building. Three convergent adjustments from the panel shaped v1:
1. Do NOT always ask for mode. Infer when the slash arg or trigger phrase is unambiguous (`/second-opinion codex`, "ask gemini"); only `AskUserQuestion` when bare. Every unnecessary confirmation trains users away from the skill.
2. Do NOT pre-recommend Panel in the `AskUserQuestion` options. Panel is the most expensive path; nudging it by default creates a quiet cost trap.
3. Keep `Key risks` in the single-expert template. A second opinion without failure modes is just a summary.

Split decisions where the panel disagreed: kept a thin `expert-review` shim (Claude + OpenAI argued path-based slash-command muscle memory survives only with a shim; Gemini wanted hard-replace). Skipped a 5th adversarial mode (Claude + OpenAI: named adversarial often produces performative contrarianism; Gemini wanted it). Skipped a tiebreaker mode (all three agreed: workflow, not a base mode).

Migration: `expert-review/SKILL.md` is now a one-page shim that forwards `/expert-review` invocations to `/second-opinion panel`, preserving any inline hint. The shim should never grow past forwarder size. Live bug from the prior `/expert-review` run still applies: `codex exec` needs `< /dev/null` AND `--skip-git-repo-check` when run from `/tmp/`.



### `[skill][distill-question-and-answer-log-to-principles]` Added the Q+A capture and distill loop
Need: every time Claude uses `AskUserQuestion`, the user's answer evaporates at session end and the same questions get re-asked in future sessions. The existing auto-memory system handles `feedback_*.md` and `project_*.md` well but does nothing for tool-mediated decisions.

Built three things together (capture hook + new memory type + distill skill); the skill lives in this repo, the hook lives at `~/.claude/scripts/question-and-answer-capture.sh` because hooks are global-machine concerns not per-skill assets.

Two rounds of `/expert-review` shaped scope, ruthlessly. Original design (PreToolUse keyword grep + Stop-hook `claude -p` distiller + reinforcement counter + 90-day decay) was cut to capture-only + user-approved distill. Expert convergence: PreToolUse grep is false-positive-heavy and adds hot-path latency; unattended `claude -p` is a silent-corruption vector; n>=2 + decay is cargo-culted from spaced repetition without the right semantics. Cuts saved roughly 60 percent of the build surface and shifted writes from machine-trusted to user-reviewed.

Five expert adjustments accepted in v1: capture surrounding conversation context, per-entry status on the JSONL (approved/rejected/deferred), drop ExitPlanMode capture (payload too thin), drop "Rejected options" from the memory body (situational, not durable), define a conflict-handling rule (CLAUDE.md > feedback > question_and_answer_decision; distiller surfaces conflicts, never auto-writes). Statusline nudge was dropped because the user separately removed the usage statusline; `/close-out` is the natural cadence.

Wired distillation into `/close-out` as Step 5 (between Pencil demotion and the summary). Skill is also invocable standalone. Re-entrancy guard via `Q_AND_A_HOOK_DISABLE=1` env var so a future `claude -p` invocation cannot feed the loop back into itself.

macOS does not ship `flock`. Capture hook uses a Python `fcntl.flock` one-liner for the locked append. Verified with a 20-way parallel write that produced 20 distinct valid JSON lines.

### `[skill][expert-review]` Added `/expert-review` for fast three-LLM second opinions
Need: while collaborating with Claude on an idea, the user often wants an outside expert opinion before committing. The desired pattern is a panel: Claude, OpenAI, and Gemini each role-play the ideal expert for the situation, in parallel, and Claude distills their feedback into adjustments to the current direction.

Existing options considered and rejected:
- gstack `/codex` consult: only one outside opinion (OpenAI), no Gemini, no synthesis layer. Useful, but a single voice.
- gstack `/benchmark-models`: measures model performance on a prompt (latency, tokens, cost). Wrong purpose. That's model selection, not idea critique.
- gstack `/autoplan`: chains Claude reviewer personas (CEO, eng, design, DX). All same model, no outside opinion.

Chosen shape: skill auto-bundles recent conversation context, infers the ideal expert persona from that context (with optional user hint), composes one self-contained prompt, fans out in parallel to a Claude subagent + `codex exec` + `gemini -p`, saves all three responses to `/tmp/expert-review-<ts>/{claude,openai,gemini}.md`, and returns ONLY a concise synthesis of suggested adjustments. Full opinions surface only on follow-up request.

Lives in `public-claude-skills/` (not `gstack-extensions/`) because the skill has no gstack dependency: it just shells out to `codex` and `gemini` and uses the standard `Agent` tool. Publicly useful as a standalone pattern.

### `[skill][expert-review]` Dogfooded `/expert-review` on itself; six improvements + a real bug

Ran the skill against its own design as the first test. The panel of three (Claude subagent, OpenAI via codex, Gemini) surfaced six convergent adjustments and one live bug:

1. Output contract per expert should be fixed-field (thesis, key risks, assumptions, recommended next step, confidence 1-5), not free-form prose. Synthesis-of-prose is much worse than synthesis-of-comparable-fields.
2. Save `prompt.md` and `meta.json` alongside the three response files so a run is interpretable a day later.
3. Persona statement should offer one-line alternatives the user can swap to with a single reply, not just be stated as a fait accompli.
4. Synthesis must include a Steelman section when all three experts substantially agree. Three LLMs trained on overlapping data converging is the most likely silent failure mode.
5. Claude expert prompt needs an explicit independence line: it is a subagent with no shared context with the orchestrator and should push back on the orchestrator's framing rather than ratify it.
6. Prompt now requires evidence (concrete reasoning, lived experience, specific examples) and tells the expert that speculation belongs in Assumptions, not Key risks. Vague advice is the dominant failure mode otherwise.

Also: narrow carve-out from the original no-fourth-opinion rule. A `Synthesis-quality notes` section is now allowed in the output, scoped strictly to evidence quality, partial failures, and convergence concerns. Not for casting a vote on the underlying decision.

Live bug found during the run: `codex exec "<prompt>"` hangs indefinitely when stdin is open, even when the prompt is passed as a positional arg. The CLI tries to read additional input from stdin. Fix: always run as `codex exec "$(cat prompt.md)" < /dev/null`. Captured as a cross-project memory since any skill that shells out to codex will hit this.

Decisions deferred: no model pinning for the CLIs (use best available per provider), no per-model prompt wrappers (one shared prompt is fine for v1).

## 2026-05-14

### `[meta][repo]` Created the repo as a public home for standalone Claude Code skills
Existing layouts considered and rejected:
- `mj-claude` (the now-archived marketplace repo): plugin manifest + `/plugin marketplace add` flow felt heavyweight for what are single-file skills. Reads as "distribution platform" cosplay.
- Folding into `gstack-extensions`: the name implies "extends gstack", and these skills are standalone. Splitting personal skills across two repos by relationship-to-gstack is the right cut.
- Repo at `~/.claude/skills/public/`: couples the author's dotfile layout to other people's clone path. Optimizes for author over audience.

Chosen layout: flat directories at the repo root, each with a `SKILL.md`. No `skills/` wrapper since the repo *is* skills. `install.sh` symlinks every skill folder into `~/.claude/skills/`. Skill folders can also be copied directly with `cp -R <skill> ~/.claude/skills/` for users who want one without cloning the rest.

Local folder is `~/dev/public-claude-skills/`; GitHub repo is `mujtaba3B/claude-skills`. The "public-" local prefix is intentional: when a sibling `private-claude-skills/` exists later (for the `streak/` workflow), the pair will read symmetrically.

### `[skill][handoff-prompt]` First skill seeded into the repo
Moved `~/.claude/skills/handoff-prompt/` (real folder, no prior git home) into the repo. Replaced with a symlink via `install.sh`. Prior risk: skill existed only locally, would have been lost on laptop failure.

## 2026-05-15

### `[skill][close-out]` Added `/close-out` for end-of-session housekeeping
Need: after a substantive working session, decisions made in chat (the WHY) never make it to LOG.md, new files get added without an INDEX.md entry, new infra gets stood up without a memory note. The personal convention (CLAUDE.md / LOG.md / INDEX.md per repo) only pays off if it stays current; manual discipline was unreliable.

Existing options considered and rejected:
- `/document-release` from gstack: scoped to public release docs (README, CHANGELOG, VERSION bump). Wrong layer. The new skill is about *internal* project-keeping for a single working session, not release ceremony.
- `/end-sprint` from gstack: also includes `/document-release` plus retro/health/save. Too heavy for "I'm pausing for the day"; the per-session housekeeping is a smaller, more frequent need.
- One mega-skill that does close-out + handoff + context-save: would have overlapping triggers and unclear boundaries. Kept narrow.

Skill walks LOG.md (almost always), INDEX.md (only if new artifacts), CLAUDE.md (only if conventions changed), README.md (rarely), and persistent memory (only if new durable cross-session knowledge emerged). Also handles the Pencil `🚧 NEW NEW` mockup demotion sweep when both a `.pen` was touched AND a deploy happened.

Hard-codes the user's interaction style: one question at a time in the prominent `### ❓ QUESTION` format, no em-dashes, no batched lists. Seeded by dogfooding it on the mujtab.ai + namecheap-cli + cloudflare-token sprint where the absence of this discipline showed up as scattered LOG entries written defensively, mid-session.

### `[meta][protection]` Enabled branch protection on `main`
Initial pushes (both the repo init and the close-out skill addition) went straight to `main` with no PR. For a public repo where the README invites people to clone, that's a real gap: no CI gate, no commit-message style enforcement, no forced final read-through.

Enabled via `gh api -X PUT /repos/mujtaba3B/claude-skills/branches/main/protection` with: `required_pull_request_reviews` (count 0, so solo workflow still works), `required_conversation_resolution` true, `enforce_admins` false (so admin can override in emergencies), force pushes blocked, deletions blocked. From now on even solo work must go through a PR.

### `[skill][close-out]` v2: applied-first, no per-phase previews
Dogfooded the v1 skill on the close-out for this session. Three problems surfaced:
1. The skill previewed every drafted entry in a table and asked for approval at each phase. User wanted "do it and summarize at the end", not "preview, approve, apply, repeat".
2. Edits were applied sequentially across multiple repos, when parallel tool calls would have been faster.
3. The 7-phase structure encouraged ask-gates at every step instead of one batched apply.

Rewrote the skill: default mode is APPLY-FIRST, parallel tool calls everywhere, one-line summary at the end. Per-phase questions removed; only ask when a decision is genuinely ambiguous (e.g., "this LOG entry could go in repo A or B"). Added explicit anti-patterns covering sequential tool calls, re-reading files after edits, and previewing entries. Memory: see `close-out-no-preview`.
