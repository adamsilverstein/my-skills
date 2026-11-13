#!/usr/bin/env python3
"""Decision cards: a one-keypress terminal UI for a list of decisions.

Usage:
    decide.py <decisions.json> <result.json>   run the UI (needs a terminal)
    decide.py --check <decisions.json>         validate the input and exit

Standard library only. See ../SKILL.md for the JSON formats.
"""

import json
import os
import select
import shutil
import signal
import sys
import textwrap

LETTERS = "ABCDEF"
MAX_WIDTH = 72
MIN_WIDTH = 40
OTHER = "other"

STYLES = {
    "bold": "1",
    "dim": "2",
    "accent": "36",
    "accent_bold": "1;36",
    "good": "32",
    "warn": "33",
}


class InputError(Exception):
    """The decisions file is missing something or is malformed."""


# ---------------------------------------------------------------- input


def load(path):
    """Read and validate the decisions file. Returns (title, decisions)."""
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as error:
        raise InputError(f"cannot read {path}: {error}") from error

    if isinstance(data, list):
        data = {"decisions": data}
    if not isinstance(data, dict):
        raise InputError("top level must be an object with a 'decisions' list")
    decisions = data.get("decisions")
    if not isinstance(decisions, list) or not decisions:
        raise InputError("'decisions' must be a non-empty list")

    clean = []
    for number, raw in enumerate(decisions, 1):
        where = f"decision {number}"
        if not isinstance(raw, dict):
            raise InputError(f"{where}: must be an object")
        question = _text(raw, "question", where)
        options = raw.get("options")
        if not isinstance(options, list) or not 2 <= len(options) <= len(LETTERS):
            raise InputError(f"{where}: needs 2 to {len(LETTERS)} options")
        clean_options = []
        for index, option in enumerate(options):
            if isinstance(option, str):
                option = {"label": option}
            if not isinstance(option, dict):
                raise InputError(f"{where}: option {LETTERS[index]} must be an object")
            clean_options.append(
                {
                    "label": _text(option, "label", f"{where} option {LETTERS[index]}"),
                    "detail": str(option.get("detail") or "").strip(),
                }
            )
        valid = LETTERS[: len(clean_options)]
        recommended = str(raw.get("recommended") or "").strip().upper()
        if recommended not in valid or len(recommended) != 1:
            raise InputError(f"{where}: 'recommended' must be one of {', '.join(valid)}")

        answer = raw.get("answer")
        if answer is not None:
            if isinstance(answer, str) and answer.strip().upper() in valid and len(answer.strip()) == 1:
                answer = {"choice": answer.strip().upper()}
            elif isinstance(answer, str) and answer.strip():
                answer = {"choice": OTHER, "text": answer.strip()}
            else:
                raise InputError(f"{where}: 'answer' must be an option letter or free text")

        clean.append(
            {
                "name": str(raw.get("name") or "").strip() or f"Decision {number}",
                "question": question,
                "why": str(raw.get("why") or "").strip(),
                "options": clean_options,
                "recommended": recommended,
                "pick": str(raw.get("pick") or "").strip(),
                "answer": answer,
            }
        )
    return str(data.get("title") or "").strip(), clean


def _text(obj, key, where):
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip():
        raise InputError(f"{where}: '{key}' is required")
    return " ".join(value.split())


# ---------------------------------------------------------------- state


