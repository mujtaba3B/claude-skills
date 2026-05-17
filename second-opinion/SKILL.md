---
name: second-opinion
description: Get a second opinion on the current approach from another LLM. Four modes, a single second opinion from Claude (subagent), Codex (OpenAI), or Gemini, or a panel of all three in parallel for cross-model consensus. Infers the ideal expert persona from the conversation, composes a self-contained prompt, fans out, saves full opinions to disk, returns a concise synthesis. Trigger when the user says "/second-opinion", "second opinion", "get me a second opinion", "ask codex", "ask gemini", "ask claude" (in a second-opinion sense), "panel of experts", "expert review", "what would experts think", "stress test this idea", or any variant of "have another LLM weigh in".
---

# Second Opinion

One skill, four modes. The goal is to make the human's next decision better-informed, not produce a wall of text.

- **claude**: one Claude subagent (Agent tool, `general-purpose`).
- **codex**: one OpenAI opinion via `codex exec`.
- **gemini**: one Gemini opinion via `gemini -p`.
- **panel**: all three in parallel for cross-model consensus.

Single-expert modes are fast and sharp. Panel mode is slower and costlier but catches blind spots a single model would miss. Pick the right tool for the question.

---

## Step 0: Resolve the mode

Determine the mode in this order:

1. **Explicit slash arg.** `/second-opinion <mode> [hint]`. If the first token is `claude`, `codex`, `gemini`, or `panel`, that is the mode. Rest of the line is a persona/scope hint to weave into Step 2.
2. **Unambiguous trigger phrase.** Examples that resolve without asking:
   - "ask codex", "what does codex think" → `codex`
   - "ask gemini", "run it by gemini" → `gemini`
   - "ask claude for a second opinion", "claude subagent opinion" → `claude`
   - "panel of experts", "expert review", "all three", "stress test this idea" → `panel`
3. **Ambiguous invocation, only then ask.** Bare `/second-opinion`, "get me a second opinion", "what would experts think", "have another LLM weigh in" do not name a mode. Use `AskUserQuestion` with the four options listed neutrally (no "recommended" pre-selection: panel is the most expensive path and should not be nudged by default):

   - Question header: `Mode`
   - Question: "Which second opinion do you want?"
   - Options:
     - `Panel of all three` (Claude + Codex + Gemini in parallel)
     - `Claude` (single subagent)
     - `Codex` (single OpenAI opinion)
     - `Gemini` (single Gemini opinion)

Do not ask when the mode is already unambiguous. Every unnecessary confirmation trains users away from the skill.

---

## Step 1: Figure out what's being reviewed

Look at the current conversation. Identify:

- **The subject**: what idea, plan, design, schema, or artifact is under consideration. If the user passed extra context inline (e.g., `/second-opinion codex focus on Postgres ops`), that scopes it.
- **The current direction**: what the user is leaning toward. This is what gets evaluated.
- **Constraints in play**: deadlines, locked-in tech choices, conventions (em-dash rule, design tool preference, project-specific CLAUDE.md rules), things ruled out.

If the subject is genuinely unclear, ask once before fanning out:

```
---

### ❓ QUESTION

> What specifically should the expert evaluate? (the recent design idea, the plan in <file>, a specific decision point, etc.)

---
```

Otherwise skip the question. Do not ask just to confirm something obvious.

---

## Step 2: Infer the ideal expert persona

Based on the subject, decide what kind of expert is ideal. Examples:

- Database schema: "senior database architect with deep Postgres operational experience"
- React component design: "staff frontend engineer specializing in React performance and accessibility"
- API contract: "API designer with experience in long-lived public APIs and versioning"
- Product scoping: "experienced startup product lead who has shipped 0-to-1 products"
- Infrastructure / deploy: "site reliability engineer with production incident experience"

If the user passed a hint, weave it into the persona. If they passed a full persona, use it verbatim.

State the chosen persona to the user and offer one or two one-line alternatives they can swap to with a single reply:

```
Persona: *<chosen persona>*.
Alternatives if this is off: (a) <one-line alt>, (b) <one-line alt>.
Fanning out now unless you swap.
```

Print this and proceed in the same turn; do not actually wait. Persona inference is the weakest step in long sessions; the swap escape valve costs nothing.

---

## Step 3: Compose the prompt

