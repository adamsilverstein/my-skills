# Decision cards in the chat

The fallback for when `scripts/launch.sh` exits with 3 because no terminal can be opened (a remote or web session, for example). The cards are printed in the conversation, one per turn, and the user types the answer and presses Enter.

## Show one card per turn

A card is a fenced code block, so the terminal keeps it monospaced. Copy this shape exactly:

```
┏━━ DECISION 2 of 5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ●●○○○
┃
┃  Where should the retry limit live?
┃
┃  WHY   Three call sites hard-code 3 today. The upload path needs
┃        5, so the value has to move somewhere before that lands.
┃
┃  ▸ A   Shared constant in config.ts               ★ RECOMMENDED
┃        One place to change, no API change.
┃
┃    B   Per-call option with a default of 3
┃        Flexible, but every caller grows a parameter.
┃
┃    C   Leave as is, hard-code 5 in the upload path
┃        Smallest diff, a fourth copy of the number.
┃
┃  PICK  A - only one caller needs a different value, so an
┃        option on every call is more surface than the problem.
┃
┗━━ a · b · c · ok = A · skip · back · all ━━━━━━━━━━━━━━━━━━━━━━━
```

The parts, in order:

| Part | Content |
|---|---|
| Top rule | `DECISION X of Y`, then one dot per decision: `●` for cards up to and including this one, `○` for the rest. Above 10 decisions use `X/Y` instead of dots. |
| Question | One line, phrased as a question, in plain words. |
| `WHY` | One or two lines: what hangs on this, with the concrete file, PR, or number. |
| Options | Two to four, lettered. Label line, then one line on the consequence. `▸` and `★ RECOMMENDED` mark exactly one. |
| `PICK` | The recommended letter and the reason, one or two lines. Always commit to one, even when it is close; say it is close. |
| Bottom rule | The option letters on this card, `ok = <recommended letter>`, `skip`, `back`, `all`. Leave `back` off card 1. |

Layout rules:

- The left bar and the two rules are the whole frame. There is no right border, so nothing has to be padded to line up.
- No line is wider than 66 columns, frame included. Keep the whole card under 24 lines.
- Plain text only inside the card: no markdown, no emoji, no ANSI color codes. They do not render inside a code block and they break the alignment.
- Details that do not fit go in one or two sentences above the card, not in it.

A decision card is the last thing in the message. Then stop and wait. One card per turn, never two.

## Read the answer

| Reply | Meaning |
|---|---|
| A letter shown on this card | That option. |
| A letter not on this card | Record nothing. Say which letters this card has and show it again. |
| `ok`, `y`, `yes`, `rec` | The recommended option. |
| `skip` | Leave it open. It is listed as open in the summary. Later decisions that depend on it are not asked; they are listed as open too, as `waiting on N`. |
| `back` | Show the previous card again, with the earlier answer noted. |
| `all` | Accept the recommendation on this card and every later one, then go to the summary. Cards skipped earlier stay open, and so do the decisions waiting on them. |
| Anything else | A custom answer or a question. Record the answer, or reply to the question and show the same card again with the same number. If the question turns up a real alternative, add it to the card as a new lettered option. |

Then, in one line above the next card (or the summary card), confirm what was recorded: `2 of 5: A, shared constant in config.ts.`

If an answer changes a later decision, update that card before showing it and say so in that same line. If it removes one or adds one, change Y and say that there too.

Do not start acting on a decision while cards remain, unless the user asks.

## Close with a summary card

After the last card:

```
┏━━ DECISIONS 4 of 5 made ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ●●●○●
┃
┃  1  Retry limit       A  Shared constant in config.ts
┃  2  Error copy        B  Reuse the existing notice       (yours)
┃  3  Feature flag      A  Ship behind the flag
┃  4  Test coverage     -  skipped, still open
┃  5  PR split          A  One PR
┃
┗━━ go = carry these out · or name a number to change it ━━━━━━━━━
```

The top rule counts the decisions made, with `○` for each one still open. Give each decision a two or three word name. Mark answers that differ from the recommendation with `(yours)`.

When the user names a number, show that card again. If the new answer changes what a later decision is about, that later answer no longer stands: reopen it and show its card again before returning to the summary. The same applies when a skipped decision gets answered and others were waiting on it.

Under the summary card, list in a sentence anything you decided yourself while collecting the decisions. Once the user says go, carry out the decisions that were made and leave the open ones alone; if the work cannot proceed without one, show its card again.

## Common mistakes

- Showing all the questions at once, or a second card in the same turn.
- Drawing a right-hand border by hand. The lines will not line up.
- Renumbering silently after the list changes.