class App:
    """All of the UI state. handle() takes one key name, nothing touches the terminal."""

    def __init__(self, decisions):
        self.decisions = decisions
        self.count = len(decisions)
        self.answers = [d.get("answer") for d in decisions]
        self.pos = 0  # 0..count-1 is a card, count is the summary
        self.cursor = 0
        self.moved = False
        self.typing = None  # text being typed for a custom answer
        self.done = None  # "go" or "cancelled"
        first_open = next((i for i, a in enumerate(self.answers) if a is None), self.count)
        self.goto(first_open)

    @property
    def on_summary(self):
        return self.pos == self.count

    def goto(self, pos):
        self.pos = max(0, min(self.count, pos))
        self.moved = False
        self.typing = None
        if not self.on_summary:
            decision = self.decisions[self.pos]
            answer = self.answers[self.pos]
            letter = answer["choice"] if answer and answer["choice"] != OTHER else decision["recommended"]
            self.cursor = LETTERS.index(letter)

    def enter_target(self):
        """What Enter will do on this card: a letter, or 'keep' for a custom answer."""
        answer = self.answers[self.pos]
        if answer and answer["choice"] == OTHER and not self.moved:
            return "keep"
        return LETTERS[self.cursor]

    def handle(self, key):
        if self.typing is not None:
            self._handle_typing(key)
        elif self.on_summary:
            self._handle_summary(key)
        else:
            self._handle_card(key)

    def _handle_card(self, key):
        options = self.decisions[self.pos]["options"]
        if key == "esc":
            self.done = "cancelled"
        elif key == "left":
            if self.pos > 0:
                self.goto(self.pos - 1)
        elif key == "right":
            self.goto(self.pos + 1)
        elif key in ("up", "down"):
            step = -1 if key == "up" else 1
            self.cursor = (self.cursor + step) % len(options)
            self.moved = True
        elif key == "enter":
            target = self.enter_target()
            if target != "keep":
                self.answers[self.pos] = {"choice": target}
            self.goto(self.pos + 1)
        elif key == "/":
            answer = self.answers[self.pos]
            self.typing = answer["text"] if answer and answer["choice"] == OTHER else ""
        elif key in ("backspace", "delete"):
            self.answers[self.pos] = None
            self.goto(self.pos)
        elif len(key) == 1 and key.upper() in LETTERS[: len(options)]:
            self.answers[self.pos] = {"choice": key.upper()}
            self.goto(self.pos + 1)

    def _handle_summary(self, key):
        if key == "esc":
            self.done = "cancelled"
        elif key == "enter":
            self.done = "go"
        elif key == "left":
            self.goto(self.count - 1)
        elif len(key) == 1 and key.isdigit() and 1 <= int(key) <= min(self.count, 9):
            self.goto(int(key) - 1)

    def _handle_typing(self, key):
        if key == "esc":
            self.typing = None
        elif key == "enter":
            text = " ".join(self.typing.split())
            if text:
                self.answers[self.pos] = {"choice": OTHER, "text": text}
                self.goto(self.pos + 1)
            else:
                self.typing = None
        elif key == "backspace":
            self.typing = self.typing[:-1]
        elif len(key) == 1 and key.isprintable():
            self.typing += key

    def result(self, status=None):
        answers = []
        for number, (decision, answer) in enumerate(zip(self.decisions, self.answers), 1):
            entry = {"n": number, "name": decision["name"], "choice": None}
            if answer and answer["choice"] == OTHER:
                entry.update(choice=OTHER, text=answer["text"])
            elif answer:
                letter = answer["choice"]
                entry.update(
                    choice=letter,
                    label=decision["options"][LETTERS.index(letter)]["label"],
                    recommended=letter == decision["recommended"],
                )
            answers.append(entry)
        return {"status": status or self.done or "cancelled", "answers": answers}


# ------------------------------------------------------------ rendering
#
# A line is a list of (text, style) segments. Widths are counted in
# characters, so the box drawing stays aligned without measuring ANSI codes.


def seg_len(line):
    return sum(len(text) for text, _ in line)


def fit(line, width):
    """Truncate or pad a line to exactly `width` characters."""
    out, used = [], 0
    for text, style in line:
        room = width - used
        if room <= 0:
            break
        if len(text) > room:
            text = text[: max(room - 1, 0)] + "…"
        out.append((text, style))
        used += len(text)
    if used < width:
        out.append((" " * (width - used), None))
    return out


def with_tag(line, tag, width):
    """Right-align the `tag` segments on a line of `width` characters."""
    if not tag:
        return line
    gap = width - seg_len(line) - seg_len(tag)
    return line + [(" " * max(gap, 1), None)] + tag


def wrap(text, width):
    return textwrap.wrap(text, max(width, 8)) or [""]


def dots(app):
    if app.count > 20:
        return []
    out = []
    for index in range(app.count):
        if index == app.pos:
            out.append(("◉", "accent_bold"))
        elif app.answers[index]:
            out.append(("●", None))
        else:
            out.append(("○", "dim"))
    return out