One self-contained prompt. In panel mode, all three experts receive the same prompt. The prompt must include:

1. **Role**: "You are a <persona>. You are giving a second opinion to another engineer."
2. **Context**: distilled version of what's happening. Subject, current direction, constraints, relevant file paths or code snippets. The expert has not seen the conversation; the prompt must stand alone.
3. **The question**: usually "Critique the current approach. Where would you push back? What are we likely getting wrong? What would you do differently and why?"
4. **Output contract** (fixed fields, in this order, so single and panel synthesis can both compare like-for-like):
   - **Thesis** (1-2 sentences): bottom-line take on the current direction.
   - **Key risks** (bulleted): things most likely to go wrong, each with a one-line *why*.
   - **Assumptions** (bulleted): assumptions the expert is making that, if wrong, would change their take.
   - **Recommended next step** (1-3 sentences): the most useful next concrete action.
   - **Confidence** (1-5 integer): 1 = wild guess, 5 = would stake reputation.
5. **Evidence requirement**: claims must be backed by concrete reasoning, lived experience, or specific examples. Vague advice ("consider scalability", "watch performance") is not useful. Speculation goes in Assumptions, not Key risks.
6. **Length cap**: under ~500 words. Concise is the point.

Hard rules for the prompt itself:

- **No em-dashes** (project-wide rule). The expert's output may be quoted downstream.
- **Self-contained**: no "as discussed", no "see above". A fresh expert reading only this prompt should be able to weigh in.
- Include exact file paths when load-bearing.
- Do not paraphrase the user's words when they expressed something specific. Quote them.
- **Claude expert anti-sycophancy line** (panel mode or single-claude mode): add an extra line instructing the subagent that it has no shared context with the orchestrator and should actively push back on the orchestrator's framing rather than ratify it. Cheapest defense against agreement theater.

---

## Step 3.5: CLI staleness check (24h TTL)

Before dispatch, check whether `codex` and `gemini` are on the latest npm-published version. This applies to **every mode**, including `claude` (panel uses both CLIs, and even single-`claude` runs are often followed by single-codex/gemini follow-ups in the same session).

Gated by a 24-hour TTL via a flag file at `~/.claude/.second-opinion-cli-check`. The hot path reads the flag and skips the check 99% of the time; the network call only runs when the TTL has expired.

### Run this block as the staleness check

```bash
FLAG="$HOME/.claude/.second-opinion-cli-check"
NOW=$(date +%s)
LAST=$(cat "$FLAG" 2>/dev/null || echo 0)
AGE=$((NOW - LAST))
if [ "$AGE" -lt 86400 ]; then
  echo "stale-check: skipped (within 24h TTL)"
  exit 0
fi

# TTL expired. Touch the flag NOW so a failed network call does not retry-loop.
echo "$NOW" > "$FLAG"

check_one() {
  local pkg="$1"; local cmd="$2"
  local installed latest
  installed=$("$cmd" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  latest=$(timeout 2 npm view "$pkg" version 2>/dev/null)
  if [ -z "$installed" ] || [ -z "$latest" ]; then
    return 0  # silent fail: cannot determine, do not block dispatch
  fi
  if [ "$installed" != "$latest" ]; then
    echo "STALE|$cmd|$installed|$latest|$pkg"
  fi
}

# Run both checks in parallel and capture stale lines.
check_one "@openai/codex" "codex" > /tmp/.so-codex-check &
check_one "@google/gemini-cli" "gemini" > /tmp/.so-gemini-check &
wait
cat /tmp/.so-codex-check /tmp/.so-gemini-check 2>/dev/null
rm -f /tmp/.so-codex-check /tmp/.so-gemini-check
```

### Handle the output

If the block prints nothing (or only "stale-check: skipped"), proceed silently to Step 4. Do not surface the check to the user.

If one or more `STALE|...` lines are present, print a one-line warning per stale CLI:

> `codex: installed 0.130.0 → latest 0.131.0. Upgrade: npm install -g @openai/codex@latest`

Then use `AskUserQuestion` with one question, three options:

- Question header: `Upgrade`
- Question: "One or more CLIs are behind. Upgrade now before dispatching?"
- Options:
  - `Upgrade now` (run `npm install -g <pkg>@latest` for each stale CLI synchronously, verify the new `--version`, then dispatch)
  - `Skip and dispatch with current` (proceed to Step 4 unchanged)
  - `Defer (do not ask again for 24h)` (proceed to Step 4; the touched flag already silences this for the TTL window)

