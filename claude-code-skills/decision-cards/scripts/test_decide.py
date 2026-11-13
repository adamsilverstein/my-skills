#!/usr/bin/env python3
"""Tests for decide.py. Run: python3 test_decide.py"""

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import decide  # noqa: E402

EXAMPLE = os.path.join(HERE, "example.json")


def new_app():
    _, decisions = decide.load(EXAMPLE)
    return decide.App(decisions)


def press(app, *keys):
    for key in keys:
        app.handle(key)


def choices(app):
    return [answer["choice"] for answer in app.result()["answers"]]


class StateTest(unittest.TestCase):
    def test_letter_answers_and_advances_without_enter(self):
        app = new_app()
        press(app, "b")
        self.assertEqual(app.pos, 1)
        self.assertEqual(choices(app)[0], "B")

    def test_letter_not_on_card_is_ignored(self):
        app = new_app()
        press(app, "right")  # card 2 has only A and B
        press(app, "c")
        self.assertEqual(app.pos, 1)
        self.assertIsNone(choices(app)[1])

    def test_enter_accepts_recommendation(self):
        app = new_app()
        press(app, *["enter"] * 5)
        self.assertTrue(app.on_summary)
        self.assertEqual(choices(app), ["A", "A", "A", "B", "B"])
        self.assertTrue(all(a["recommended"] for a in app.result()["answers"]))

    def test_enter_keeps_an_earlier_answer(self):
        app = new_app()
        press(app, "c", "left", "enter")
        self.assertEqual(choices(app)[0], "C")

    def test_arrows_navigate_and_leave_cards_open(self):
        app = new_app()
        press(app, "left")
        self.assertEqual(app.pos, 0)
        press(app, "right", "right", "left")
        self.assertEqual(app.pos, 1)
        self.assertEqual(choices(app)[:2], [None, None])

    def test_up_down_moves_the_highlight(self):
        app = new_app()
        press(app, "down", "enter")
        self.assertEqual(choices(app)[0], "B")
        press(app, "up", "enter")  # card 2: wraps from A to B
        self.assertEqual(choices(app)[1], "B")

    def test_escape_cancels_from_a_card_and_from_the_summary(self):
        app = new_app()
        press(app, "a", "esc")
        self.assertEqual(app.result()["status"], "cancelled")
        app = new_app()
        press(app, *["enter"] * 5, "esc")
        self.assertEqual(app.done, "cancelled")

    def test_summary_enter_goes_and_left_goes_back(self):
        app = new_app()
        press(app, *["enter"] * 5, "left")
        self.assertEqual(app.pos, 4)
        press(app, "a")
        self.assertTrue(app.on_summary)
        press(app, "enter")
        self.assertEqual(app.done, "go")
        self.assertEqual(choices(app)[4], "A")
        self.assertFalse(app.result()["answers"][4]["recommended"])

    def test_summary_number_jumps_to_that_card(self):
        app = new_app()
        press(app, *["enter"] * 5, "3")
        self.assertEqual(app.pos, 2)

    def test_custom_answer(self):
        app = new_app()
        press(app, "/", *"use env var", "backspace", "enter")
        self.assertEqual(app.pos, 1)
        self.assertEqual(app.result()["answers"][0], {"n": 1, "name": "Retry limit", "choice": "other", "text": "use env va"})

    def test_escape_while_typing_only_leaves_the_input(self):
        app = new_app()
        press(app, "/", "a", "esc")
        self.assertIsNone(app.done)
        self.assertIsNone(app.typing)
        self.assertIsNone(choices(app)[0])

    def test_preset_answers_start_on_first_open_card(self):
        _, decisions = decide.load(EXAMPLE)
        decisions[0]["answer"] = {"choice": "B"}
        app = decide.App(decisions)
        self.assertEqual(app.pos, 1)
        self.assertEqual(choices(app)[0], "B")


