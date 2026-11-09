#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests for tools/make_homophones.py."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import lime2rime  # noqa: E402
import make_homophones  # noqa: E402
import make_zhuyin  # noqa: E402


class TestHomophones(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = ROOT / "data" / "liu7.cin"
        terra = ROOT / "data" / "terra_pinyin.dict.yaml"
        essay = ROOT / "data" / "essay.txt"
        for path in (source, terra, essay):
            if not path.exists():
                raise unittest.SkipTest(f"{path.name} not present")

        cls.entries, _fmt = lime2rime.read_source(source)
        rows = make_zhuyin.read_terra(terra)
        freq = make_zhuyin.read_essay(essay)
        cls.codes, cls.groups, cls.stats = make_homophones.build(
            cls.entries, rows, freq)

    def test_neo(self):
        entry = self.codes["neo"]
        self.assertEqual(entry["ref"], "同")
        self.assertEqual(entry["reading"], "wj/6")
        self.assertEqual(entry["bopomofo"], "ㄊㄨㄥˊ")
        group = self.groups[entry["reading"]]
        self.assertEqual(group[0], "同")
        for ch in ("銅", "童", "桐"):
            self.assertIn(ch, group)

    def test_qnmr(self):
        entry = self.codes["qnmr"]
        self.assertEqual(entry["ref"], "規")
        group = self.groups[entry["reading"]]
        self.assertIn("規", group)
        self.assertIn("龜", group)
        self.assertIn("歸", group)

    def test_doo(self):
        entry = self.codes["doo"]
        self.assertEqual(entry["ref"], "加")
        group = self.groups[entry["reading"]]
        for ch in ("家", "嘉", "佳"):
            self.assertIn(ch, group)

    def test_uoo_primary_reading(self):
        # 台 is polyphonic; the common reading is tai2, not the rare yi2.
        entry = self.codes["uoo"]
        self.assertEqual(entry["ref"], "台")
        self.assertEqual(entry["reading"], "w96")
        self.assertEqual(entry["bopomofo"], "ㄊㄞˊ")
        group = self.groups[entry["reading"]]
        for ch in ("臺", "抬", "颱", "苔"):
            self.assertIn(ch, group)

    def test_tone_is_exact(self):
        # doo is 加 (ㄐㄧㄚ first tone); jia3/jia4 characters must not leak.
        group = self.groups[self.codes["doo"]["reading"]]
        self.assertNotIn("假", group)
        self.assertNotIn("價", group)

    def test_reference_in_group(self):
        for code, entry in self.codes.items():
            self.assertIn(entry["ref"], self.groups[entry["reading"]],
                          msg=f"reference missing for {code}")

    def test_group_chars_are_in_table(self):
        table_chars = set()
        for code, text, _lineno in self.entries:
            if lime2rime.BOSHIAMY_CODE_RE.match(code) and len(text) == 1:
                table_chars.add(text)
        for reading, group in self.groups.items():
            for ch in group:
                self.assertIn(ch, table_chars, msg=f"{ch} in {reading}")

    def test_output_file_if_built(self):
        dist = ROOT / "dist" / "lua" / "boshiamy_homophones.lua"
        if not dist.exists():
            self.skipTest("dist not built")
        text = dist.read_text(encoding="utf-8")
        self.assertIn('["neo"] = "同\\twj/6\\tㄊㄨㄥˊ"', text)
        self.assertIn('["wj/6"] = "同\\t銅\\t童\\t桐', text)
        self.assertIn('["uoo"] = "台\\tw96\\tㄊㄞˊ"', text)


if __name__ == "__main__":
    unittest.main()