def card_body(app, pos, inner, spacing):
    """The lines inside the box for one card."""
    decision = app.decisions[pos]
    answer = app.answers[pos]
    current = pos == app.pos
    indent = 6
    lines = []

    def gap(level=1):
        if spacing >= level:
            lines.append([])

    gap()
    for text in wrap(decision["question"], inner):
        lines.append([(text, "bold")])
    gap()
    if decision["why"]:
        for index, text in enumerate(wrap(decision["why"], inner - indent)):
            lines.append([("WHY   " if index == 0 else " " * indent, "dim"), (text, None)])
        gap()

    for index, option in enumerate(decision["options"]):
        letter = LETTERS[index]
        chosen = bool(answer) and answer["choice"] == letter
        pointed = current and index == app.cursor
        # The chosen mark sits in the gutter so that answering never changes
        # how a label wraps, and the box keeps its height.
        tag = [("★ recommended", "accent")] if letter == decision["recommended"] else []
        label_width = inner - indent - (seg_len(tag) + 1 if tag else 0)
        label_style = "bold" if pointed or chosen else None
        for row, text in enumerate(wrap(option["label"], label_width)):
            if row == 0:
                head = [("▸ " if pointed else "  ", "accent_bold"), (letter, "accent_bold" if pointed else "bold"), (" ✓ " if chosen else "   ", "good")]
                lines.append(with_tag(head + [(text, label_style)], tag, inner))
            else:
                lines.append([(" " * indent, None), (text, label_style)])
        if option["detail"]:
            for text in wrap(option["detail"], inner - indent):
                lines.append([(" " * indent, None), (text, "dim")])
        if index < len(decision["options"]) - 1:
            gap(2)

    if answer and answer["choice"] == OTHER:
        gap(2)
        for row, text in enumerate(wrap(answer["text"], inner - indent)):
            if row == 0:
                lines.append([("  /", "bold"), (" ✓ ", "good"), (text, "bold")])
            else:
                lines.append([(" " * indent, None), (text, "bold")])

    if decision["pick"]:
        gap()
        pick = f"{decision['recommended']} - {decision['pick']}"
        for index, text in enumerate(wrap(pick, inner - indent)):
            lines.append([("PICK  " if index == 0 else " " * indent, "dim"), (text, None)])
    gap()
    return lines


def summary_body(app, inner, spacing):
    lines = [[]] if spacing else []
    name_width = min(max(len(d["name"]) for d in app.decisions), 22)
    number_width = len(str(app.count))
    for index, (decision, answer) in enumerate(zip(app.decisions, app.answers)):
        line = [
            (str(index + 1).rjust(number_width) + "  ", "dim"),
            (fit([(decision["name"], None)], name_width)[0][0].ljust(name_width) + "  ", None),
        ]
        tag = []
        if not answer:
            line += [("-  ", "dim"), ("open", "warn")]
        elif answer["choice"] == OTHER:
            line += [("/  ", "bold"), (answer["text"], None)]
            tag = [("(yours)", "accent")]
        else:
            letter = answer["choice"]
            line += [(letter + "  ", "bold"), (decision["options"][LETTERS.index(letter)]["label"], None)]
            if letter != decision["recommended"]:
                tag = [("(yours)", "accent")]
        room = inner - (seg_len(tag) + 1 if tag else 0)
        line = fit(line, room) if seg_len(line) > room else line
        lines.append(with_tag(line, tag, inner))
    if spacing:
        lines.append([])
    return lines


def body_for(app, pos, inner, spacing):
    if pos == app.count:
        return summary_body(app, inner, spacing)
    return card_body(app, pos, inner, spacing)


def hint_line(app):
    key = "bold"
    sep = ("  ·  ", "dim")
    if app.typing is not None:
        return [("Your answer ▸ ", "accent_bold"), (app.typing, None), ("█", "accent"), ("     enter", key), (" save", "dim"), sep, ("esc", key), (" back", "dim")]
    if app.on_summary:
        parts = [[("enter", key), (" go", "dim")], [("←", key), (" back", "dim")]]
        if app.count > 1:
            parts.append([(f"1-{min(app.count, 9)}", key), (" change", "dim")])
        parts.append([("esc", key), (" cancel", "dim")])
    else:
        options = app.decisions[app.pos]["options"]
        letters = " ".join(LETTERS[: len(options)].lower())
        target = app.enter_target()
        arrows = "← →" if app.pos > 0 else "→"
        parts = [
            [(letters, key), (" choose", "dim")],
            [("enter", key), (" keep" if target == "keep" else f" pick {target}", "dim")],
            [(arrows, key), (" move", "dim")],
            [("/", key), (" other", "dim")],
            [("esc", key), (" cancel", "dim")],
        ]
    line = []
    for index, part in enumerate(parts):
        if index:
            line.append(sep)
        line += part
    return line


