---
name: expert-review
description: Get a fast second opinion on the current approach from three LLM experts in parallel (Claude, OpenAI via codex, Gemini). Infers the ideal expert persona for the situation from the conversation context plus any hint the user provides, fans out the same prompt to all three, saves the full opinions to disk, and returns a concise synthesis of suggested adjustments to the current direction. Trigger when the user says "/expert-review", "expert review", "get a second opinion", "panel of experts", "what would experts think", "stress test this idea", or any variant of "have three LLMs weigh in on this".
---

# Expert Review

Spawns three LLM "experts" in parallel (Claude, OpenAI via `codex`, Gemini via `gemini`) to give a second opinion on the current approach. Returns a concise synthesis of the adjustments they'd recommend, not the raw opinions. Full opinions are saved to disk for follow-up.

The goal is to make the human's next decision better-informed, not to produce a wall of text.

---

## Step 1: Figure out what's being reviewed

Look at the current conversation. Identify:

- **The subject**: what idea, plan, design, schema, approach, or artifact is under consideration? Be specific. If the user passed extra context inline with `/expert-review <stuff>`, that's a strong signal about scope.
- **The current direction**: what is the user about to do, or leaning toward? This is what the experts are evaluating.
- **Constraints in play**: deadlines, tech choices already locked in, conventions (em-dash rule, design tool preference, project-specific CLAUDE.md rules), things the user has ruled out.

If the subject is genuinely unclear, ask once before fanning out:

```
---

### ❓ QUESTION

> What specifically should the experts evaluate? (the recent design idea, the plan in <file>, a specific decision point, etc.)

---
```

Otherwise skip the question. Don't ask just to confirm something obvious.

---

## Step 2: Infer the ideal expert persona

Based on the subject, decide what kind of expert is ideal. Examples:

- Database schema decision: "senior database architect with deep Postgres operational experience"
- React component design: "staff frontend engineer specializing in React performance and accessibility"
- API contract: "API designer with experience in long-lived public APIs and versioning"
- Product scoping: "experienced startup product lead who has shipped 0-to-1 products"
- Infrastructure / deploy: "site reliability engineer with production incident experience"

If the user passed a hint like `/expert-review focus on security tradeoffs`, weave that into the persona. If they passed a full persona, use it verbatim.

State the chosen persona to the user, and offer one or two one-line alternatives they can swap to with a single reply. This way they can redirect without cancelling:

```
Persona: *<chosen persona>*.
Alternatives if this is off: (a) <one-line alt>, (b) <one-line alt>.
Fanning out now unless you swap.
```

Don't actually wait for an answer. Print this and proceed in the same turn. If the user replies with a swap before the fan-out completes, you'll catch it in the next turn. (For long sessions, persona inference is often the weakest step; the swap escape valve costs nothing.)

---

## Step 3: Build the prompt that goes to all three experts

Compose one self-contained prompt. All three experts receive the **same** prompt. It must include:

1. **Role**: "You are a <persona>. You are giving a second opinion to another engineer."
2. **Context**: a distilled version of what's happening. Include the subject, the current direction, the constraints, any relevant file paths or code snippets. The expert has not seen this conversation, so the prompt must stand alone.
3. **The question**: what specifically should they evaluate? Usually some form of "Critique the current approach. Where would you push back? What are we likely getting wrong? What would you do differently and why?"
4. **Output contract** (fixed fields, in this order, so synthesis can compare like-for-like):
   - **Thesis** (1-2 sentences): the expert's bottom-line take on the current direction.
   - **Key risks** (bulleted): the things most likely to go wrong, each with a one-line *why*.
   - **Assumptions** (bulleted): assumptions the expert is making that, if wrong, would change their take.
   - **Recommended next step** (1-3 sentences): the most useful next concrete action.
   - **Confidence** (1-5 integer): how confident the expert is in their thesis, where 1 = wild guess and 5 = would stake reputation.
5. **Evidence requirement**: tell the expert explicitly that claims should be backed by concrete reasoning, lived experience, or specific examples. Vague or generic advice ("consider scalability", "watch performance") is not useful. If the expert is uncertain or speculating, they should say so in the Assumptions section rather than dressing it up as a Key Risk.
6. **Length cap**: ask for under ~500 words. Concise is the point.

Hard rules for the prompt itself:
- No em-dashes (project-wide rule).
- Self-contained: a fresh expert reading only this prompt should be able to weigh in. No "as discussed" or "see above".
- Include exact file paths when they're load-bearing.
- Don't paraphrase the user's words if they expressed something specific. Quote them.
- For the Claude expert specifically: add an extra line to the prompt instructing it that it is a fully independent subagent with no shared context with the orchestrator, and it should actively push back on the orchestrator's framing rather than ratify it. This is the cheapest defense against agreement theater.

---

## Step 4: Fan out in parallel

Create a timestamped output directory, write the composed prompt to a file, and run all three experts concurrently.

```bash
TS=$(date +%Y%m%d-%H%M%S)
DIR="/tmp/expert-review-$TS"
mkdir -p "$DIR"
# Write the composed prompt to a file (this avoids shell-quoting issues with
# multi-line prompts containing quotes, backticks, and $-signs).
cat > "$DIR/prompt.md" <<'PROMPT_EOF'
<the full composed prompt from Step 3 goes here>
PROMPT_EOF
# Save run metadata so this run is interpretable later.
cat > "$DIR/meta.json" <<META_EOF
{
  "timestamp": "$TS",
  "persona": "<the chosen persona, one line>",
  "subject": "<one-line description of what was reviewed>",
  "experts": ["claude", "openai", "gemini"]
}
META_EOF
```

After each expert's bash call completes, append an entry to `$DIR/meta.json` (or a sibling `results.json`) capturing its exit code and elapsed time. Skip if it adds friction; the timestamps and exit codes from the tool results are enough to reconstruct after the fact.

