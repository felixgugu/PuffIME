#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests for tools/make_zhuyin.py."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import make_zhuyin as z  # noqa: E402


class TestZhuyin(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = z.read_terra(ROOT / "data" / "terra_pinyin.dict.yaml")
        cls.freq = z.read_essay(ROOT / "data" / "essay.txt")
        (cls.items, cls.invalid, cls.too_long, cls.bad_chars,
         cls.readings, cls.stats) = z.build(cls.rows, cls.freq, 1000)
        cls.by_code = {}
        cls.by_text = {}
        for text, code, weight, kind in cls.items:
            cls.by_code.setdefault(code, []).append((text, weight))
            cls.by_text.setdefault(text, []).append((code, weight))
        cls.toneless = z.build_toneless(cls.readings, cls.freq)
        cls.toneless_by_code = {}
        for text, code, weight, _kind in cls.toneless:
            cls.toneless_by_code.setdefault(code, []).append((text, weight))
        cls.prefix_completion = z.build_prefix_completion(cls.items)

    def test_known_readings(self):
        cases = {
            "ni3": "su3",
            "yi1": "u",
            "shi4": "g4",
            "zhong1": "5j/",
            "guo2": "eji6",
            "nv3": "sm3",
            "lve4": "xm,4",
            "er2": "-6",
            "de5": "2k7",
            "hui4": "cjo4",
            "wen2": "jp6",
            "hang2": "c;6",
            "chang2": "t;6",
            "lv4": "xm4",
            "jun4": "rmp4",
            "qiu1": "fu.",
            "jiu4": "ru.4",
            "ni3 hao3": "su3cl3",
            "zhong1 guo2": "5j/eji6",
        }
        for pinyin, expected in cases.items():
            converted = z.convert_reading(pinyin)
            self.assertIsNotNone(converted, pinyin)
            self.assertEqual(converted[0], expected, pinyin)

    def test_candidate_order(self):
        self.assertEqual(self.by_code["su3"][0][0], "你")
        self.assertEqual(self.by_code["g4"][0][0], "是")
        self.assertEqual(self.by_code["ji3"][0][0], "我")
        # Tone-less code lists all tones, highest frequency first.
        self.assertEqual(self.by_code["su"][0][0], "你")
        self.assertEqual(self.by_code["ji"][0][0], "我")
        self.assertEqual(self.by_code["u"][0][0], "一")
        self.assertEqual(self.by_code["5j/"][0][0], "中")
        self.assertEqual(self.by_code["eji6"][0][0], "國")
        self.assertEqual(self.by_code["cl3"][0][0], "好")
        self.assertEqual(self.by_code["2k7"][0][0], "的")

    def test_phrases(self):
        self.assertIn("su3cl3", [code for code, _w in self.by_text["你好"]])
        self.assertIn("5j/eji6", [code for code, _w in self.by_text["中國"]])
        self.assertIn("rupwu0", [code for code, _w in self.by_text["今天"]])
        self.assertIn("ji3ap7", [code for code, _w in self.by_text["我們"]])

    def test_code_charset(self):
        for _text, code, _weight, _kind in self.items:
            self.assertTrue(0 < len(code) <= 64)
            self.assertTrue(all(ch in z.ALLOWED_CODE for ch in code), code)

    def test_counts(self):
        self.assertGreater(len(self.items), 100000)
        self.assertLess(len(self.invalid), 50)
        self.assertEqual(self.too_long, 0)
        self.assertEqual(self.bad_chars, 0)
        self.assertGreater(len(self.toneless), 10000)

    def test_toneless(self):
        su = [t for t, _w in self.toneless_by_code.get("su", [])]
        self.assertIn("你", su)
        self.assertIn("呢", su)
        self.assertIn("尼", su)
        self.assertIn("擬", su)
        self.assertNotIn("su3", self.toneless_by_code)
        for _text, code, _weight, _kind in self.toneless:
            self.assertNotEqual(code[-1], "3")
            self.assertNotEqual(code[-1], "4")
            self.assertNotEqual(code[-1], "6")
            self.assertNotEqual(code[-1], "7")

    def test_prefix_completion(self):
        pc = self.prefix_completion
        # A bare initial has no exact entry, so it gets a completion list.
        self.assertIn("1", pc)
        self.assertGreater(len(pc["1"]), 1000)
        self.assertEqual(pc["1"][0][0], "不")
        self.assertEqual(pc["q"][0][0], "怕")
        # Characters with the exact code stay out; only longer syllables are
        # added after the exact candidates.
        top5 = [text for text, _code in pc["5"]]
        self.assertNotIn("之", top5)
        self.assertEqual(pc["5"][0][0], "中")
        # Complete syllables without longer codes have no completion list.
        for code in ("18", "su3", "ji3", "1u0", "su3c"):
            self.assertNotIn(code, pc)
        # First-tone aliases are internal; never offer them as completions.
        for _prefix, entries in pc.items():
            for text, code in entries:
                self.assertNotIn("=", code, (text, code))

    def test_first_tone_alias(self):
        # Normal codes keep first tone implicit so existing input still works.
        self.assertEqual(z.convert_reading("ji1")[0], "ru")
        self.assertEqual(z.convert_reading("zhong1")[0], "5j/")
        # Marked aliases add one explicit first-tone marker per first tone.
        self.assertEqual(z.convert_reading_marked("ji1")[0], "ru=")
        self.assertEqual(z.convert_reading_marked("zhong1")[0], "5j/=")
        self.assertEqual(z.convert_reading_marked("ni3")[0], "su3")
        self.assertEqual(z.convert_reading_marked("ji1 cha2")[0], "ru=t86")
        # 稽 has both the toneless code and the first-tone alias.
        codes = [c for c, _w in self.by_text["稽"]]
        self.assertIn("ru", codes)
        self.assertIn("ru=", codes)
        self.assertIn("稽", [t for t, _w in self.by_code["ru="]])

    def test_prefix_completion_codes(self):
        pc = self.prefix_completion
        codes_by_text = {}
        for text, code, _weight, _kind in self.items:
            if len(text) == 1:
                codes_by_text.setdefault(text, set()).add(code)
        for prefix, entries in pc.items():
            self.assertGreater(len(prefix), 0)
            seen = set()
            for text, code in entries:
                self.assertNotIn(text, seen, prefix)
                seen.add(text)
                self.assertTrue(code.startswith(prefix), (prefix, code))
                self.assertNotIn(prefix, codes_by_text[text], (prefix, text))

    def test_dist_file_if_built(self):
        dist = ROOT / "dist" / "puffzhuyin.dict.yaml"
        if not dist.exists():
            self.skipTest("dist not built")
        text = dist.read_text(encoding="utf-8")
        self.assertIn("你\tsu3\t", text)
        self.assertIn("你好\tsu3cl3\t", text)
        self.assertIn("中國\t5j/eji6\t", text)
        self.assertIn("中國\t5j/=eji6\t", text)
        # Tone-less single-syllable codes are merged into the same dictionary.
        self.assertIn("你\tsu\t", text)
        self.assertIn("呢\tsu\t", text)
        self.assertIn("擬\tsu\t", text)
        self.assertIn("我\tji\t", text)
        # First-tone alias used by the space key.
        self.assertIn("稽\tru=\t", text)

    def test_completion_file_if_built(self):
        path = ROOT / "dist" / "lua" / "zhuyin_completion_data.lua"
        if not path.exists():
            self.skipTest("dist not built")
        text = path.read_text(encoding="utf-8")
        self.assertIn('["1"]', text)
        self.assertIn('["1u"]', text)
        self.assertNotIn('["18"]', text)
        # Tabs are escaped in the generated Lua string literal.
        self.assertIn("不\\t", text)


if __name__ == "__main__":
    unittest.main()
