---
name: claude-attribution
description: "Use when anything Claude drafted is about to be posted under Adam's name - a GitHub comment, issue, PR description, code review reply, Trac ticket or comment - or when a PR or issue needs its 'AI Use' section. Also use when revising such a draft, when a reader could not tell Claude's words from Adam's, or when a draft carries a byline that does not name the model."
---

# Claude attribution

Adam discloses when Claude wrote something for him. A reader should be able to answer three questions at a glance, without reading carefully:

1. **Which words are Claude's?** The drafted text sits behind a block quote bar.
2. **Which Claude?** The byline names the model and version: "Claude (Opus 5.5)".
3. **What did Claude do?** Wrote, investigated, reviewed, drafted - said in a fresh line each time, not a rubber stamp.

Why the boundary matters, in a reviewer's own words ([Gutenberg#81397](https://github.com/WordPress/gutenberg/pull/81397#issuecomment-5429568461)): "I can't tell from your comment if your reply is the Claude generated response or your own take on this topic... I want to feel like we're collaborating together, and it will help me a lot if I can know when I'm chatting with you, or chatting with an LLM."

Pairs with [adams-voice](../adams-voice/SKILL.md), which governs how the writing sounds, and [post-review-gate](../post-review-gate/SKILL.md), which governs the handoff before posting. This skill governs the byline, the boundary, and whose words go where.

## Quick reference

| Posting | Byline header | Block quote | AI Use footer |
|---|---|---|---|
| Comment, review reply, Trac comment | Yes | Yes | No |
| Issue, Trac ticket | Yes | Yes | Yes |
| PR description | Yes | Yes | Yes, with "I will review and test." when the PR has code |
| One-line reply Adam would write himself ("Updated in a1b2c3d.") | No | No | No |

Every byline and every footer names the model. One byline per post: no second "written with Claude" line at the bottom of a comment.

## Shape of an attributed post

The parts, in order:

1. **Adam's own words, at the left margin - only if he supplied them.** See "The left margin is Adam's" below. Most drafts have none, and start at the header.
2. **The byline header, at the left margin.** Italic, one line, names Claude and the model.
3. **The Claude-drafted body, block quoted.** Every line prefixed with `> `, including blank lines between paragraphs, so the quote bar runs the full height of the response.
4. **The post ends where the body ends** - on the last finding, or on a plain statement of what is still open. Not on a question. (On a PR or issue, the `## AI Use` section follows, unquoted.)

Raw markdown:

```markdown
_Claude (Opus 5.5) chased this down, here is where it landed:_

> The regression traces back to the `current_user_can` check in
> `edit-post/src/hooks.js`. Removing that check restores the preview, though
> why it returns true and still breaks isn't clear yet.
>
> Not yet confirmed on a clean install.
```

## Name the model

The byline says which model wrote the text, in parentheses after the name: `Claude (Opus 5.5)`, `Claude Code (Opus 5.5)`.

- **Read the model from your own session, every time.** The environment section of your system prompt states the model you are running as ("You are powered by the model named ..."). Use that. The examples in this skill say "Opus 5.5" because that is what wrote them - do not copy it, and do not carry over the model named in an earlier draft, an older comment in the thread, or a commit trailer.
- **Family and version, nothing else.** "Opus 5.5", not "claude-opus-5-5", not "Claude Opus 5.5 (1M context)". If all you have is a model ID, convert it: `claude-opus-5-5` becomes "Opus 5.5".
- **If the session does not state the model, write plain "Claude".** A missing version is fine. A guessed one is a false statement under Adam's name.
- **Subagents:** if a subagent on a different model drafted the text, name the model that wrote it when you know it. Otherwise name your own - you are the one posting it.
- **Once per byline.** The header names the model. So does the AI Use footer, because a reader may see only one of them. The body does not mention it.

## The left margin is Adam's

Anything outside the quote bar reads as Adam speaking in person. That is the whole point of the boundary, so it has to stay true:

- **Put words at the left margin only when Adam said them** - in this conversation, or in the draft file during the review window. His take, his decision, his thanks, his question. Tidy them into a sentence if he dictated them roughly; do not add to them.
- **Do not write Adam's opinion, plan, or reaction for him.** "I lean toward the `<select>` here", "this was news to me", "I'll get a patch up today" are his to say. If he has not said them, the post starts at the header. Most drafts post without Adam editing them, so an invented left-margin line goes out as a statement he never made.
- **The byline is the one exception**: it sits at the left margin and Claude writes it. Keep it to facts about what Claude did.

## No questions to the reader

The post states what was found and what is still unknown. It does not ask the reader anything. Asking is how Adam steers a thread, and he does it himself.

