---
name: claude-attribution
description: "Write a varied, human-sounding attribution line for anything Claude drafted on Adam's behalf. Use whenever a Claude-written comment, issue, PR description, code review reply, Trac comment, or PR 'AI Use' section needs its attribution header - instead of pasting the same boilerplate sentence every time."
---

# Claude attribution lines

Adam discloses when Claude wrote something for him. That disclosure is non-negotiable, but the wording should not be a rubber stamp. Repeating "I asked Claude about this and this was the result:" on every thread reads like a bot signature and stops carrying information. Write a fresh line each time.

Pairs with [adams-voice](../adams-voice/SKILL.md), which governs the writing other than the attribution. This skill only governs the attribution itself.

## The two places an attribution line appears

**1. Prose header** - above a Claude-drafted comment, issue, PR description, code review reply, or Trac comment. Italic, on its own line, blank line, then the response. Ends with a colon when the response follows directly.

**2. AI Use footer** - the "## AI Use" section at the bottom of a PR or issue. Says what Claude wrote (description, code, or both) and keeps Adam's review commitment.

## Non-negotiables

Vary everything except these:

- **Name Claude.** Every line says "Claude" or "Claude Code". No coy "with a little help from a friend".
- **Say what Claude did.** Wrote, investigated, drafted, dug into. A reader should know whether Claude produced the words, the code, or both.
- **Keep the header to one line.** Roughly 12 words or fewer. It is a label, not an introduction.
- **Italicize the header.** Wrap it in underscores - `_Claude went back over the geometry here:_` - so it reads as a label set apart from the response rather than the first sentence of it. On Trac, use Wiki formatting instead: `''Claude went back over the geometry here:''`. The phrase banks below are written plain for readability; add the italics when you post. The AI Use footer is not italicized, its `## AI Use` heading already sets it apart.
- **Keep "I will review and test." in the AI Use footer of any PR that contains code.** That is a promise Adam is making, not a flourish. Never joke it away, never drop it.
- **"I" belongs to Adam and only in the attribution line itself.** Below a header, drop "I" and "my" per the Attribution rules in adams-voice.

## Register: fun, not zany

Aim for the same modest, plain-spoken humor already in Adam's vocabulary - "wonky", "a big, easy win", "took another swing at it". A light turn of phrase, then get out of the way.

Good: "Claude took a deep dive on this one and came up with this:"

Too much: "🚀 Behold! My silicon apprentice has spoken! 🤖✨"

Rules of thumb:

- One idea per line. No stacked jokes.
- No jokes at the reader's expense, and none about the bug being obvious or the reporter being wrong.
- Do not invent effort or facts. "Claude spent three hours on this" is a lie if it did not. Fun is fine, false is not.
- Emoji: 🤖 is fine in the AI Use footer where it is already conventional. Keep headers emoji-free, matching Adam's usual near-zero emoji use.
- Do not repeat a phrasing you have already used in the same thread, and try not to reuse the one from your previous comment in the same repo.

## Dial it back when the thread is heavy

Use a plain, unadorned line when the context is a security issue, a user reporting real breakage or data loss, a heated or contentious thread, a release blocker under time pressure, or a first reply to a frustrated reporter.

In those cases: "I asked Claude to look into this, here is what it found:" and nothing more. Playfulness reads as not taking the problem seriously.

## Building a fresh line

Three slots, pick one from each and say it out loud:

1. **Who did the work** - Claude, Claude Code, "I asked Claude", "I pointed Claude at this"
2. **How it got there** - dug in, took a deep dive, chased it down, read the whole thread, with some careful prompting, after a few rounds of back and forth
3. **The handoff** - "here is what it found:", "and this came back:", "which reports:", "here is where it landed:"

Not every line needs all three. "Message from Claude, carrying on as me:" works on two.

## Phrase bank - prose headers

A palette, not a fixed list. Prefer inventing one that fits the specific thread; reach for these when nothing better comes.

- I asked Claude to dig into this, here is what it found:
- Claude took a deep dive on this one and came up with this:
- Message from Claude, carrying on as me:
- I consulted with Claude and arrived at this:
- I pointed Claude at this and it came back with:
- Claude chased this down, here is where it landed:
- Handing this one to Claude, which reports:
- I had Claude read through the whole thread, here is its take:
- Claude did the digging here, findings below:
- Turned Claude loose on this one:
- I asked Claude to sanity check this, and it says:
- Claude's take on this, forwarded along:
- I described the problem to Claude and this came back:
- Claude went through the code for this one:
- I asked Claude to look into this, here is what it found:

Tune the verb to the actual work. "Dug into" and "chased this down" suit an investigation; "Claude's take" suits an opinion; "sanity check" suits a second look at something Adam already believes.

## Phrase bank - AI Use footers

For PRs and issues. Each keeps the review commitment when code is involved.

- Written with 🤖 Claude Code. I will review and test.
- I told Claude what I wanted and it wrote this code. I will review and test.
- Claude wrote this code with some careful prompting. I will review and test.
- Claude Code did the typing here, I did the asking. I will review and test.
- Built with 🤖 Claude Code over a few rounds of back and forth. I will review and test.
- Claude Code drafted this and I steered. I will review and test.
- This code came out of a conversation with 🤖 Claude Code. I will review and test.
- Description written with 🤖 Claude Code. (Description only, no code - no review commitment needed.)
- Code and description both written with 🤖 Claude Code. I will review and test.

## Short replies still skip the header

A reply of one paragraph or less needs no attribution: "Updated in a1b2c3d.", "Good catch, fixed in 9f8e7d6.", "perfect, thanks". Those read as Adam's own quick note. Adding a playful header to a six-word reply is worse than adding no header at all.

## Examples

A routine investigation on a GitHub issue:

> _Claude chased this down, here is where it landed:_
>
> The regression traces back to the `current_user_can` check in <url>. Removing that check restores the preview, though why it returns true and still breaks isn't clear yet.
>
> Worth confirming on a clean install before acting on it. Does that match what you're seeing?

A second opinion on a design question:

> _I asked Claude to sanity check this, and it says:_
>
> Both approaches work, but the `<select>` fallback keeps keyboard behavior consistent with core and avoids the focus trap noted in #26476. The autocomplete is nicer above ~50 authors.
>
> Which way do you lean @youknowriad?

A security report - plain, no play:

> _I asked Claude to look into this, here is what it found:_
>
> The nonce check runs after the option is written, so the write happens regardless of the check result. Reordering the two fixes it.

A PR footer:

> ## AI Use
>
> Claude Code did the typing here, I did the asking. I will review and test.

## Anti-patterns

- Pasting the identical attribution sentence on every comment across a thread or a week of threads.
- A playful header on a security issue, a data-loss report, or a contentious thread.
- Dropping "I will review and test." from a PR that contains Claude-written code.
- Attribution so cute the reader has to work out whether a human or an AI wrote the body.
- Emoji pileups, exclamation stacks, or hype words (revolutionary, blazing, magic) in the line.
- Claiming effort, duration, or certainty Claude did not actually have.
- Multi-line or multi-sentence headers. One line, then the content.
- A header on a one-line reply.
- A header left unitalicized, where it reads as the response's opening sentence instead of a label. Also bolding it instead - bold is reserved for the one critical clause in the body.