class InputTest(unittest.TestCase):
    def check(self, data):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(data, handle)
        try:
            return decide.load(handle.name)
        finally:
            os.unlink(handle.name)

    def test_rejects_bad_input(self):
        good = {"question": "Q?", "options": ["x", "y"], "recommended": "A"}
        self.check({"decisions": [good]})
        for bad in (
            {"decisions": []},
            {"decisions": [dict(good, recommended="C")]},
            {"decisions": [dict(good, options=["x"])]},
            {"decisions": [dict(good, question="")]},
        ):
            with self.assertRaises(decide.InputError):
                self.check(bad)

    def test_control_characters_are_stripped(self):
        evil = "x\x1b[2Jy\nz\x07"
        _, decisions = self.check({"decisions": [{
            "name": evil, "question": evil, "why": evil, "pick": evil, "answer": evil + " more",
            "options": [{"label": evil, "detail": evil}, evil], "recommended": "A",
        }]})
        screen = "\n".join(decide.paint(decide.frame(decide.App(decisions), 80, 32), color=False))
        screen += json.dumps(decisions, ensure_ascii=False)
        self.assertNotIn("\x1b", screen)
        self.assertNotIn("\x07", screen)
        self.assertIn("x[2Jy z", screen)

    def test_parse_keys(self):
        self.assertEqual(decide.parse_keys("a\x1b[D\x1b[C\r"), ["a", "left", "right", "enter"])
        self.assertEqual(decide.parse_keys("\x1b"), ["esc"])
        self.assertEqual(decide.parse_keys("\x1b[5~b"), ["b"])


class RenderTest(unittest.TestCase):
    def screens(self, cols, rows):
        app = new_app()
        out = []
        for _ in range(app.count + 1):
            out.append(decide.paint(decide.frame(app, cols, rows), color=False))
            app.handle("enter")
        return out

    def test_box_keeps_its_place_across_cards(self):
        for cols, rows in ((80, 32), (80, 24), (60, 20), (120, 50)):
            screens = self.screens(cols, rows)
            for screen in screens:
                self.assertLessEqual(len(screen), rows)
                self.assertTrue(all(len(line) < cols for line in screen), (cols, rows))
                self.assertEqual(len(screen), len(screens[0]))
                bottom = [i for i, line in enumerate(screen) if line.startswith(" ╰")]
                self.assertEqual(bottom, [len(screens[0]) - 3])

    def test_card_content(self):
        first, *_, summary = self.screens(80, 32)
        text = "\n".join(first)
        self.assertIn("DECISION 1 of 5", text)
        self.assertIn("◉○○○○", text)
        self.assertIn("▸ A   Shared constant in config.ts", text)
        self.assertIn("★ recommended", text)
        self.assertIn("esc cancel", text)
        text = "\n".join(summary)
        self.assertIn("DECISIONS 5 of 5 made", text)
        self.assertIn("enter go", text)


class TerminalTest(unittest.TestCase):
    def drive(self, keys):
        """Run decide.py on a pseudo terminal, send keys, return (result, output)."""
        with tempfile.TemporaryDirectory() as folder:
            result_path = os.path.join(folder, "result.json")
            master, slave = pty.openpty()
            env = dict(os.environ, TERM="xterm-256color", COLUMNS="80", LINES="32")
            process = subprocess.Popen(
                [sys.executable, os.path.join(HERE, "decide.py"), EXAMPLE, result_path],
                stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True,
            )
            os.close(slave)
            output = b""
            deadline = time.time() + 10
            pending = list(keys)
            while time.time() < deadline and process.poll() is None:
                if select.select([master], [], [], 0.2)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
                elif pending:
                    os.write(master, pending.pop(0))
            process.wait(timeout=5)
            os.close(master)
            with open(result_path, encoding="utf-8") as handle:
                return json.load(handle), output.decode("utf-8", "ignore")

    def test_keys_without_enter_then_go(self):
        result, output = self.drive([b"b", b"\x1b[D", b"\x1b[C", b"\r", b"\r", b"a", b"\r", b"\r"])
        self.assertEqual(result["status"], "go")
        self.assertEqual([a["choice"] for a in result["answers"]], ["B", "A", "A", "A", "B"])
        self.assertIn("\x1b[?1049h", output)  # alternate screen: no scrollback
        self.assertIn("\x1b[?1049l", output)
        self.assertNotIn("\x1b[2J", output)

    def test_escape_cancels(self):
        result, _ = self.drive([b"a", b"\x1b"])
        self.assertEqual(result["status"], "cancelled")
        self.assertEqual(result["answers"][0]["choice"], "A")


if __name__ == "__main__":
    unittest.main()
