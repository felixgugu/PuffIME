#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build a Zhuyin (Bopomofo, Dachen keyboard) Rime table dictionary.

Sources:
    data/terra_pinyin.dict.yaml  -- pinyin readings (single chars + phrases)
    data/essay.txt               -- character / phrase frequencies

Pipeline:
    pinyin (with tone digit) -> bopomofo -> Dachen key code

Examples:
    ni3      -> ㄋㄧˇ   -> su3
    yi1      -> ㄧ     -> u
    shi4     -> ㄕˋ    -> g4
    zhong1   -> ㄓㄨㄥ  -> 5j/
    guo2     -> ㄍㄨㄛˊ -> eji6
    nv3      -> ㄋㄩˇ   -> sm3
    er2      -> ㄦˊ    -> -6
    de5      -> ㄉㄜ˙   -> 2k7
    ni3 hao3 -> ㄋㄧˇㄏㄠˇ -> su3cl3

Tone 1 is the default and gets no key.  Tones 2/3/4/5 map to 6/3/4/7,
the standard Dachen layout.

Outputs:
    dist/puffzhuyin.dict.yaml              -- Rime table dictionary
    dist/lua/zhuyin_completion_data.lua    -- prefix -> characters by weight

Usage:
    python tools/make_zhuyin.py
    python tools/make_zhuyin.py --min-phrase-weight 1000
