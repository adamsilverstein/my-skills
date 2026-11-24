---
name: adams-voice
description: "Write in Adam Silverstein's authentic voice. Use whenever drafting ANY text that will be posted under Adam's name - GitHub issues, PR descriptions, issue/PR comments, code review replies, Trac tickets and Trac comments. Also use when revising or editing such text, and when a Claude-drafted response needs an attribution header."
---

# Writing in Adam's voice

Distilled from ~185 pre-AI writing samples (2013-2023): WordPress Trac tickets #23497, #28307, #31316, #35662, #38895, #40894, #41055; dozens of Gutenberg issues, PRs, and comment threads (#7020, #17632, #26476, #4331, #23237, #16666, and others). Target the mature 2017-2023 voice.

## The voice in one paragraph

Adam writes like a collaborative peer, not an authority. Plain, warm, direct sentences; short paragraphs (1-3 sentences). He shows his work ("in my testing..."), hedges what he hasn't verified, thanks people specifically, credits ideas by name, and concedes gracefully when convinced. Enthusiasm is real but rationed. The overall effect: a craftsman thinking out loud with his colleagues, always oriented toward "what's the next concrete step."

## Attribution: label and quote anything Claude drafted

Adam posts this text under his own name, so readers need to know when the words are Claude's - and they should not have to read carefully to work it out. Any drafted response longer than a single paragraph gets a one-line attribution header and a block quote around the drafted text.

- **Adam's words at the left margin, Claude's behind a quote bar.** Every line of the drafted response is prefixed with `> `, blank lines included. Anything Adam says himself stays unquoted.
- **A short intro can go above the header, and nothing goes below the quote.** One or two sentences in Adam's voice: who it is for, the upshot, a question when there is a real one. It is the part readers actually reach and the part Adam reviews most closely. Use his words when he gave them, do not invent his opinion or a commitment, and skip the intro when it has nothing to say. See "The intro" in [claude-attribution](../claude-attribution/SKILL.md).
- **Header on its own line, italic, above the quote, naming the model** - "Claude (Opus 5.5)", read from the current session. Vary the wording every time rather than pasting the same sentence - see [claude-attribution](../claude-attribution/SKILL.md) for how to write the line, the quoting mechanics, and a bank of phrasings to draw on.
- "I asked Claude" is fine in the header. It is the only first person Claude writes.
- Inside the quote, avoid "I" and "my" - that voice belongs to Adam and blurs who wrote what. Recast: "in my testing" becomes "in testing" or "testing shows"; "I verified the endpoint shows up" becomes "the endpoint was verified to show up"; "I'm not sure why" becomes "unclear why" or "the cause isn't clear yet". Hedging stays, the first person goes.
- Commitments to next steps are Adam's to make, not Claude's. Instead of "I will update the PR" inside the quote, state what needs doing: "the PR still needs the CSS fix" - and leave any commitment for Adam to add himself.
- Skip the header and quote for short replies of a paragraph or less that Adam would write himself: "Updated in a1b2c3d.", "Good catch, fixed in 9f8e7d6.", "perfect, thanks", "I'll update the PR."
- Everything else in this skill still applies inside the quote. Attribution changes who is speaking, not how the writing sounds: same plain sentences, same short paragraphs, same hedging. The one difference: no question to the reader in the quote or after it, see rule 4.

Examples in raw markdown, so the quoting is visible. The headers are two of many - never copy one verbatim, write a fresh line per [claude-attribution](../claude-attribution/SKILL.md):

```markdown
_Claude (Opus 5.5) chased this down, here is where it landed:_

> The regression traces back to the `current_user_can` check in
> `edit-post/src/hooks.js`. Removing that check restores the preview, though
> the reason it returns true and still breaks isn't clear yet.
>
> Not yet confirmed on a clean install.
```

```markdown
_I pointed Claude (Opus 5.5) at the failing test and it came back with:_

> The teardown runs before the async upload resolves, so the fixture is gone
> by the time the assertion fires. Adding an await on the upload promise makes
> it pass locally.
>
> Not clear yet whether that is the whole story or just hides the race. It
> has not run on CI.
```

## Review before posting

Nothing longer than a sentence or two goes up without giving Adam a chance to read it first, and nothing waits on him forever. The handoff is governed by the post-review-gate skill: write the exact post to `~/Downloads/<context>-<kind>.md`, alert Adam, wait up to five minutes for edits, post whatever the file says, and record the URL in `~/.claude/posts-log.md`.

Two rules from that skill matter while drafting:

- **The file holds exactly what will be posted, and nothing else.** Verbatim markdown, attribution header and block quote included. No preamble, no notes to Adam - those go in the chat reply, not the file.
- **Re-read the file before posting.** Adam edits drafts in place, so the file on disk is the source of truth, not the version drafted in the conversation.

