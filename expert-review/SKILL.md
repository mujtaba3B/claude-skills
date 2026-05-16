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

State the chosen persona to the user in one line before fanning out, so they can redirect if it's off:

> Sending this to three experts as a *<persona>*. Fanning out now.

Don't ask for approval, just state it. The user can interrupt if wrong.

---

## Step 3: Build the prompt that goes to all three experts

Compose one self-contained prompt. All three experts receive the **same** prompt. It must include:

1. **Role**: "You are a <persona>. You are giving a second opinion to another engineer."
2. **Context**: a distilled version of what's happening. Include the subject, the current direction, the constraints, any relevant file paths or code snippets. The expert has not seen this conversation, so the prompt must stand alone.
3. **The question**: what specifically should they evaluate? Usually some form of "Critique the current approach. Where would you push back? What are we likely getting wrong? What would you do differently and why?"
4. **Output shape**: ask for a structured response so synthesis is easier. Suggested shape:
   - **Verdict** (1-2 sentences): is the current direction sound, partially sound, or off?
   - **Top adjustments** (bulleted): the highest-leverage changes they'd recommend, each with a one-line *why*.
   - **Risks the current plan underweights** (bulleted, optional).
   - **What they'd want to know more about before committing** (bulleted, optional).
5. **Length cap**: ask for under ~500 words. Concise is the point.

Hard rules for the prompt itself:
- No em-dashes (project-wide rule).
- Self-contained: a fresh expert reading only this prompt should be able to weigh in. No "as discussed" or "see above".
- Include exact file paths when they're load-bearing.
- Don't paraphrase the user's words if they expressed something specific. Quote them.

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
```

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

**Where the experts converge:**
- <bullet> . <one-line why this matters for the current direction>
- <bullet>
- ...

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
```

Rules for the synthesis:
- Be concise. Aim for under ~300 words total.
- Translate expert recommendations into *adjustments to what the user is currently doing*, not abstract advice.
- Do NOT paste verbatim expert text. Distill.
- If an expert recommendation conflicts with a known project constraint (something in CLAUDE.md, MEMORY.md, a locked-in choice), flag it and lean toward the constraint.
- No em-dashes.
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
- Add a fourth opinion of your own to the synthesis as if it were a peer of the three. Your role is to distill, not to vote.
- Use em-dashes anywhere (including inside the prompt sent to the experts, since their output may be quoted later).
- Skip the persona-statement line in Step 2. The user needs a chance to redirect before tokens are spent.