If `Upgrade now` is chosen, run the installs **synchronously**, in a single command (e.g. `npm install -g @openai/codex@latest @google/gemini-cli@latest` if both are stale). Do NOT background the install. A mid-dispatch global npm install can change the binary the current run is about to use; that is a footgun, not a feature. After install completes, re-read `<cli> --version` and confirm it matches latest before dispatching. If the install fails, surface the error and ask whether to proceed with the old CLI or abort.

### Hot-path latency

When the TTL is fresh (the common case), this step is one `cat` of a tiny file: sub-millisecond. When the TTL has expired (at most once per 24h), the worst case is two `npm view` calls in parallel with 2s timeouts, so ~2s. Acceptable as a once-a-day cost.

### Anti-patterns specific to this step

- Do not run `npm view` on the hot path without the TTL gate. That is the failure mode the experts warned about.
- Do not fail closed on network errors. The `timeout 2` plus empty-string check above means a flaky registry results in "could not determine staleness", not "skill cannot dispatch".
- Do not write the upgrade itself as a background task. Synchronous or not at all.
- Do not parse "minor versions behind" or compute version deltas. `0.x` packages do not honor semver minor-bump semantics; just show installed vs latest and let the user judge.

---

## Step 4: Dispatch (mode-aware)

Create a timestamped output directory keyed on the mode, write the prompt to a file, write run metadata, then dispatch.

```bash
TS=$(date +%Y%m%d-%H%M%S)
MODE=<claude|codex|gemini|panel>
DIR="/tmp/second-opinion-$MODE-$TS"
mkdir -p "$DIR"
cat > "$DIR/prompt.md" <<'PROMPT_EOF'
<the full composed prompt from Step 3>
PROMPT_EOF
cat > "$DIR/meta.json" <<META_EOF
{
  "timestamp": "$TS",
  "mode": "$MODE",
  "persona": "<one line>",
  "subject": "<one line>"
}
META_EOF
```

Print a one-line status update before fanning out so the user sees what is about to happen, then dispatch in **one assistant turn**:

### Mode: `panel`

Three tool calls in parallel:

- **Claude expert**: `Agent` tool, `subagent_type: "general-purpose"`. Pass the prompt. Instruct the agent in the prompt itself to write its final response to `$DIR/claude.md` and also return it as the tool result.
- **OpenAI expert**: `Bash`, `run_in_background: true`:
  ```bash
  codex exec --skip-git-repo-check "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/openai.md" 2>&1
  ```
  Both flags are load-bearing. `< /dev/null` prevents `codex exec` from hanging on open stdin. `--skip-git-repo-check` lets codex run from `/tmp` (it refuses untrusted directories otherwise). Reading the prompt from a file via `cat` avoids quoting bugs with multi-line content.
- **Gemini expert**: `Bash`, `run_in_background: true`:
  ```bash
  gemini -p "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/gemini.md" 2>&1
  ```

### Mode: `claude`

Single `Agent` call (`subagent_type: "general-purpose"`), same prompt, write to `$DIR/claude.md` and return as tool result. Foreground; the orchestrator is already waiting on one thing.

### Mode: `codex`

Single foreground `Bash` call (5-minute timeout):

```bash
codex exec --skip-git-repo-check "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/openai.md" 2>&1
```

### Mode: `gemini`

Single foreground `Bash` call (5-minute timeout):

```bash
gemini -p "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/gemini.md" 2>&1
```

### Progress visibility (panel mode only)

After the parallel kickoff, print a status line listing the three experts. As each completes (Agent returns; background Bash sends a completion notification), print a one-liner:

> `Claude: done (42s, 3.1 KB)`
> `Gemini: done (19s, 2.4 KB)`
> `OpenAI: still running...`

Do not poll or sleep manually; background-Bash completion notifications fire automatically. If any expert fails (non-zero exit, timeout, stderr-only output), print the failure on its own line and continue with the rest. Do not block synthesis on a failure: a two-expert synthesis labelled as such is more honest than a stalled one.

---

## Step 5: Synthesize

Two templates. Choose by mode.

