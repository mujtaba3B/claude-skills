---
name: handoff-prompt
description: Generate a handoff prompt that a fresh agent can pick up from. Snapshots the current task, decisions, file paths, conventions, and open questions into a self-contained prompt and copies it to the clipboard so the user can paste it into a new agent session with Cmd+V. Trigger when the user says "/handoff-prompt", "handoff prompt", "hand off to a new agent", "give me a handoff", "make me a handoff", "wrap this for a new agent", or any variant of "I want to hand this off to another agent".
---

# Handoff Prompt

This skill produces a self-contained prompt that lets a fresh agent (Claude, Codex, Cursor, anything) pick up the current task without seeing this conversation. The output goes to the macOS clipboard so the user can paste it directly into the new agent's input.

---

## Step 1: Ask if there's anything special about this handoff

Use AskUserQuestion to ask one focused question:

> Anything specific to add to the handoff (a particular task for the next agent, files they should focus on, things to skip)? If not, default is a snapshot of the current state.

Offer two options:
1. "Default snapshot" (recommended) - just capture the current state of the work.
2. "I have extra context" - user provides what to emphasize, what the next agent's job is, what to avoid.

If the user picks "I have extra context", let them write it freely. Take whatever they say verbatim and weave it into the prompt's "Your task" section.

If they pick the default, frame the handoff as a generic continuation: "pick up where the previous agent left off and continue the same work."

---

## Step 2: Build the handoff prompt

Synthesize the prompt from what's actually in this conversation. Cover these sections, only including ones that are real:

- **Context paths**: project CLAUDE.md, LOG.md, INDEX.md, MEMORY.md, cross-project CLAUDE.md, global ~/.claude/CLAUDE.md. List the ones that exist and are relevant.
- **Working files**: paths to the specific files being edited (code, .pen mockups, design docs). Include node IDs / function names / line numbers when they are load-bearing.
- **What's been done so far**: concrete diff summary, not narration. "Changed X from A to B" not "we discussed changing X".
- **Conventions in effect**: any session-specific or project-specific rules that the next agent must respect (em-dash rule, mockup conventions, button styles, etc.). Pull from the active CLAUDE.md files and MEMORY.md.
- **Open questions / decisions pending**: anything the previous agent flagged or that the user has not yet decided.
- **Your task** (for the new agent): either the user's extra context from Step 1, or a generic "continue the work in progress" instruction.

Hard rules for the prompt body:

- No em-dashes. Period.
- Self-contained: a fresh agent reading only this prompt should be able to start work. Don't write "see above" or "as we discussed" - the new agent has no "above" and was not in the discussion.
- Include exact file paths (absolute, not relative) and exact node IDs / symbol names.
- Don't paraphrase the user's extra context if they gave any. Keep their wording.
- Don't include the conversation history. Distill it.

---

## Step 3: Copy to clipboard

Use a Bash heredoc piped to `pbcopy`:

```bash
cat <<'EOF' | pbcopy
<the handoff prompt>
EOF
echo "Copied $(pbpaste | wc -c | tr -d ' ') chars to clipboard"
```

Use the single-quoted heredoc delimiter (`'EOF'`) so backticks, dollar signs, and other shell characters in the prompt don't get interpreted.

If the prompt contains a literal `EOF` line for any reason, switch the delimiter to something else like `'HANDOFF_EOF'`.

---

## Step 4: Confirm

Report back in one short line: the character count and a one-sentence summary of what the next agent will be doing. Tell the user to paste with Cmd+V (macOS).

Example: "Copied 4,200 chars. Next agent will pick up the suggest-intros engineering review starting from the locked-in wireframes."

Do not print the full prompt back to the user. They have it on the clipboard; printing it again just clutters the chat.
