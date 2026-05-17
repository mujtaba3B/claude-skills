---
name: handoff
description: Hand off the current work to a fresh agent or LLM. Two destinations: (default) spawn a fresh Claude session in a new vertical iTerm2 split, or (--copy flag) copy a self-contained handoff prompt to the macOS clipboard. Scope is inferred from args: bare invocation hands off the full session, trailing free-text args are treated as a sidequest topic and the handoff is scoped to that topic. Trigger when the user says "/handoff", "handoff", "hand off", "hand off to a new agent", "give me a handoff", "make me a handoff", "wrap this for a new agent", "fresh agent", "new claude", "spin up a sibling session", "sidequest", "fork this", "spin off", "I have a sidequest", "different rabbit hole", "/handoff-prompt", "handoff prompt", "copy a handoff", or "paste into ChatGPT / Gemini / another LLM". Replaces the legacy handoff-prompt skill.
---

# Handoff

Package up the work in this session as a self-contained prompt, then either spawn a fresh Claude session in a new vertical iTerm2 pane with it preloaded, or copy it to the clipboard so the user can paste it into another LLM (browser-based or otherwise).

---

## Step 1: Parse args

The user invokes as `/handoff [<args>]`. Args can include:

- The `--copy` flag, anywhere in args. Destination becomes clipboard. Without `--copy`, destination is "spawn a fresh Claude in a new vertical iTerm2 split".
- Free text, anything other than `--copy`. That free text is the sidequest topic, and the handoff prompt is scoped to that topic. Without free text, the handoff covers the full current session.

Scan args. Strip `--copy` if present (note the destination). Whatever remains, joined back into a single string, is the topic (may be empty).

Examples:

- `/handoff` -> spawn split, full-session handoff.
- `/handoff --copy` -> clipboard, full-session prompt.
- `/handoff fix the way we think about spec organization` -> spawn split, scoped to "fix the way we think about spec organization".
- `/handoff --copy explain the migration risk` -> clipboard, scoped to "explain the migration risk".
- `/handoff investigate flaky auth test --copy` -> same as `/handoff --copy investigate flaky auth test`.

Do NOT use `AskUserQuestion` to confirm the destination or scope. The args are the answer. If args are genuinely ambiguous (rare), bias toward the inferred mode and mention it in the final confirmation so the user can rerun if wrong.

---

## Step 2: Terminal detection (only if destination is spawn)

If the destination is spawn (no `--copy`), check the environment via Bash:

```bash
echo "$TERM_PROGRAM"
```

If the value is not `iTerm.app`, silently fall back: switch destination to clipboard, and note in the final confirmation line: "Not in iTerm2 (TERM_PROGRAM=<value>), copied to clipboard instead."

If the value is `iTerm.app`, proceed with spawn.

---

## Step 3: Synthesize the handoff prompt

Build a self-contained prompt that lets a fresh agent pick up without seeing this conversation. Pull from the actual session contents, not from imagination.

Cover these sections, only including ones that are real for the current session:

- **Context paths**: project CLAUDE.md, LOG.md, INDEX.md, MEMORY.md, cross-project CLAUDE.md, global `~/.claude/CLAUDE.md`. List the ones that exist and are relevant.
- **Working files**: paths to the specific files being edited (code, .pen mockups, design docs). Include node IDs, function names, and line numbers when they are load-bearing.
- **What's been done so far**: concrete diff summary, not narration. "Changed X from A to B", not "we discussed changing X".
- **Conventions in effect**: any session-specific or project-specific rules the next agent must respect (em-dash rule, mockup conventions, button styles, design tool defaults, etc.). Pull from active CLAUDE.md files and MEMORY.md.
- **Open questions / decisions pending**: anything flagged by the previous agent or that the user has not yet decided.
- **Your task**: what the receiving agent should actually do.

Scoping rules:

- **Full-session mode** (no topic in args): "Your task" reads "pick up where the previous agent left off and continue the same work in this directory." All other sections cover the full session, comprehensively.
- **Sidequest mode** (topic in args): "Your task" is the user's topic verbatim (do not paraphrase). All other sections are filtered to context relevant to that topic only. Drop main-quest material that has no bearing on the sidequest. The receiving agent is going on the sidequest while the user keeps doing the main work in this pane.

Hard rules for the prompt body:

- No em-dash characters (`—`, Unicode U+2014). Use periods, commas, colons, semicolons, parens, or hyphens.
- Self-contained. A fresh agent reading only this prompt should be able to start work. No "see above", no "as we discussed".
- Absolute file paths, not relative. Exact node IDs / symbol names.
- Do not paraphrase the user's topic when they provided one. Quote it.
- Do not include the conversation history. Distill it.

---

## Step 4: Dispatch

### Clipboard path (`--copy` or non-iTerm fallback)

Write the prompt to a heredoc piped to `pbcopy`. Use the single-quoted delimiter (`'EOF'`) so backticks, dollar signs, and other shell metacharacters in the prompt do not get interpreted. If the prompt itself contains a literal `EOF` line, switch the delimiter to `'HANDOFF_EOF'`.

```bash
cat <<'EOF' | pbcopy
<the handoff prompt>
EOF
echo "Copied $(pbpaste | wc -c | tr -d ' ') chars to clipboard"
```

### Spawn path (default, in iTerm2)

Write the prompt to a temp file, then invoke the spawn helper:

```bash
TMPFILE=$(mktemp /tmp/handoff-prompt.XXXXXX)
cat > "$TMPFILE" <<'EOF'
<the handoff prompt>
EOF
~/.claude/skills/handoff/spawn.sh "$TMPFILE"
```

The helper script handles iTerm2 AppleScript split-and-launch: it reads the prompt from the file, captures the invoking iTerm session, splits it vertically, and launches `claude "<prompt>"` as the new session's startup command (no `write text` race). It also inherits `--dangerously-skip-permissions` if any ancestor process has it (so a YOLO-mode parent spawns YOLO-mode children).

Use the same `'HANDOFF_EOF'` swap rule for the temp-file heredoc if the prompt contains a literal `EOF` line.

---

## Step 5: Confirm

One short line. Pick the right variant:

- Clipboard, full session: `Copied N chars to clipboard. Paste into a fresh agent with Cmd+V.`
- Clipboard, sidequest: `Copied N chars to clipboard, scoped to: <topic>. Paste with Cmd+V.`
- Clipboard fallback (not iTerm): `Not in iTerm2 (TERM_PROGRAM=<value>), copied N chars to clipboard instead. Paste with Cmd+V.`
- Spawn, full session: `Spawned fresh Claude in new iTerm pane with full session context.`
- Spawn, sidequest: `Spawned fresh Claude in new iTerm pane, scoped to: <topic>. Main quest is still here.`

Do not print the full prompt back to the user. They have it on the clipboard or in the new pane; reprinting is clutter.