- **End on the last finding or the open item**, stated flat: "Not yet confirmed on a clean install." "Unclear whether this also affects multisite."
- **Turn a would-be question into a statement of what is unknown.** "Does that match what you're seeing?" becomes nothing at all. "Should this default to on?" becomes "Whether this should default to on is undecided."
- **No @mention asking for input, no "What do you think?", no "Thoughts?", no "let me know".** Not inside the quote, not after it.
- **No @mentions inside the quote.** A mention notifies the person, which is a request for their attention even when the sentence is a statement. Write "the reporter" or "the reviewer"; "Only @jdoe can confirm it" becomes "Only the reporter can confirm it."
- **Bring the questions to Adam instead.** When a draft would have benefited from a question - something only the reporter can confirm, a decision that needs a maintainer - list those in the chat reply alongside the review-gate alert, worded so he can paste one in. He decides whether to ask.
- **If Adam dictates a question, it goes at the left margin, in his words**, after the quote.

This overrides the "end with a question" habit described in adams-voice for anything Claude drafts.

## Non-negotiables

Vary everything except these:

- **Block quote the drafted body.** Every line, including the blank lines between paragraphs. A quote that stops after the first paragraph is worse than none, because the rest reads as Adam's.
- **Name Claude and the model.** `Claude (Opus 5.5)` or `Claude Code (Opus 5.5)`, with your own model. No coy "with a little help from a friend".
- **Say what Claude did.** Wrote, investigated, drafted, reviewed, dug into. A reader should know whether Claude produced the words, the code, or both.
- **Keep the header to one line.** Roughly 14 words or fewer. It is a label, not an introduction.
- **Italicize the header.** Wrap it in underscores - `_Claude (Opus 5.5) went back over the geometry here:_` - so it reads as a label rather than the first sentence of the response. On Trac, use Wiki formatting instead: `''Claude (Opus 5.5) went back over the geometry here:''`. The phrase banks below are written plain for readability; add the italics when you post.
- **Keep "I will review and test." in the AI Use footer of any PR that contains code.** That is a promise Adam is making, not a flourish. Never joke it away, never drop it.
- **No "I" or "my" inside the quote.** Recast per the Attribution rules in adams-voice. Commitments to next steps are Adam's: write "the PR still needs the CSS fix", not "I will update the PR".
- **Do not claim Adam's review or agreement.** "I consulted with Claude and arrived at this" says he weighed it and signed off. Unless he did, the byline says only what Claude did.

## Building a fresh byline

Three slots:

1. **Who did the work** - Claude (model), Claude Code (model), "I asked Claude (model)"
2. **What it did** - dug in, chased it down, read the whole thread, reviewed the diff, wrote the fix, tested against the beta
3. **The handoff** - "here is what it found:", "write-up below:", "which reports:", "here is where it landed:"

Not every line needs all three. "Review notes from Claude (Opus 5.5):" works on two.

Tune the verb to the actual work. "Dug into" and "chased this down" suit an investigation; "review notes" suits a review; "wrote the code and this description" suits a PR. Naming the specific thing - "tested the plugin against 7.2 beta 5" - beats any stock phrase, and is what keeps a week of bylines from sounding alike.

"I asked Claude" is fine when Adam did ask, which is the usual case. Use the Claude-as-subject form when Claude acted on its own initiative inside a larger task (filing an issue it noticed while doing something else).

## Phrase bank - headers

A palette, not a fixed list. Prefer a line that fits the specific thread. Swap in your own model.

- Written by Claude (Opus 5.5):
- Claude (Opus 5.5) chased this down, here is where it landed:
- I asked Claude (Opus 5.5) to dig into this, here is what it found:
- Review notes from Claude (Opus 5.5):
- Claude Code (Opus 5.5) wrote the code and this description, summary below:
- I pointed Claude (Opus 5.5) at the failing test and it came back with:
- Claude (Opus 5.5) read through the whole thread, here is its take:
- Write-up from Claude Code (Opus 5.5), which also made the fix:
- While testing screen reader output, Claude (Opus 5.5) noticed this:
- Claude (Opus 5.5) did the digging here, findings below:
- I asked Claude (Opus 5.5) to sanity check this, and it says:
- Update from Claude (Opus 5.5) after the rebase:

## Phrase bank - AI Use footers

For PRs and issues. Not quoted, not italic - the `## AI Use` heading already sets it apart. Say which parts Claude produced (code, tests, description), name the model, and keep the review commitment when code is involved.

- Claude Code (Opus 5.5) wrote the fix, the test and this description. I will review and test.
- I told Claude (Opus 5.5) what I wanted and it wrote this code. I will review and test.
- Claude Code (Opus 5.5) did the typing here, I did the asking. I will review and test.
- Built with 🤖 Claude Code (Opus 5.5) over a few rounds of back and forth. I will review and test.
- Claude (Opus 5.5) found the cause, wrote the fix, and drafted this description. I will review and test.
- Description written with 🤖 Claude Code (Opus 5.5). (Description only, no code - no review commitment needed.)
- Claude (Opus 5.5) wrote up this issue from a QA pass. (Issue, no code.)

## Register: plain, with a light touch

Aim for the modest, plain-spoken humor already in Adam's vocabulary - "wonky", "took another swing at it". A light turn of phrase, then get out of the way.

Good: "Claude (Opus 5.5) took a deep dive on this one and came up with this:"

Too much: "🚀 Behold! My silicon apprentice has spoken! 🤖✨"

