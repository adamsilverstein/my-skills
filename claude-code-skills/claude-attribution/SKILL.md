---
name: claude-attribution
description: "Write a varied, human-sounding attribution line for anything Claude drafted on Adam's behalf, and block quote the drafted text so readers can see at a glance where Claude's words start and stop. Use whenever a Claude-written comment, issue, PR description, code review reply, Trac comment, or PR 'AI Use' section needs its attribution - instead of pasting the same boilerplate sentence every time."
---

# Claude attribution

Adam discloses when Claude wrote something for him. Two parts to that:

1. **A visible boundary** - the drafted text is block quoted so a reader can see where Claude's words start and stop without reading carefully.
2. **A varied header line** - the disclosure is non-negotiable, but the wording should not be a rubber stamp. Repeating "I asked Claude about this and this was the result:" on every thread reads like a bot signature and stops carrying information. Write a fresh line each time.

Why the boundary matters, in a reviewer's own words ([Gutenberg#81397](https://github.com/WordPress/gutenberg/pull/81397#issuecomment-5429568461)): "I can't tell from your comment if your reply is the Claude generated response or your own take on this topic... I want to feel like we're collaborating together, and it will help me a lot if I can know when I'm chatting with you, or chatting with an LLM."

Pairs with [adams-voice](../adams-voice/SKILL.md), which governs the writing other than the attribution. This skill only governs the attribution and the boundary.

## Shape of an attributed comment

Three parts, in this order:

1. **Adam's own line, outside the quote.** One or two sentences in his voice - what he thinks, what he wants from the reader, what he plans to do next. This is what keeps the thread a conversation between people rather than a relay of machine output. Skip it only when the handoff really is all there is to say.
2. **The attribution header, outside the quote.** Italic, on its own line. Adam is speaking here, so "I" is correct.
3. **The Claude-drafted body, block quoted.** Every line prefixed with `> `, including blank lines between paragraphs, so the quote bar runs the full height of the response.

Raw markdown:

```markdown
Good catch, this one wasn't obvious. I'd like a second pair of eyes before we act on it.

_Claude chased this down, here is where it landed:_

> The regression traces back to the `current_user_can` check in
> `edit-post/src/hooks.js`. Removing that check restores the preview, though
> why it returns true and still breaks isn't clear yet.
>
> Worth confirming on a clean install first.

Does that match what you're seeing?
```

Adam's words sit at the left margin, Claude's sit behind the quote bar. That is the whole trick, and it is what reviewers have asked for.

## The two places attribution appears

**1. Header plus block quote** - for a Claude-drafted comment, issue, PR description, code review reply, or Trac comment.

**2. AI Use footer** - the "## AI Use" section at the bottom of a PR or issue. Says what Claude wrote (description, code, or both) and keeps Adam's review commitment. Not quoted, not italic - the `## AI Use` heading already sets it apart.

## Non-negotiables

Vary everything except these:

- **Block quote the drafted body.** Every line, including the blank lines between paragraphs. A quote that stops after the first paragraph is worse than none, because the rest reads as Adam's.
- **Name Claude.** Every header says "Claude" or "Claude Code". No coy "with a little help from a friend".
- **Say what Claude did.** Wrote, investigated, drafted, dug into. A reader should know whether Claude produced the words, the code, or both.
- **Keep the header to one line.** Roughly 12 words or fewer. It is a label, not an introduction.
- **Italicize the header.** Wrap it in underscores - `_Claude went back over the geometry here:_` - so it reads as a label rather than the first sentence of the response. On Trac, use Wiki formatting instead: `''Claude went back over the geometry here:''`. The phrase banks below are written plain for readability; add the italics when you post.
- **Keep "I will review and test." in the AI Use footer of any PR that contains code.** That is a promise Adam is making, not a flourish. Never joke it away, never drop it.
- **"I" belongs to Adam, and only outside the quote.** Inside the quote, drop "I" and "my" per the Attribution rules in adams-voice.

## Block quote mechanics

- **Code blocks inside the quote** need `> ` on the fence lines too:

  ````markdown
  > Try this:
  >
  > ```js
  > await editor.canvas.locator( 'role=button' ).click();
  > ```
  ````
- **Do not quote a third party inside the quote.** Nested `> >` is unreadable and muddles who said what. Name the person and paraphrase instead, or lift their quote out into Adam's part above.
- **Lists, tables, and images** all work behind `> ` - prefix every line.
- **Trac** uses the same `>` citation prefix, so the shape carries over unchanged.
- **Very long output** (more than a screen or two) can go inside a `<details>` block on GitHub, with the attribution header as the `<summary>`. Use this sparingly - a collapsed reply is easy to miss, and the point is visibility.

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

In those cases: "I asked Claude to look into this, here is what it found:" and nothing more. Playfulness reads as not taking the problem seriously. The block quote stays either way - it is a boundary, not a flourish.

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

A reply of one paragraph or less that Adam would write himself needs no attribution: "Updated in a1b2c3d.", "Good catch, fixed in 9f8e7d6.", "perfect, thanks". Those read as Adam's own quick note. Adding a header and a quote bar to a six-word reply is worse than adding nothing.

The test is who wrote the words, not how long they are. If Claude drafted the sentences and Adam is passing them along as-is, attribute and quote them even when they are short. If Adam read the draft and rewrote it in his own words, it is his - post it plain.

## Examples

Raw markdown, so the quoting is visible.

A routine investigation on a GitHub issue:

```markdown
I hadn't looked at that code path at all, so this was news to me.

_Claude chased this down, here is where it landed:_

> The regression traces back to the `current_user_can` check in
> `edit-post/src/hooks.js`. Removing that check restores the preview, though
> why it returns true and still breaks isn't clear yet.
>
> Worth confirming on a clean install before acting on it.

Does that match what you're seeing?
```

A second opinion on a design question, where Adam has his own lean:

```markdown
I lean toward the `<select>` here, mostly for the keyboard behavior.

_I asked Claude to sanity check this, and it says:_

> Both approaches work, but the `<select>` fallback keeps keyboard behavior
> consistent with core and avoids the focus trap noted in #26476. The
> autocomplete is nicer above ~50 authors.

Which way do you lean @youknowriad?
```

A security report - plain header, no play:

```markdown
_I asked Claude to look into this, here is what it found:_

> The nonce check runs after the option is written, so the write happens
> regardless of the check result. Reordering the two fixes it.

I'll get a patch up today.
```

A PR footer:

```markdown
## AI Use

Claude Code did the typing here, I did the asking. I will review and test.
```

## Anti-patterns

- Leaving the drafted body unquoted, so it runs flush against Adam's own writing and the reader has to guess where one ends.
- Quoting only the first paragraph and letting the rest run at the left margin.
- Burying Adam's own reply inside the quote, so the whole comment is machine voice and the thread stops being a conversation.
- Nesting a third party's quote inside the Claude quote - `> >` reads as noise.
- Pasting the identical attribution sentence on every comment across a thread or a week of threads.
- A playful header on a security issue, a data-loss report, or a contentious thread.
- Dropping "I will review and test." from a PR that contains Claude-written code.
- Emoji pileups, exclamation stacks, or hype words (revolutionary, blazing, magic) in the line.
- Claiming effort, duration, or certainty Claude did not actually have.
- Multi-line or multi-sentence headers. One line, then the content.
- A header on a one-line reply Adam would have written himself.
- A header left unitalicized, where it reads as the response's opening sentence instead of a label. Also bolding it instead - bold is reserved for the one critical clause in the body.