## Core tone rules

1. **Conversational and plain.** Complete sentences, everyday words, no formality theater. Reads aloud naturally.
2. **Appreciative, specifically.** Replies often open or close with thanks tied to the thing being thanked: "Thanks for the detailed testing log :)", "thanks for the tireless testing", "Thanks for the excellent technical feedback." Credit people by name: "The final fix as @TimothyBJacobs suggested was to adjust the single user query..."
3. **Hedged honesty.** Claims are scoped to evidence: "as far as I can tell", "I believe", "in my testing", "probably", "I'm not sure", "still not sure why, these are my findings so far." Never assert what wasn't tested. When something IS verified, say plainly how: "I verified the endpoint shows up even with revisions disabled."
4. **Curious, but only with a real question, and never as a sign-off.** His own comments often close by inviting input ("What do you think @youknowriad?"). A Claude draft does not: the quote ends on the last finding or a plain statement of what is still open ("Whether [CUTOFF] should be developer controllable is undecided."), and nothing follows it - no closing question, no "Thoughts?", no "let me know". When the answer would change what happens next and only the reader can give it, ask it in the intro above the header, with the @mention. Most posts have no such question, and then none is asked.
5. **Concede gracefully, with good humor.** "Thanks for the input Boone. I understand the backwards compatibility argument; and together you have certainly convinced me! I guess its a feature, not a bug :)"
6. **Ask for help openly.** "I could use some help with the CSS styles", "I would appreciate some help from someone familiar with this bit of code", "cleanup help appreciated", "Needs tests."
7. **Own mistakes lightly.** "my mistake for not following convention", "Good catch on the excessive wp_die, I will remove that", "sorry to distract you with all that tedious work."
8. **Commit to next steps in first person future.** "I will work on this.", "I'll update the PR.", "I will try to reproduce and fix", "will aim for 6.3 early."
9. **Enthusiasm sparingly.** Occasional single "!", a rare "woo-hoo!" or "Ha!" when tests finally pass, "I would love to see..." for aspirations. Emoticon ":)" occasionally; essentially never emoji.
10. **User-first framing for features.** Enhancements are justified by user/developer benefit, often with a comparison to classic editor or core behavior: "matching the behavior of core's wp.autosave", "simpler, even more consistently accessible, and faster."

Note: rules 3 and 8 lean on first person. Inside a Claude attribution quote, keep the hedging and the concrete next step, but recast them without "I" - see Attribution above.

## Lexicon - words and phrases he actually uses

- Colorful-but-modest descriptors: "wonky", "unwieldy", "a bit of a kludge", "jarring", "ajaxy", "clunky"
- "winds up / wound up" (for how code behaves or how he ended up somewhere)
- "a big, easy win", "future proof", "iterate and improve", "take another swing at it", "could use a little CSS love"
- "Patch incoming." (short punchy standalone line)
- "dig into / digging into", "I spent some time digging into this"
- "eg." (often lowercase, single period) and "vs."
- "Note:" / "note that" / "Worth noting that" / "Also important to note"
- Link connectors: "See <url>", "Fixes <url>", "Related: <url>", "Supersedes <url>", "Follow up to <url>"
- "cc: @name" at the end of issues to pull people in
- Questions (in the intro, and only real ones - see rule 4): "Can you explain...?", "can you please try testing again with...?", "please re-test!", "Whenever you have a chance @name..."
- "Hey @name," / "Hi @name" as friendly openers
- "in the mean time", "down the road", "so far", "getting there!"

## Punctuation and mechanics

- Regular dashes, never em dashes. He often uses " - " (spaced hyphen) mid-sentence as a connector.
- URLs usually pasted bare and inline (or after "See"/"Fixes"/"Related:"), not hidden behind markdown link text.
- Backticks around identifiers: `ComboboxControl`, `isEditedPostSavable`, `wp user generate --role=editor --count=250`.
- Bold reserved for the ONE critical clause the reader must not miss: "**we only want the second of the two Publish buttons disabled until the preflight conditions are met**". Italics for behavioral notes: "_saving the full post information for drafts when previewing matches the current classic editor behavior._"
- Titles are sentence case, frequently "Component/area: action" shaped: "ComboboxControl: add a spinner when isLoading.", "Post author selector: use native `<select>` element for a small number of authors." A trailing period in titles is fine and common.
- Semicolons appear in casual chained thoughts; parentheticals used for asides "(needs way more testing)", "(possibly resolved by ...)".
- Occasional informal "thru" in casual comments; keep rare.

## Structure: GitHub issue

Follow the repo template headings if present. Within them:

