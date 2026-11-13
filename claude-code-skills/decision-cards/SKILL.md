---
name: decision-cards
description: "Use when the user wants to work through the open decisions on the work in progress one at a time: 'let's go through the decisions one by one', 'walk me through the choices I need to make', 'what do you need from me', 'ask me about each decision', 'one by one', or when several questions for the user have piled up and they ask to settle them in order."
---

# Decision cards

Walk the user through every open decision on the current work, one card at a time, in a small terminal UI. Each card states the question, why it matters, the options, and a recommended choice. The card stays in place on screen and the user answers with a single keypress: no Enter, no scrolling.

## 1. Collect the decisions

Before showing anything, list every decision that is the user's to make. Sources:

- Questions already raised in this conversation and left unanswered
- Forks in the plan or spec where the next step depends on a preference
- Open review feedback, TODOs, and trade-offs found in the diff or the branch
- Anything you would otherwise have guessed at

Leave out what you can settle from the code, the project conventions, or an earlier answer. Those are yours to decide; mention them in the final summary instead.

Order the list so that decisions other decisions depend on come first, then by impact. The count is Y. If there is nothing to decide, say so in one line and stop.

## 2. Write the decisions file

Write the list as JSON to a file in your scratch or temp directory, not in the repository:

```json
{
  "decisions": [
    {
      "name": "Retry limit",
      "question": "Where should the retry limit live?",
      "why": "Three call sites hard-code 3 today. The upload path needs 5, so the value has to move somewhere before that lands.",
      "options": [
        { "label": "Shared constant in config.ts", "detail": "One place to change, no API change." },
        { "label": "Per-call option with a default of 3", "detail": "Flexible, but every caller grows a parameter." },
        { "label": "Leave as is, hard-code 5 in the upload path", "detail": "Smallest diff, a fourth copy of the number." }
      ],
      "recommended": "A",
      "pick": "only one caller needs a different value, so an option on every call is more surface than the problem."
    }
  ]
}
```

| Field | Content |
|---|---|
| `name` | Two or three words. It labels the decision in the summary. |
| `question` | One line, phrased as a question, in plain words. |
| `why` | One or two sentences: what hangs on this, with the concrete file, PR, or number. |
| `options` | Two to four. They are lettered A, B, C in order. `label` is under 45 characters; `detail` is one line on the consequence. |
| `recommended` | The letter of exactly one option. Always commit to one, even when it is close. |
| `pick` | The reason for the recommendation, one or two lines. The UI puts the letter in front. If it is close, say so. |
| `answer` | Optional. A letter or free text the user already gave. The UI opens on the first card without one. |

Plain text only: no markdown, no line breaks. The UI wraps the text and draws the frame.

A card cannot change once the UI is open. If the options of one decision depend on the answer to another, leave the dependent one out and ask it in a second round.

## 3. Open the cards

Run `scripts/launch.sh` from this skill's directory in the background (`run_in_background: true`), since the user may take a while:

```bash
<skill directory>/scripts/launch.sh /path/to/decisions.json
```

It opens the UI where the user can type into it (a tmux popup, or a new iTerm or Terminal window), waits, and prints the result. Tell the user in one line that the cards are open in a new window, then end the turn. Do not print the cards in the chat as well.

What the user sees:

```
 ╭─ DECISION 2 of 5 ─────────────────────────────────────────── ●◉○○○ ─╮
 │                                                                      │
 │ Where should the retry limit live?                                   │
 │                                                                      │
 │ WHY   Three call sites hard-code 3 today. The upload path needs 5,   │
 │       so the value has to move somewhere before that lands.          │
 │                                                                      │
 │ ▸ A   Shared constant in config.ts                     ★ recommended │
 │       One place to change, no API change.                            │
 │                                                                      │
 │   B   Per-call option with a default of 3                            │
 │       Flexible, but every caller grows a parameter.                  │
 │                                                                      │
 │ PICK  A - only one caller needs a different value, so an option on   │
 │       every call is more surface than the problem.                   │
 │                                                                      │
 ╰──────────────────────────────────────────────────────────────────────╯

  a b choose  ·  enter pick A  ·  ← → move  ·  / other  ·  esc cancel
```

| Key | On a card | On the summary |
|---|---|---|
| `a` `b` `c` | Choose that option and move on | |
| `Enter` | Accept the recommendation (or keep the earlier answer) and move on | Go |
| `←` `→` | Previous or next card. A card passed with `→` stays open. | `←` goes back through the cards |
| `↑` `↓` | Move the highlight; `Enter` then picks it | |
| `/` | Type an answer or a question of their own | |
| `Backspace` | Clear the answer on this card | |
| `1`-`9` | | Jump to that card to change it |
| `Esc` | Cancel everything | Cancel everything |

After the last card the same box shows the summary: every decision with its answer, `(yours)` where it differs from the recommendation, `open` where there is none.

## 4. Act on the result

The launcher prints:

```json
{
  "status": "go",
  "answers": [
    { "n": 1, "name": "Retry limit", "choice": "A", "label": "Shared constant in config.ts", "recommended": true },
    { "n": 2, "name": "Error copy", "choice": "other", "text": "what does the notice say today?" },
    { "n": 3, "name": "Feature flag", "choice": null }
  ]
}
```

| Result | What to do |
|---|---|
| `status: go` | Confirm the answers in one or two lines, mention anything you decided yourself in step 1, then carry out the decisions that were made. |
| `choice: null` | Still open. Leave it alone. If the work cannot proceed without it, say so and ask. |
| `choice: other` | The user's own words. If it is an answer, act on it. If it is a question, answer it in the chat; when it turns up a real alternative, add it as an option. Then, if decisions are still open or were held back for a second round, write a new file with only those and open the cards again. |
| `status: cancelled` | The user pressed Esc or closed the window. Act on nothing, even though the answers so far are listed. Say it was cancelled and ask how they want to continue. |
| Exit code 2 | The file is invalid. The reason is on stderr: fix the file and run it again. |
| Exit code 3 | No terminal can be opened here. Show the cards in the chat instead: read [chat-cards.md](chat-cards.md) and follow it. |
| Exit code 4 | No answer within the hour. Ask whether they still want to go through them. |

## Common mistakes

- Printing the cards in the chat when the launcher works.
- A card without a recommendation, or "it depends" in `pick`.
- Asking about things the code or the conventions already answer.
- Acting on the answers after `cancelled`.
- Running the launcher in the foreground, where the tool call times out before the user is done.
- Leaving the decisions file in the repository.