### Panel template (mode == panel)

Read all three result files. Produce a concise synthesis (under ~300 words):

```
**Persona used:** <one line>

**Confidence:** Claude <1-5>, OpenAI <1-5>, Gemini <1-5>. <One-line read on whether they were sure or hedging.>

**Where the experts converge:**
- <bullet>. <one-line why this matters for the current direction>
- ...

**Steelman against the consensus** (required when all three substantially agree):
- <one short paragraph: strongest case AGAINST the convergent view. Note if any expert flagged this themselves or if none did.>

**Where they disagree (and which side seems stronger here):**
- <topic>. <one side> vs <other side>. <one-line take on which matters given the user's constraints>
- ...

**Suggested adjustments to the current plan:**
1. <concrete change>
2. ...

**Things you may want to decide before continuing:**
- <open question the experts surfaced>
- ...

**Synthesis-quality notes** (optional, only if warranted):
- <e.g., "All three were polished but evidence-light. Treat as priors, not data."> <or> <e.g., "Gemini timed out. This is a two-expert synthesis.">
```

The **Steelman** section is required when all three substantially agree. Convergence-bias is the most likely failure mode: three LLMs trained on overlapping data agreeing is not three humans agreeing. Write a short honest counter-case, even if you have to construct it yourself.

### Single-expert template (mode == claude | codex | gemini)

Read the one result file. Produce a sharp critique (under ~250 words):

```
**Persona used:** <one line>

**Expert:** <Claude | Codex | Gemini>. **Confidence:** <1-5>. <One-line read on whether confident or hedging.>

**Thesis:** <the expert's bottom-line take, distilled.>

**Key risks:**
- <risk>. <one-line why>
- ...

**Suggested adjustments to the current plan:**
1. <concrete change>
2. ...

**Things you may want to decide before continuing:**
- <open question the expert surfaced>
- ...

**Steelman** (optional, include only when the expert was strongly opinionated):
- <strongest case AGAINST the expert's thesis.>
```

Keep `Key risks` in the single template. A second opinion that does not name failure modes is just a summary.

### Synthesis rules (both templates)

- Translate expert recommendations into *adjustments to what the user is currently doing*, not abstract advice.
- Do NOT paste verbatim expert text. Distill.
- If a recommendation conflicts with a known project constraint (CLAUDE.md, MEMORY.md, a locked-in choice), flag it and lean toward the constraint.
- No em-dashes.
- `Synthesis-quality notes` (panel only) is the only place to add an orchestrator-side observation. Scope it tightly: evidence quality, partial failures, convergence concerns. Do not cast your own vote on the underlying decision. Your job is to distill, not to vote.
- End with a one-line footer pointing to the saved files:

> Full opinion saved to `/tmp/second-opinion-<mode>-<TS>/`. Say "show me what <Claude|Codex|Gemini> said" for the verbatim response.

---

## Step 6: Follow-ups

If the user asks for the full opinion of a specific expert ("show me the OpenAI one", "what did Gemini actually say"), read the file from the saved directory and print it verbatim. Do not summarize a second time.

If the user asks a follow-up that benefits from re-querying ("ask them about <specific tradeoff>"), compose a new focused prompt and run Step 4 again, reusing the same persona unless context has shifted. Mode may change too: a panel run can be followed by a single-expert deep-dive on the dimension that mattered.

---

## Anti-patterns

Do not:

- Ask `AskUserQuestion` when the mode is already unambiguous. Slash args and "ask codex"-style phrases resolve directly to Step 1.
- Pre-recommend Panel in the `AskUserQuestion` options. It is the most expensive path; listing it first or marking it "recommended" creates a quiet cost trap.
- Run panel experts sequentially. They are independent. Parallel is the point.
- Show verbatim opinions unless asked.
- Let one expert's failure block the others.
- Add a fourth substantive opinion on the underlying decision. The narrow `Synthesis-quality notes` section (panel only) is allowed for evidence quality, failures, and convergence concerns. Not for casting your own vote.
- Use em-dashes anywhere, including inside the prompt sent to the experts (their output may be quoted later).
- Skip the persona-statement line in Step 2. The user needs a chance to redirect before tokens are spent.
- Skip the Steelman section (panel) when all three agree. Convergence among LLMs trained on overlapping data is the most likely silent failure mode.