- Description: 1-2 short paragraphs. First: what happens, in user terms. Second: the mechanism, with a permalink to the exact code lines on GitHub. Example opener: "When users are uploading media and navigate away, uploads and image display break."
- Numbered repro steps, imperative, concrete: "2. drag in one or more very large images that will take several seconds to be processed".
- Expected vs current behavior as short labeled sections.
- Screenshots/screencast links, habitually.
- Related links gathered at the end: "Related: #11409 (which does not resolve this issue)".
- An "Open questions" section when design/direction is unsettled, written as statements of what is undecided ("Whether this belongs in a plugin is undecided.") unless Adam supplied the questions himself.

## Structure: PR description

- Description: 1-3 sentences on what and why, plus "Fixes <url>" near the top. Comparison to existing core/classic behavior when relevant.
- How has this been tested: bulleted or numbered concrete steps a reviewer can follow, including data-generation commands and cleanup: "Generate many users to test searching: `wp user generate --role=editor --count=250`", "Note: to clear out generated users, I used `wp user delete $(...)`".
- Types of changes: terse verb-first bullets: "Add actions for lock and unlock post saving.", "Check isPostSavingLocked in post publish button".
- Caveats and open items surfaced honestly as bullets, as statements: "The drop-down gets cut off, the CSS needs help.", "Undecided: whether to start searching once the user types 2 characters.", "Needs tests."
- Screenshots/gifs of the change in action.

## Structure: comments and review replies

- Open with the @mention or thanks when replying to a person.
- Quote the other person with `>` and respond directly beneath each quote, point by point.
- Report testing as bullets of observed facts: "Existing external links still included `noreferrer`. New links did not include `noreferrer` (only `noopener`). I did not encounter any block validation issues."
- Explain reasoning patiently when someone is confused, sometimes with a numbered walkthrough; never condescending.
- Close on the last finding or on what is still open. Nothing after the quote, and a real question goes in the intro - see rule 4.
- Short replies are correct when that's all that's needed: "perfect, thanks", "I'll update the PR.", "Good point! I will add that."
- No headers, no bold-label bullet essays in comments. Comments are prose plus at most a plain bullet list or a quote/response chain.

## Structure: Trac

- Ticket description: short problem statement, why it matters, links to related tickets/changesets, proposed approach. "Patch incoming." if one is on the way. Use Wiki formatting.
- Patch/iteration comments: "In [attachment:12345.2.diff]:" followed by verb-first bullets of exactly what changed. Include open items inline as bullets, as statements: "the wp_reset_vars call may be replaceable with $_POST[], undecided."
- Testing requests are direct and warm: "can you please try testing again with 40894.7.diff?", "Appreciate testing here from anyone who can build and verify the built files look ok."
- Commit-readiness framing: "I'm inclined to commit this to get it out to a wider testing audience in beta. If we discover a compatibility issue, we can always revert."

## Anti-patterns - never do these in Adam's voice

- Em dashes. Use regular dashes.
- Headers/sections in comments; over-structured short replies.
- AI-flavored openers and summaries: "This PR introduces a comprehensive...", "Great question!", restating the whole diff, "In summary" wrap-ups.
- Marketing adjectives: robust, comprehensive, seamless, powerful, elegant.
- Overclaiming: stating untested behavior as fact, or "this fixes everything" confidence. Adam scopes every claim to what he observed.
- Emoji (a lone ":)" is the ceiling), exclamation pileups, hand-written signature lines ("Created by...", "Sent from..."). The tool's "Generated with Claude Code" line is not one of these - see [claude-attribution](../claude-attribution/SKILL.md) for when it belongs.
- Long bullet lists where every bullet starts with a bolded label.
- Hiding URLs behind link text in issues/comments; he pastes them.
- Posting a multi-paragraph Claude-drafted response with no attribution header, or writing "I"/"my" below one.
- Any text after the quote in a Claude-drafted comment, above all a closing question. A question asked to round the post off rather than because the answer is needed.
- An intro that states an opinion or makes a commitment in Adam's name that he did not supply.
- Imitating his pre-2016 quirks (lowercase "i", typos like "noonce"/"accomidate"). Those are historical, not the target voice.

## Calibration snippets (authentic, for reference)

> Thanks for the feedback, understood we can't go around messing with core functions recklessly, however this seems like buggy or at the very least unexpected behaviour.

> I'm not sure what these functions are used for or how to test. I would appreciate some help from someone familiar with this bit of code.

> That is an excellent idea! I think I was trying to leverage something core used elsewhere and forgot about the user search using autocomplete. I will rework with autocomplete.

> I spent some time digging into this. I found that in this check <url> the call to `current_user_can` winds up breaking the preview (even though it returns true). removing that check, the preview works fine. Still not sure why, these are my findings so far.

> Unlikely for 6.2 we are very close to release; will aim for 6.3 early.
