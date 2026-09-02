---
name: post-review-gate
description: "Use before posting anything under Adam's name that runs longer than a sentence or two - a GitHub issue, PR description, issue or PR comment, code review reply, Trac ticket or Trac comment - and whenever Adam asks what Claude has posted on his behalf (today, this week, ever)."
---

# Post review gate

Adam gets a timed chance to look at every post that goes out under his name, and his silence never blocks the work. Draft to a file, alert him, wait up to five minutes, post whatever the file says, write it down.

Pairs with adams-voice (how the text reads) and claude-attribution (how Claude's words are marked). This skill only governs the handoff: file, alert, wait, post, record.

Scripts live in this skill's `scripts/` directory (`~/.claude/skills/post-review-gate/scripts/` once installed).

## The workflow

1. **Draft to a file.** Write the exact text to `~/Downloads/<context>-<kind>.md`: `gutenberg-81397-comment.md`, `trac-62345-ticket.md`, `wpd-9012-review-reply.md`, `my-skills-post-review-gate-pr.md`. The file holds only what will be posted, attribution header and block quote included. No preamble, no notes to Adam, no "let me know" - those go in chat.

2. **Alert and wait, in the background.**
   ```
   bash ~/.claude/skills/post-review-gate/scripts/wait-for-review.sh ~/Downloads/gutenberg-81397-comment.md
   ```
   Run it with `run_in_background: true`. It fires a macOS notification with a sound and a terminal bell, then watches the file for five minutes. Where the PushNotification tool is available, also send one naming the file, so the alert reaches Adam's phone when Remote Control is connected. If it is not available, the script's notification is enough.

   Then tell Adam in chat: the path, that he can edit it in place, delete it to veto, or ignore it and it posts in five minutes. Never block on the script. If the task has other steps, continue them; if not, end the turn. Either way the script's result arrives as a notification and the workflow resumes from step 3.

3. **Act on the first signal.**

   | Signal | Do this | `review` |
   |---|---|---|
   | Script prints `TIMEOUT` | Post as drafted. | `unreviewed` |
   | Script prints `EDITED` | Post the file exactly as it is now on disk. | `edited` |
   | Script prints `DELETED` | Do not post. Say so in chat and move on. | - |
   | Adam tells you to post it in chat ("post it", "go ahead", "looks good, ship it") | Post now. Stop the waiter with TaskStop. | `approved` |
   | Adam asks for changes in chat | Revise the file, run the waiter again. Fresh five minutes. | - |

4. **Post from the file.** Re-read it from disk immediately before posting. The file is the source of truth, not the version drafted in the conversation - Adam edits in place and may not mention it.

5. **Record it, then report it.**
   ```
   bash ~/.claude/skills/post-review-gate/scripts/log-post.sh comment "WordPress/gutenberg#81397" <url> unreviewed ~/Downloads/gutenberg-81397-comment.md
   ```
   Kinds: `comment`, `review-reply`, `issue`, `pr`, `trac-ticket`, `trac-comment`. The log is `~/.claude/posts-log.md`. Give Adam the URL in chat, and say whether it went out reviewed or not.

**Short replies skip the file and the wait, not the record.** A one-liner Adam would fire off himself ("Updated in a1b2c3d.", "Thanks, merging.") posts directly with no draft file and is logged with `review: short` and no draft path. Anything longer, or anything Claude drafted from scratch, goes through the gate.

## Guardrails

- **Five minutes, then post.** No manual sleeps, no re-running the waiter to "give Adam more time", no ending the turn with the draft unposted and no waiter running. The whole point is that Adam being busy does not stall the task.
- **The waiter fired but the post already went out** (Adam approved in chat first): check the log for the draft path. If it is there, do nothing.
- **No file, no post.** When Adam says "just post it" before a draft exists, still write the file, post from it, and log it as `approved`. Cheap next to a comment that cannot be unsent.
- **Log before reporting.** If the log line fails, fix it before handing over the URL. A post that is not in the log did not happen as far as "what have you posted for me" is concerned.
- **Approval is a reply about the post, not about the work.** "Looks good, go ahead" after you named the draft is approval. "Looks good" about the code, the diff, or the task, with no reference to posting, is not. When in doubt, the timer decides.

## "What have you posted for me today?"

```
bash ~/.claude/skills/post-review-gate/scripts/show-posts.sh            # today
bash ~/.claude/skills/post-review-gate/scripts/show-posts.sh 2026-09-01 # one day
bash ~/.claude/skills/post-review-gate/scripts/show-posts.sh all        # everything
```

Present the entries as a list with links. Call out anything marked `unreviewed` so Adam knows which posts went out without his eyes on them.

Log line shape:

```
- 16:52 PDT | comment | WordPress/gutenberg#81397 | https://github.com/WordPress/gutenberg/pull/81397#issuecomment-123 | review: unreviewed | draft: ~/Downloads/gutenberg-81397-comment.md
```

## Rationalizations that mean stop and follow the workflow

| Thought | Reality |
|---|---|
| "Adam is probably busy, better to wait until he answers." | Waiting indefinitely is the failure this skill replaces. Five minutes, then post. |
| "This one is too important to post unreviewed." | Adam set the timeout knowing he might not respond. Post it. The `unreviewed` flag in the log tells him to look. |
| "It's quick, I'll just paste it in chat and ask." | A draft in chat cannot be edited in place and leaves no record. Write the file. |
| "I already posted, no need to log it." | The log is how Adam finds out what went out under his name. Log it. |
| "I'll post first and write the file after." | The file is what Adam edits and what the waiter watches. File first, always. |