def frame(app, cols, rows):
    """The full screen as a list of lines, sized to the terminal."""
    width = max(MIN_WIDTH, min(MAX_WIDTH, cols - 2))
    inner = width - 4
    chrome = 5  # top margin, two borders, blank line, hint
    positions = range(app.count + 1)

    # Use the roomiest spacing at which every card fits, so the box keeps
    # one height from the first card to the summary and nothing jumps.
    for spacing in (2, 1, 0):
        height = max(len(body_for(app, pos, inner, spacing)) for pos in positions)
        if height + chrome <= rows:
            break
    height = max(min(height, rows - chrome), 1)

    body = body_for(app, app.pos, inner, spacing)
    if len(body) > height:
        body = body[: height - 1] + [[("… make the window taller to see the rest", "warn")]]
    body += [[] for _ in range(height - len(body))]

    if app.on_summary:
        made = sum(1 for answer in app.answers if answer)
        title = f" DECISIONS {made} of {app.count} made "
    else:
        title = f" DECISION {app.pos + 1} of {app.count} "
    progress = dots(app)
    right = [(" ", None)] + progress + [(" ", None)] if progress else []
    fill = width - 3 - len(title) - seg_len(right) - 2
    if fill < 1:
        right, fill = [], width - 3 - len(title) - 2
    top = [("╭─", "dim"), (title, "bold"), ("─" * max(fill, 0), "dim")] + right + [("─╮", "dim")]

    lines = [[], [(" ", None)] + top]
    for line in body:
        lines.append([(" ", None), ("│ ", "dim")] + fit(line, inner) + [(" │", "dim")])
    lines.append([(" ", None), ("╰" + "─" * (width - 2) + "╯", "dim")])
    lines.append([])
    lines.append(fit([("  ", None)] + hint_line(app), max(cols - 1, 1)))
    return lines[:rows]


def paint(lines, color):
    out = []
    for line in lines:
        text = ""
        for chunk, style in line:
            if color and style:
                text += f"\x1b[{STYLES[style]}m{chunk}\x1b[0m"
            else:
                text += chunk
        out.append(text.rstrip() if not color else text)
    return out


# ------------------------------------------------------------- terminal

KEYS = {
    "\x1b[A": "up",
    "\x1b[B": "down",
    "\x1b[C": "right",
    "\x1b[D": "left",
    "\x1bOA": "up",
    "\x1bOB": "down",
    "\x1bOC": "right",
    "\x1bOD": "left",
    "\x1b[3~": "delete",
    "\r": "enter",
    "\n": "enter",
    "\x7f": "backspace",
    "\x08": "backspace",
    "\x03": "esc",
}


def parse_keys(data):
    """Split raw terminal input into key names."""
    keys, index = [], 0
    while index < len(data):
        for sequence, name in KEYS.items():
            if data.startswith(sequence, index):
                keys.append(name)
                index += len(sequence)
                break
        else:
            char = data[index]
            index += 1
            if char == "\x1b":
                if index < len(data) and data[index] in "[O":
                    # An escape sequence we do not use: swallow it whole.
                    index += 1
                    while index < len(data) and not ("@" <= data[index] <= "~"):
                        index += 1
                    index += 1
                else:
                    keys.append("esc")
            elif char.isprintable():
                keys.append(char)
    return keys


def read_keys(fd, timeout):
    ready, _, _ = select.select([fd], [], [], timeout)
    if not ready:
        return []
    data = os.read(fd, 1024)
    if not data:
        raise EOFError
    # A lone ESC may be the start of an arrow key still in transit.
    if data == b"\x1b" and select.select([fd], [], [], 0.05)[0]:
        data += os.read(fd, 1024)
    return parse_keys(data.decode("utf-8", "ignore"))


def write_result(path, result):
    temp = f"{path}.tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(temp, path)


def run(app, out_path):
    import termios
    import tty

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    color = not os.environ.get("NO_COLOR") and os.environ.get("TERM") != "dumb"

    def hangup(signum, _frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGHUP, hangup)
    signal.signal(signal.SIGTERM, hangup)

    try:
        tty.setcbreak(fd)
        sys.stdout.write("\x1b[?1049h\x1b[?25l")
        last = None
        while app.done is None:
            size = shutil.get_terminal_size((80, 24))
            screen = paint(frame(app, size.columns, size.lines), color)
            if screen != last:
                # Redraw in place: home, overwrite each line, clear what is left.
                sys.stdout.write("\x1b[H" + "\x1b[K\r\n".join(screen) + "\x1b[K\x1b[J")
                sys.stdout.flush()
                last = screen
            for key in read_keys(fd, 0.25):
                app.handle(key)
                if app.done is not None:
                    break
    except (KeyboardInterrupt, EOFError):
        app.done = "cancelled"
    finally:
        try:
            sys.stdout.write("\x1b[?25h\x1b[?1049l")
            sys.stdout.flush()
            termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        except (OSError, ValueError, termios.error):
            pass
        write_result(out_path, app.result())


def main(argv):
    if len(argv) == 3 and argv[1] == "--check":
        try:
            _, decisions = load(argv[2])
        except InputError as error:
            print(f"decision-cards: {error}", file=sys.stderr)
            return 2
        print(f"ok: {len(decisions)} decisions")
        return 0
    if len(argv) != 3 or argv[1].startswith("-"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        _, decisions = load(argv[1])
    except InputError as error:
        print(f"decision-cards: {error}", file=sys.stderr)
        return 2
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("decision-cards: needs an interactive terminal; use launch.sh", file=sys.stderr)
        return 3
    app = App(decisions)
    run(app, argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