**Then print a one-line status update to the user before fanning out**, so they can see what's about to happen:

> Spawning three experts in parallel: Claude (subagent), OpenAI (codex), Gemini (gemini). Saving to `/tmp/expert-review-<TS>/`. Status will print as each lands.

Then in **one assistant turn**, make three tool calls in parallel:

- **Claude expert**: use the `Agent` tool with `subagent_type: "general-purpose"`. Pass the full composed prompt as `prompt`. Instruct the agent in the prompt itself to write its final response to `$DIR/claude.md` and also return it as the tool result.
- **OpenAI expert**: `Bash` tool, `run_in_background: true`, command:
  ```bash
  codex exec "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/openai.md" 2>&1
  ```
  The `< /dev/null` is **required**: `codex exec` reads stdin for additional input even when a prompt arg is provided, and will hang on an open stdin. Reading the prompt from a file (via `cat`) avoids any quoting/escaping bugs that arise from passing multi-line strings as shell arguments.
- **Gemini expert**: `Bash` tool, `run_in_background: true`, command:
  ```bash
  gemini -p "$(cat "$DIR/prompt.md")" < /dev/null > "$DIR/gemini.md" 2>&1
  ```

Both bash calls run in the background so the user can see them spawn immediately. Use a 5-minute timeout (300000ms) if you ever switch them to foreground.

### Progress visibility

After the parallel kickoff, the user wants to know things are working. Do this:

1. Immediately after the three tool calls fire, print a status line listing the three experts and noting they are running in parallel.
2. As each one completes (the Agent returns; each background Bash sends a completion notification), print a one-liner:
   > `Claude: done (42s, 3.1 KB)`
   > `Gemini: done (19s, 2.4 KB)`
   > `OpenAI: still running...`
3. If any expert is still running after the first two land, mention it explicitly so the user knows you are waiting on it, not stuck. Do **not** poll or sleep manually. You will be notified automatically when a background Bash completes.
4. If any expert fails (non-zero exit, timeout, or stderr-only output), print the failure on its own line and continue with the rest. Do not block synthesis on it.

If any single expert fails or times out, continue with the others. Note the failure in the synthesis explicitly ("Gemini timed out") rather than producing a confident two-expert consensus that reads like three.

---

## Step 5: Read the three opinions and synthesize

Read all three result files. Produce a concise synthesis for the user. The synthesis is the only thing shown by default. Structure:

```
**Persona used:** <one line>

**Confidence:** Claude <1-5>, OpenAI <1-5>, Gemini <1-5>. <One-line read on whether they were sure or hedging.>

**Where the experts converge:**
- <bullet> . <one-line why this matters for the current direction>
- <bullet>
- ...

**Steelman against the consensus** (only include this section if all three substantially agree):
- <one short paragraph: what would the strongest case AGAINST the convergent view look like? Mention if any expert flagged this themselves, or note that none did.>

**Where they disagree (and which side seems stronger here):**
- <topic> . <one side> vs <other side>. <one-line take on which matters given the user's constraints>
- ...

**Suggested adjustments to the current plan:**
1. <concrete change, one line>
2. <concrete change, one line>
3. ...

**Things you may want to decide before continuing:**
- <open question the experts surfaced>
- ...

**Synthesis-quality notes** (optional, only if warranted):
- <e.g., "All three responses were polished but evidence-light. Treat as priors, not data."> <or> <e.g., "Gemini timed out. This is a two-expert synthesis.">
```

Rules for the synthesis:
- Be concise. Aim for under ~300 words total.
- Translate expert recommendations into *adjustments to what the user is currently doing*, not abstract advice.
- Do NOT paste verbatim expert text. Distill.
- If an expert recommendation conflicts with a known project constraint (something in CLAUDE.md, MEMORY.md, a locked-in choice), flag it and lean toward the constraint.
- No em-dashes.
- The **Steelman against the consensus** section is required when all three experts substantially agree on the same direction. Convergence-bias is the most likely failure mode: three LLMs trained on overlapping data agreeing is not the same as three humans agreeing. Write a short, honest counter-case, even if you have to construct it yourself.
- The **Synthesis-quality notes** section is the only place where you may add an orchestrator-side observation. Scope it tightly: flag evidence quality, partial failures, or convergence concerns. Do **not** add a new substantive opinion on the underlying decision. Your job is to distill, not to vote.
- End with a one-line footer pointing to the saved files:

> Full opinions saved to `/tmp/expert-review-<TS>/`. Say "show me what Gemini said" (or claude / openai) for the verbatim response.

---

## Step 6: Handle follow-up requests for full opinions

If the user later asks for the full opinion of a specific expert ("show me the OpenAI one", "what did Gemini actually say", etc.), read the corresponding file from the saved directory and print it verbatim. Don't summarize a second time.

If the user asks a follow-up question that would benefit from re-querying the experts (e.g. "ask them about <specific tradeoff>"), compose a new focused prompt and run Step 4 again, reusing the same persona unless context has shifted.

---

## Anti-patterns

Do not:
- Run the experts sequentially. They are independent. Parallel is the point.
- Show the verbatim opinions unless asked.
- Let one expert's failure block the others.
- Add a fourth substantive opinion on the underlying decision. The narrow `Synthesis-quality notes` section is allowed, but it is for evidence quality, failures, and convergence concerns only, not for casting your own vote on the decision.
- Use em-dashes anywhere (including inside the prompt sent to the experts, since their output may be quoted later).
- Skip the persona-statement line in Step 2. The user needs a chance to redirect before tokens are spent.
- Skip the steelman section when all three agree. Convergence among LLMs trained on overlapping data is the most likely silent failure mode.
