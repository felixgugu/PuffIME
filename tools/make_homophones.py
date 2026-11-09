#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the homophone lookup data for the `'` prefix.

Typing `'` followed by a normal Boshiamy code lists every character with the
same pronunciation as the code's first character.  Example:

    'neo  -> 同, 銅, 童, 桐, ...

The reference character (同) is the first candidate; the rest are ordered by
essay.txt frequency.

Sources:
    data/liu7.cin / boshiamy.lime  -- code -> character
    data/terra_pinyin.dict.yaml    -- character -> pinyin readings
    data/essay.txt                 -- candidate ordering

Outputs:
    dist/lua/boshiamy_homophones.lua
    dist/homophones-report.txt

Primary reading of a polyphonic reference character:

    terra's single-character percentages are usually enough (行 xing2 90%,
    長 chang2 90%, 重 zhong4 90%).  A few characters are wrong (台 has a rare
    yi2 entry at 39% but the common reading is tai2), so the score also uses
    terra's phrase rows weighted by essay.txt:

        score = 0.7 * normalized_single_percentage
              + 0.3 * normalized_phrase_usage

    If terra gives no percentage at all, keep terra's first listed reading
    (規 -> gui1, 龜 -> gui1).

Only characters present in the Boshiamy table are included in a homophone
group.  This keeps the list useful (every candidate has a code) and avoids
hundreds of rare CJK extension characters in the menu.
"""

from __future__ import annotations

import argparse
import collections
import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import lime2rime  # noqa: E402
import make_zhuyin  # noqa: E402

# Weight of terra's single-character percentage vs essay-weighted phrase usage.
SINGLE_WEIGHT = 0.7
PHRASE_WEIGHT = 0.3


def lua_quote(s: str) -> str:
    return ('"' + s.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\r", "\\r")
            .replace("\t", "\\t") + '"')


def build_stats_with_freq(terra_rows, freq):
    """Return (single, phrase, first_seen) for primary-reading selection.

    single[char][zhuyin_code] = terra percentage (max)
    phrase[char][zhuyin_code] = sum of essay weights of terra phrases
    first_seen[(char, code)]  = terra row index (deterministic tie-break)
    """
    single = collections.defaultdict(dict)
    phrase = collections.defaultdict(collections.Counter)
    first_seen = {}

    for index, (text, pinyin, weight) in enumerate(terra_rows):
        syllables = pinyin.split()
        if len(text) != len(syllables):
            continue
        if len(text) == 1:
            converted = make_zhuyin.convert_reading(pinyin)
            if converted is None:
                continue
            code = converted[0]
            first_seen.setdefault((text, code), index)
            if weight > single[text].get(code, 0.0):
                single[text][code] = weight
        else:
            w = freq.get(text, 1)
            for ch, syllable in zip(text, syllables):
                converted = make_zhuyin.convert_reading(syllable)
                if converted is not None:
                    phrase[ch][converted[0]] += w

    return single, phrase, first_seen


def primary_reading(ch, readings, single, phrase, first_seen):
    """Pick the most common reading code for one character."""
    entries = readings.get(ch)
    if not entries:
        return None

    codes = []
    for _weight, code, _pinyin in entries:
        if code not in codes:
            codes.append(code)
    if not codes:
        return None

    s = single.get(ch, {})
    single_total = sum(s.values())
    if single_total <= 0:
        # No percentages at all: trust terra's first listed reading.  This
        # avoids phrase-only rare readings (e.g. 嘸 should stay fu3, not mu2).
        return min(codes, key=lambda c: (first_seen.get((ch, c), 1 << 60), c))

    p = phrase.get(ch, collections.Counter())
    phrase_total = sum(p.values())

    best_score = None
    best_code = codes[0]
    for code in codes:
        a = s.get(code, 0.0) / single_total
        b = (p.get(code, 0.0) / phrase_total) if phrase_total else 0.0
        score = SINGLE_WEIGHT * a + PHRASE_WEIGHT * b
        key = (score, s.get(code, 0.0), p.get(code, 0.0),
               -first_seen.get((ch, code), 1 << 60))
        if best_score is None or key > best_score:
            best_score = key
            best_code = code
    return best_code


def bopomofo_for(ch, reading, readings):
    for _weight, code, pinyin in readings.get(ch, []):
        if code == reading:
            converted = make_zhuyin.convert_reading(pinyin)
            if converted is not None:
                return converted[1]
    return ""


def build(entries, terra_rows, freq):
    """Build (codes, groups, stats) from a Boshiamy table and terra rows.

    codes[code] = {"ref": 字, "reading": zhuyin_code, "bopomofo": 注音}
    groups[reading] = [字, ...] sorted by frequency (reference included)
    """
    readings = make_zhuyin.build_readings(terra_rows)
    single, phrase, first_seen = build_stats_with_freq(terra_rows, freq)

    by_code = collections.OrderedDict()
    first_order = {}
    table_chars = set()
    seen_pairs = set()
    skipped = 0

    for index, (code, text, _lineno) in enumerate(entries):
        if not lime2rime.BOSHIAMY_CODE_RE.match(code) or len(text) != 1:
            skipped += 1
            continue
        if (code, text) in seen_pairs:
            continue
        seen_pairs.add((code, text))
        table_chars.add(text)
        first_order.setdefault(text, index)
        by_code.setdefault(code, []).append(text)

    # reading code -> character -> best terra weight (tie-break only)
    groups = collections.defaultdict(dict)
    for ch in table_chars:
        for weight, code, _pinyin in readings.get(ch, []):
            old = groups[code].get(ch)
            if old is None or weight > old:
                groups[code][ch] = weight

    codes = {}
    for code, refs in by_code.items():
        ref = None
        for ch in refs:
            if ch in readings:
                ref = ch
                break
        if ref is None:
            continue

        reading = primary_reading(ref, readings, single, phrase, first_seen)
        if reading is None or reading not in groups:
            continue

        codes[code] = {
            "ref": ref,
            "reading": reading,
            "bopomofo": bopomofo_for(ref, reading, readings),
        }

    used_readings = {entry["reading"] for entry in codes.values()}
    ordered_groups = {}
    for reading in sorted(used_readings):
        chars = sorted(
            groups[reading],
            key=lambda ch: (-freq.get(ch, 0), -groups[reading][ch],
                            first_order.get(ch, 1 << 60), ch),
        )
        ordered_groups[reading] = chars

    stats = {
        "table_chars": len(table_chars),
        "chars_with_reading": sum(1 for ch in table_chars if ch in readings),
        "codes": len(codes),
        "readings": len(ordered_groups),
        "skipped": skipped,
        "group_entries": sum(len(v) for v in ordered_groups.values()),
        "max_group": max((len(v) for v in ordered_groups.values()), default=0),
    }
    return codes, ordered_groups, stats


def write_lua(codes, groups, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    out = io.StringIO()
    out.write("-- Generated by tools/make_homophones.py.  Do not edit.\n")
    out.write("-- codes:  boshiamy code -> \"ref<TAB>zhuyin code<TAB>bopomofo\"\n")
    out.write("-- groups: zhuyin code -> \"char<TAB>char...\" (essay frequency)\n")
    out.write("return {\n")
    out.write("  codes = {\n")
    for code in sorted(codes):
        entry = codes[code]
        value = f"{entry['ref']}\t{entry['reading']}\t{entry['bopomofo']}"
        out.write(f"    [{lua_quote(code)}] = {lua_quote(value)},\n")
    out.write("  },\n")
    out.write("  groups = {\n")
    for reading in sorted(groups):
        value = "\t".join(groups[reading])
        out.write(f"    [{lua_quote(reading)}] = {lua_quote(value)},\n")
    out.write("  },\n")
    out.write("}\n")
    output.write_text(out.getvalue(), encoding="utf-8")


def write_report(codes, groups, stats, source: Path, fmt: str, report: Path) -> None:
    out = io.StringIO()
    w = lambda *a: print(*a, file=out)
    w("# Boshiamy homophones report")
    w(f"source: {source} ({fmt})")
    w(f"table characters: {stats['table_chars']}  "
      f"with readings: {stats['chars_with_reading']}")
    w(f"codes: {stats['codes']}  readings: {stats['readings']}  "
      f"entries: {stats['group_entries']}  max group: {stats['max_group']}  "
      f"skipped rows: {stats['skipped']}")
    w("samples:")
    for code in ("neo", "qnmr", "doo", "uoo", "ovff", "a"):
        entry = codes.get(code)
        if not entry:
            w(f"  {code}: (none)")
            continue
        chars = groups.get(entry["reading"], [])
        w(f"  {code}: {entry['ref']} ({entry['reading']} "
          f"{entry['bopomofo']}) -> " + " ".join(chars[:20]))
    w("polyphonic checks:")
    for code in ("uoo", "c;6", "t;6", "5j/4", "2k7", "xk7"):
        entry = codes.get(code)
        if entry:
            w(f"  {code}: {entry['ref']} -> {entry['reading']} "
              f"{entry['bopomofo']}")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(out.getvalue(), encoding="utf-8")


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=None,
                        help="liu7.cin or boshiamy.lime")
    parser.add_argument("--terra", type=Path,
                        default=root / "data" / "terra_pinyin.dict.yaml")
    parser.add_argument("--essay", type=Path,
                        default=root / "data" / "essay.txt")
    parser.add_argument("--output", type=Path,
                        default=root / "dist" / "lua" / "boshiamy_homophones.lua")
    parser.add_argument("--report", type=Path,
                        default=root / "dist" / "homophones-report.txt")
    args = parser.parse_args()

    source = args.input
    if source is None:
        for candidate in (root / "data" / "liu7.cin",
                          root / "data" / "boshiamy.lime"):
            if candidate.exists():
                source = candidate
                break
    if source is None:
        raise SystemExit("no source table found (data/liu7.cin or data/boshiamy.lime)")
    if not args.terra.exists():
        raise SystemExit(f"terra_pinyin not found: {args.terra}")
    if not args.essay.exists():
        raise SystemExit(f"essay.txt not found: {args.essay}")

    entries, fmt = lime2rime.read_source(source)
    terra_rows = make_zhuyin.read_terra(args.terra)
    freq = make_zhuyin.read_essay(args.essay)

    codes, groups, stats = build(entries, terra_rows, freq)
    write_lua(codes, groups, args.output)
    write_report(codes, groups, stats, source, fmt, args.report)

    neo = codes.get("neo")
    sample = ""
    if neo:
        sample = "  sample: 'neo -> " + " ".join(
            groups[neo["reading"]][:8])
    print(f"source: {source.name} ({fmt})  codes: {stats['codes']}  "
          f"readings: {stats['readings']}  entries: {stats['group_entries']}  "
          f"output: {args.output}")
    if sample:
        print(sample)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