- One idea per line. No stacked jokes, none at the reader's expense.
- Do not invent effort or facts. "Claude spent three hours on this" is a lie if it did not.
- Emoji: 🤖 is fine in the AI Use footer where it is already conventional. Headers stay emoji-free.
- Do not repeat a byline already used in the same thread. Before writing one, read the earlier bylines in the thread, and the draft files that the last few `~/.claude/posts-log.md` entries for the same repo point to, and pick a different shape.

**When the thread is heavy** - a security issue, real breakage or data loss, a heated thread, a release blocker, a first reply to a frustrated reporter - use the plainest line there is: "Written by Claude (Opus 5.5):" or "I asked Claude (Opus 5.5) to look into this, here is what it found:". Playfulness reads as not taking the problem seriously. The block quote and the model name stay either way.

## Block quote mechanics

- **Code blocks inside the quote** need `> ` on the fence lines too:

  ````markdown
  > Try this:
  >
  > ```js
  > await editor.canvas.locator( 'role=button' ).click();
  > ```
  ````
- **Do not quote a third party inside the quote.** Nested `> >` is unreadable and muddles who said what. Name the person and paraphrase instead.
- **Lists, tables, and images** all work behind `> ` - prefix every line.
- **Trac** uses the same `>` citation prefix, so the shape carries over unchanged.
- **Very long output** (more than a screen or two) can go inside a `<details>` block on GitHub, with the byline as the `<summary>`. Use this sparingly - a collapsed reply is easy to miss.
- **Tool-added trailers stay outside the quote, at the very end.** If the harness requires a "Generated with Claude Code" line or a session link on a PR, it goes after the AI Use section, unquoted. It does not replace the byline, and it is not a reason to add another one.

## Short replies still skip the header

A reply of one sentence that Adam would write himself needs no attribution: "Updated in a1b2c3d.", "Good catch, fixed in 9f8e7d6.", "perfect, thanks". Adding a header and a quote bar to a six-word reply is worse than adding nothing.

The test is who wrote the words, not how long they are. If Claude drafted sentences that carry a claim or an opinion and Adam is passing them along as-is, attribute and quote them even when they are short. If Adam rewrote the draft in his own words, it is his - post it plain.

## Examples

Raw markdown, so the quoting is visible. Written by Opus 5.5 - a different model writes its own name.

A second opinion, where Adam gave his lean and a question in the conversation ("tell them I lean select for keyboard reasons, and ask Riad which way he leans"):

```markdown
I lean toward the `<select>` here, mostly for the keyboard behavior.

_I asked Claude (Opus 5.5) to sanity check this, and it says:_

> Both approaches work, but the `<select>` fallback keeps keyboard behavior
> consistent with core and avoids the focus trap noted in #26476. The
> autocomplete is nicer above ~50 authors.

Which way do you lean @youknowriad?
```

The same comment when Adam said nothing beyond "post the analysis" - no left-margin lines, no question:

```markdown
_Claude (Opus 5.5) compared the two approaches:_

> Both approaches work, but the `<select>` fallback keeps keyboard behavior
> consistent with core and avoids the focus trap noted in #26476. The
> autocomplete is nicer above ~50 authors.
>
> Where the cutoff between the two should sit is still undecided.
```

A security report - plain header, no play:

```markdown
_Written by Claude (Opus 5.5):_

> The nonce check runs after the option is written, so the write happens
> regardless of the check result. Reordering the two fixes it.
>
> No patch is up yet.
```

A PR description:

```markdown
_Claude Code (Opus 5.5) wrote the fix and this description, summary below:_

> Fixes https://github.com/WordPress/gutenberg/issues/12345
>
> The teardown ran before the async upload resolved, so the fixture was gone
> by the time the assertion fired. Awaiting the upload promise fixes it.

## AI Use

Claude Code (Opus 5.5) did the typing here, I did the asking. I will review and test.
```

## Anti-patterns

- A byline that says only "Claude", when the session states the model.
- A model name copied from this skill's examples or from an earlier comment instead of read from the session. A guessed version.
- Ending the post with a question to the reader, an @mention asking for input, or "let me know".
- Writing Adam's opinion, reaction, or commitment at the left margin when he did not say it.
- Leaving the drafted body unquoted, or quoting only the first paragraph and letting the rest run at the left margin.
- Burying Adam's own words inside the quote.
- Nesting a third party's quote inside the Claude quote - `> >` reads as noise.
- A second byline at the bottom of a comment ("Comment written with Claude Code.") on top of the header.
- The identical byline on every comment across a thread or a week of threads.
- A playful header on a security issue, a data-loss report, or a contentious thread.
- Dropping "I will review and test." from a PR that contains Claude-written code.
- Emoji pileups, exclamation stacks, or hype words (revolutionary, blazing, magic) in the line.
- Claiming effort, duration, certainty, or Adam's sign-off that did not happen.
- Multi-line or multi-sentence headers. A header left unitalicized, or bolded instead.
- A header on a one-line reply Adam would have written himself.