"""

from __future__ import annotations

import argparse
import collections
import io
import sys
from pathlib import Path

# bopomofo -> Dachen key
BOPOMOFO_TO_KEY = {
    "ㄅ": "1", "ㄆ": "q", "ㄇ": "a", "ㄈ": "z",
    "ㄉ": "2", "ㄊ": "w", "ㄋ": "s", "ㄌ": "x",
    "ㄍ": "e", "ㄎ": "d", "ㄏ": "c",
    "ㄐ": "r", "ㄑ": "f", "ㄒ": "v",
    "ㄓ": "5", "ㄔ": "t", "ㄕ": "g", "ㄖ": "b",
    "ㄗ": "y", "ㄘ": "h", "ㄙ": "n",
    "ㄧ": "u", "ㄨ": "j", "ㄩ": "m",
    "ㄚ": "8", "ㄛ": "i", "ㄜ": "k", "ㄝ": ",",
    "ㄞ": "9", "ㄟ": "o", "ㄠ": "l", "ㄡ": ".",
    "ㄢ": "0", "ㄣ": "p", "ㄤ": ";", "ㄥ": "/", "ㄦ": "-",
}

# Normal codes: the first tone is omitted, so `ru` (ㄐㄧ) lists every tone.
TONE_TO_KEY = {"1": "", "2": "6", "3": "3", "4": "4", "5": "7"}

# First-tone alias codes: the same reading with one explicit first-tone marker.
# The schema maps the marker to ˉ, and the Lua space handler turns a plain
# space into this marker so `ru` + Space shows only the ㄐㄧ first-tone list.
FIRST_TONE_KEY = "="
MARKED_TONE_TO_KEY = {"1": FIRST_TONE_KEY, "2": "6", "3": "3", "4": "4", "5": "7"}

# Tone key -> Bopomofo display symbol (first tone is normally omitted).
TONE_SYMBOLS = {"6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙", FIRST_TONE_KEY: "ˉ"}

INITIALS = {
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ",
    "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ",
    "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
    "j": "ㄐ", "q": "ㄑ", "x": "ㄒ",
    "zh": "ㄓ", "ch": "ㄔ", "sh": "ㄕ", "r": "ㄖ",
    "z": "ㄗ", "c": "ㄘ", "s": "ㄙ",
}

FINALS = {
    "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "ê": "ㄝ",
    "ai": "ㄞ", "ei": "ㄟ", "ao": "ㄠ", "ou": "ㄡ",
    "an": "ㄢ", "en": "ㄣ", "ang": "ㄤ", "eng": "ㄥ", "er": "ㄦ",
    "i": "ㄧ", "ia": "ㄧㄚ", "ie": "ㄧㄝ", "iao": "ㄧㄠ",
    "iou": "ㄧㄡ", "ian": "ㄧㄢ", "in": "ㄧㄣ", "iang": "ㄧㄤ",
    "ing": "ㄧㄥ", "iong": "ㄩㄥ", "io": "ㄧㄛ",
    "u": "ㄨ", "ua": "ㄨㄚ", "uo": "ㄨㄛ", "uai": "ㄨㄞ",
    "uei": "ㄨㄟ", "uan": "ㄨㄢ", "uen": "ㄨㄣ",
    "uang": "ㄨㄤ", "ueng": "ㄨㄥ", "ong": "ㄨㄥ",
    "ü": "ㄩ", "üe": "ㄩㄝ", "üan": "ㄩㄢ", "ün": "ㄩㄣ",
}

ZERO_INITIAL = {
    "yi": "i", "ya": "ia", "ye": "ie", "yao": "iao", "you": "iou",
    "yan": "ian", "yin": "in", "yang": "iang", "ying": "ing",
    "yong": "iong", "yo": "io",
    "yu": "ü", "yue": "üe", "yuan": "üan", "yun": "ün",
    "wu": "u", "wa": "ua", "wo": "uo", "wai": "uai", "wei": "uei",
    "wan": "uan", "wen": "uen", "wang": "uang", "weng": "ueng",
}

ALLOWED_CODE = set("1qaz2wsxedcrfv5tgbyhnujm8ik,9ol.0p;/-6347=")

INITIAL_ORDER = ("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l",
                 "g", "k", "h", "j", "q", "x", "r", "z", "c", "s")

MAX_VARIANTS = 8
MAX_READINGS_PER_CHAR = 3


def convert_syllable(raw: str, tone_map=None):
    """pinyin syllable -> (bopomofo, tone_key) or None."""
    if tone_map is None:
        tone_map = TONE_TO_KEY
    raw = raw.strip().lower().replace("u:", "ü").replace("v", "ü")
    if not raw:
        return None
    tone = "1"
    if raw[-1] in "12345":
        tone = raw[-1]
        raw = raw[:-1]
    if not raw:
        return None

    if raw == "r":
        raw = "er"

    if raw in ("m", "n"):
        return ({"m": "ㄇ", "n": "ㄋ"}[raw], tone_map[tone])
    if raw in ("hm", "hng", "ng"):
        return None

    if raw in FINALS:
        return (FINALS[raw], tone_map[tone])
    if raw in ZERO_INITIAL:
        final = ZERO_INITIAL[raw]
        if final not in FINALS:
            return None
        return (FINALS[final], tone_map[tone])

    initial = ""
    for cand in INITIAL_ORDER:
        if raw.startswith(cand):
            initial = cand
            break
    if not initial:
        return None
    final = raw[len(initial):]

    # Apical vowels: zhi chi shi ri zi ci si
    if final == "i" and initial in ("zh", "ch", "sh", "r", "z", "c", "s"):
        return (INITIALS[initial], tone_map[tone])

    if initial in ("j", "q", "x"):
        if final == "u":
            final = "ü"
        elif final == "ue":
            final = "üe"
        elif final == "uan":
            final = "üan"
        elif final == "un":
            final = "ün"
        elif final == "iu":
            final = "iou"
    else:
        if final == "ui":
            final = "uei"
        elif final == "iu":
            final = "iou"
        elif final == "un":
            final = "uen"
    if initial in ("n", "l") and final == "ue":
        final = "üe"

    if final not in FINALS:
        return None
    return (INITIALS[initial] + FINALS[final], tone_map[tone])


def bopomofo_to_code(bopomofo: str, tone_key: str) -> str | None:
    try:
        return "".join(BOPOMOFO_TO_KEY[ch] for ch in bopomofo) + tone_key
    except KeyError:
        return None


def convert_reading(pinyin: str, tone_map=None):
    """Convert a (possibly multi-syllable) pinyin reading to (code, bopomofo)."""
    if tone_map is None:
        tone_map = TONE_TO_KEY
    code = []
    bopomofo = []
    for raw in pinyin.split():
        converted = convert_syllable(raw, tone_map)
        if converted is None:
            return None
        bo, tone = converted
        key = bopomofo_to_code(bo, tone)
        if key is None:
            return None
        code.append(key)
        bopomofo.append(bo + TONE_SYMBOLS.get(tone, ""))
    return "".join(code), "".join(bopomofo)


def convert_reading_marked(pinyin: str):
    """Convert a reading to a code with an explicit first-tone marker.

    Non-first tones are identical to convert_reading(); only first-tone
    syllables gain FIRST_TONE_KEY (e.g. ji1 -> ru=, ji1 cha2 -> ru=t86).
    """
    return convert_reading(pinyin, MARKED_TONE_TO_KEY)


def parse_weight(token: str | None) -> float:
    if not token:
        return 0.0
    token = token.strip()
    if token.endswith("%"):
        try:
            return float(token[:-1])
        except ValueError:
            return 0.0
    try:
        return float(token)
    except ValueError:
        return 0.0


def read_terra(path: Path):
    """Return (text, pinyin, weight) rows from terra_pinyin.dict.yaml."""
    lines = path.read_text(encoding="utf-8").splitlines()
    in_body = False
    rows = []
    for line in lines:
        if not in_body:
            if line.strip() == "...":
                in_body = True
            continue
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        text = parts[0].strip()
        pinyin = parts[1].strip()
        weight = parse_weight(parts[2] if len(parts) > 2 else None)
        if not text or not pinyin:
            continue
        rows.append((text, pinyin, weight))
    return rows


def read_essay(path: Path):
    """Return {text: weight} from rime essay.txt."""
    freq = {}
    if not path.exists():
        return freq
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        try:
            freq[parts[0]] = int(parts[1])
        except ValueError:
            pass
    return freq


def build_readings(rows, tone_map=None):
    """char -> list of (reading_weight, code, pinyin), deduped by code."""
    if tone_map is None:
        tone_map = TONE_TO_KEY
    readings = collections.defaultdict(dict)
    for text, pinyin, weight in rows:
        if len(text) != 1:
            continue
        converted = convert_reading(pinyin, tone_map)
        if converted is None:
            continue
        code, _bo = converted
        if not code:
            continue
        old = readings[text].get(code)
        if old is None or weight > old[0]:
            readings[text][code] = (weight, pinyin)
    return {
        ch: [(w, code, pinyin) for code, (w, pinyin) in sorted(d.items(), key=lambda kv: -kv[1][0])]
        for ch, d in readings.items()
    }


def phrase_variants(text: str, readings, limit: int = MAX_VARIANTS):
    """Return up to `limit` Zhuyin codes for a phrase, best reading first."""
    options = []
    for ch in text:
        rs = readings.get(ch)
        if not rs:
            return []
        codes = []
        for _w, code, _p in rs[:MAX_READINGS_PER_CHAR]:
            if code not in codes:
                codes.append(code)
        options.append(codes)

    results = []

    def dfs(i, acc):
        if len(results) >= limit:
            return
        if i == len(options):
            results.append("".join(acc))
            return
        for code in options[i]:
            dfs(i + 1, acc + [code])
            if len(results) >= limit:
                return

    dfs(0, [])
    return results


def valid_code(code: str) -> bool:
    return 0 < len(code) <= 64 and all(ch in ALLOWED_CODE for ch in code)


def build_prefix_completion(items):
    """Build prefix -> [(character, matching code)] for incomplete codes.

    Typing a bare initial such as 1 (ㄅ) is not a syllable, so the table has
    no exact entry for it.  Prefix completion lists every character whose
    code starts with the typed keys, ordered by dictionary weight (essay
    frequency + reading percentage).

    Characters that already have the exact code are left to the table
    translator, which keeps exact candidates first in table/weight order.
    This is the same rule as tools/make_hints.py uses for Boshiamy.
    """
    codes_by_text = collections.defaultdict(set)
    for text, code, _weight, _kind in items:
        if len(text) == 1 and "=" not in code:
            codes_by_text[text].add(code)

    best = collections.defaultdict(dict)  # prefix -> text -> (weight, code)
    for text, code, weight, _kind in items:
        if len(text) != 1 or "=" in code:
            continue
        for i in range(1, len(code)):
            prefix = code[:i]
            if prefix in codes_by_text[text]:
                continue
            old = best[prefix].get(text)
            if old is None or weight > old[0]:
                best[prefix][text] = (weight, code)

    result = {}
    for prefix, chars in best.items():
        ordered = sorted(chars.items(), key=lambda kv: (-kv[1][0], kv[0]))
        result[prefix] = [(text, code) for text, (_w, code) in ordered]
    return result


def build(rows, freq, min_phrase_weight: int):
    entries = {}
    readings = build_readings(rows)
    readings_marked = build_readings(rows, MARKED_TONE_TO_KEY)
    invalid = []
    too_long = 0
    bad_chars = 0
    first_tone_entries = 0

    # 1) Single-character entries: every reading from terra, ordered by essay
    #    frequency (fallback: reading percentage).
    for text, pinyin, weight in rows:
        if len(text) != 1:
            continue
        converted = convert_reading(pinyin)
        if converted is None:
            invalid.append((text, pinyin))
            continue
        code, _bo = converted
        if not valid_code(code):
            if len(code) > 64:
                too_long += 1
            else:
                bad_chars += 1
            continue
        w = freq.get(text, 0) + weight / 100.0 + 1.0
        key = (text, code)
        if key not in entries or w > entries[key][0]:
            entries[key] = (w, "single")

        # Alias with an explicit first-tone marker (ji1 -> ru=).  The normal
        # code above stays, so existing input and phrase codes do not break.
        marked = convert_reading(pinyin, MARKED_TONE_TO_KEY)
        if marked is not None:
            mcode, _bo = marked
            if mcode != code and valid_code(mcode):
                mkey = (text, mcode)
                if mkey not in entries or w > entries[mkey][0]:
                    if mkey not in entries:
                        first_tone_entries += 1
                    entries[mkey] = (w, "single-first-tone")

    # 2) Terra's own multi-character entries (rare words / fixed phrases).
    for text, pinyin, weight in rows:
        if len(text) <= 1:
            continue
        converted = convert_reading(pinyin)
        if converted is None:
            invalid.append((text, pinyin))
            continue
        code, _bo = converted
        if not valid_code(code):
            if len(code) > 64:
                too_long += 1
            else:
                bad_chars += 1
            continue
        w = freq.get(text, 0) + weight + 1.0
        key = (text, code)
        if key not in entries or w > entries[key][0]:
            entries[key] = (w, "terra-phrase")

        marked = convert_reading(pinyin, MARKED_TONE_TO_KEY)
        if marked is not None:
            mcode, _bo = marked
            if mcode != code and valid_code(mcode):
                mkey = (text, mcode)
                if mkey not in entries or w > entries[mkey][0]:
                    if mkey not in entries:
                        first_tone_entries += 1
                    entries[mkey] = (w, "terra-phrase-first-tone")

    # 3) Common phrases from essay.txt, with reading variants.  Generate both
    #    the normal (first tone omitted) code and the marked alias, so `5j/eji6`
    #    and `5j/=eji6` both reach 中國.
    phrase_count = 0
    skipped_no_reading = 0
    for text, w in freq.items():
        if not (2 <= len(text) <= 5) or w < min_phrase_weight:
            continue
        codes = phrase_variants(text, readings)
        if not codes:
            skipped_no_reading += 1
            continue
        for code in codes:
            if not valid_code(code):
                continue
            key = (text, code)
            value = (float(w), "essay-phrase")
            if key not in entries or value[0] > entries[key][0]:
                entries[key] = value
                phrase_count += 1
        marked_codes = phrase_variants(text, readings_marked)
        for mcode in marked_codes:
            if mcode in codes or not valid_code(mcode):
                continue
            mkey = (text, mcode)
            if mkey not in entries or w > entries[mkey][0]:
                if mkey not in entries:
                    first_tone_entries += 1
                entries[mkey] = (float(w), "essay-phrase-first-tone")

    # 4) Tone-less single-character codes.  Typing `su` matches every tone;
    #    the exact toned codes above still make `su3` narrow to tone 3.
    #    Merging them into one dictionary (instead of a second translator)
    #    keeps all candidates in a single frequency-ordered list.
    for text, code, w, _kind in build_toneless(readings, freq):
        key = (text, code)
        if key not in entries or w > entries[key][0]:
            entries[key] = (w, "toneless")

    items = []
    for (text, code), (w, kind) in entries.items():
        items.append((text, code, w, kind))
    items.sort(key=lambda x: (-x[2], x[0], x[1]))
    return items, invalid, too_long, bad_chars, readings, {
        "phrase_entries": phrase_count,
        "skipped_no_reading": skipped_no_reading,
        "first_tone_entries": first_tone_entries,
    }


def build_toneless(readings, freq):
    """Single-character entries with the tone digit removed from the code.

    Typing `su` can then match every tone variant; typing `su3` still matches
    only the exact tone-3 entry in the normal dictionary.
    """
    entries = {}
    for text, rs in readings.items():
        for weight, code, _pinyin in rs:
            if code and code[-1] in "3467":
                toneless = code[:-1]
            else:
                toneless = code
            if not toneless or not valid_code(toneless):
                continue
            w = freq.get(text, 0) + weight / 100.0 + 1.0
            key = (text, toneless)
            if key not in entries or w > entries[key]:
                entries[key] = w
    items = [(text, code, w, "toneless") for (text, code), w in entries.items()]
    items.sort(key=lambda x: (-x[2], x[0], x[1]))
    return items


def write_dict(items, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    out = io.StringIO()
    out.write("# Rime dictionary\n")
    out.write("# Generated by tools/make_zhuyin.py\n")
    out.write("# Sources: data/terra_pinyin.dict.yaml, data/essay.txt\n")
    out.write("# Do not edit by hand.\n")
    out.write("---\n")
    out.write("name: puffzhuyin\n")
    out.write('version: "0.1"\n')
    out.write("sort: by_weight\n")
    out.write("use_preset_vocabulary: false\n")
    out.write("...\n")
    out.write("\n")
    for text, code, weight, _kind in items:
        out.write(f"{text}\t{code}\t{weight:g}\n")
    output.write_text(out.getvalue(), encoding="utf-8")


def lua_quote(s: str) -> str:
    return ('"' + s.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\r", "\\r")
            .replace("\t", "\\t") + '"')


def write_completion(by_prefix, output: Path) -> None:
    """Write the Lua prefix table consumed by src/lua/zhuyin_completion.lua."""
    output.parent.mkdir(parents=True, exist_ok=True)
    out = io.StringIO()
    out.write("-- Generated by tools/make_zhuyin.py.  Do not edit.\n")
    out.write("-- prefix -> characters sorted by essay frequency.\n")
    out.write("-- Characters with an exact code are handled by the table\n")
    out.write("-- translator and are excluded here.\n")
    out.write("return {\n")
    for prefix in sorted(by_prefix):
        records = "".join(f"{text}\t{code}\n" for text, code in by_prefix[prefix])
        out.write(f"  [{lua_quote(prefix)}] = {lua_quote(records)},\n")
    out.write("}\n")
    output.write_text(out.getvalue(), encoding="utf-8")


def write_report(rows, items, invalid, too_long, bad_chars, readings, stats, completion,
                 output: Path):
    out = io.StringIO()
    w = lambda *a: print(*a, file=out)
    kinds = collections.Counter(k for _t, _c, _w, k in items)
    w("# terra_pinyin + essay -> Zhuyin dictionary report")
    w(f"source rows: {len(rows)}")
    w(f"dictionary entries: {len(items)}")
    w(f"tone-less entries merged: {kinds.get('toneless', 0)}")
    w(f"first-tone alias entries: {stats.get('first_tone_entries', 0)}")
    w("entry kinds: " + ", ".join(f"{k}:{v}" for k, v in kinds.items()))
    w(f"invalid readings skipped: {len(invalid)}")
    if invalid:
        w("  first 40: " + ", ".join(f"{t}={p}" for t, p in invalid[:40]))
    w(f"codes longer than 64 skipped: {too_long}")
    w(f"codes with bad chars skipped: {bad_chars}")
    w(f"essay phrases skipped (no reading): {stats['skipped_no_reading']}")
    w("code length distribution: " + ", ".join(
        f"{n}:{sum(1 for i in items if len(i[1]) == n)}" for n in range(1, 33)))
    by_text = collections.defaultdict(list)
    for text, code, weight, _kind in items:
        by_text[text].append((code, weight))
    w("known single-character checks:")
    wanted = {"你": "su3", "一": "u", "是": "g4", "中": "5j/", "國": "eji6",
              "女": "sm3", "略": "xm,4", "兒": "-6", "的": "2k7", "會": "cjo4",
              "文": "jp6", "行": "c;6", "長": "t;6", "綠": "xm4", "我": "ji3",
              "好": "cl3", "天": "wu0", "稽": "ru="}
    for text, expected in wanted.items():
        got = [c for c, _w in by_text.get(text, [])]
        w(f"  {text}: expected {expected}, got {got[:6]} {'OK' if expected in got else 'MISS'}")
    w("known phrase checks (codes generated):")
    for text in ["你好", "中國", "今天", "時間", "我們", "電腦", "手機", "謝謝"]:
        got = [c for c, _w in by_text.get(text, [])]
        w(f"  {text}: {got[:8]}")
    w("top candidates for common codes:")
    for code in ["su3", "g4", "ji3", "u", "5j/", "eji6", "cl3", "2k7", "su3cl3", "5j/eji6"]:
        hits = [(t, w_) for t, c, w_, _k in items if c == code][:10]
        w(f"  {code}: " + ", ".join(f"{t}({w_:g})" for t, w_ in hits))
    w(f"prefix completion: {len(completion)} prefixes, "
      f"{sum(len(v) for v in completion.values())} entries")
    for prefix in ["1", "q", "5", "5j", "18", "1u", "su", "su3"]:
        if prefix in completion:
            w(f"  completion[{prefix}]: " +
              " ".join(f"{t}({c})" for t, c in completion[prefix][:20]))
        else:
            w(f"  completion[{prefix}]: (none)")
    w("sample entries: " + ", ".join(f"{t}={c}" for t, c, _w, _k in items[:30]))
    output.parent.joinpath("zhuyin-report.txt").write_text(out.getvalue(), encoding="utf-8")


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=root / "data" / "terra_pinyin.dict.yaml")
    parser.add_argument("--essay", type=Path, default=root / "data" / "essay.txt")
    parser.add_argument("--output", type=Path, default=root / "dist" / "puffzhuyin.dict.yaml")
    parser.add_argument("--completion-output", type=Path,
                        default=root / "dist" / "lua" / "zhuyin_completion_data.lua")
    parser.add_argument("--min-phrase-weight", type=int, default=1000)
    args = parser.parse_args()

    rows = read_terra(args.input)
    freq = read_essay(args.essay)
    items, invalid, too_long, bad_chars, readings, stats = build(rows, freq, args.min_phrase_weight)
    completion = build_prefix_completion(items)
    write_dict(items, args.output)
    write_completion(completion, args.completion_output)
    write_report(rows, items, invalid, too_long, bad_chars, readings, stats, completion,
                 args.output)
    print(f"rows: {len(rows)}  essay: {len(freq)}  entries: {len(items)}  "
          f"invalid: {len(invalid)}  completion: {len(completion)}  "
          f"output: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
