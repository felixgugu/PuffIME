#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the Boshiamy dictionary and generated Lua data from a user's table.

This is the code-only release's builder: the package never ships the
Boshiamy-derived files.  The user supplies their own liu7.cin or
boshiamy.lime, and install.bat runs this program to create:

    puffime.dict.yaml
    lua/boshiamy_hints.lua
    lua/boshiamy_prefixes.lua
    lua/boshiamy_completion_data.lua
    lua/boshiamy_homophones.lua

Usage:
    python tools/make_dict.py --input data/liu7.cin --out app
    make_dict.exe --input data/liu7.cin --out app
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import lime2rime  # noqa: E402
import make_hints  # noqa: E402
import make_homophones  # noqa: E402
import make_zhuyin  # noqa: E402


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True,
                        help="liu7.cin or boshiamy.lime supplied by the user")
    parser.add_argument("--essay", type=Path, required=True,
                        help="essay.txt used for completion frequency")
    parser.add_argument("--terra", type=Path,
                        default=Path("data") / "terra_pinyin.dict.yaml",
                        help="terra_pinyin.dict.yaml used for homophone lookup")
    parser.add_argument("--out", type=Path, required=True,
                        help="app/output directory")
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"input table not found: {args.input}")
    if not args.essay.exists():
        raise SystemExit(f"essay.txt not found: {args.essay}")

    out: Path = args.out
    lua_dir = out / "lua"
    lua_dir.mkdir(parents=True, exist_ok=True)

    print(f"reading table: {args.input}")
    entries, fmt = lime2rime.read_source(args.input)
    data = lime2rime.build(entries)
    lime2rime.write_dict(data["rows"], out / "puffime.dict.yaml",
                         args.input, fmt)
    print(f"wrote puffime.dict.yaml ({len(data['rows'])} entries)")

    hints, _hfmt, bad = make_hints.build_hints(args.input)
    prefixes, _pfmt, _code_count = make_hints.build_prefixes(args.input)
    entries2, _ = make_hints.read_source(args.input)
    freq = make_hints.read_essay(args.essay)
    completion = make_hints.build_completion(entries2, freq)

    make_hints.write_lua(hints, lua_dir / "boshiamy_hints.lua")
    make_hints.write_prefixes(prefixes, lua_dir / "boshiamy_prefixes.lua")
    make_hints.write_completion_lua(
        completion, lua_dir / "boshiamy_completion_data.lua")

    if args.terra.exists():
        try:
            terra_rows = make_zhuyin.read_terra(args.terra)
            hom_codes, hom_groups, _stats = make_homophones.build(
                entries2, terra_rows, freq)
            make_homophones.write_lua(
                hom_codes, hom_groups, lua_dir / "boshiamy_homophones.lua")
            print(f"wrote homophones.lua ({len(hom_codes)} codes, "
                  f"{len(hom_groups)} readings)")
        except Exception as exc:  # Keep the IME installable even if this fails.
            print(f"warning: homophone table not built: {exc}")
    else:
        print(f"warning: {args.terra} not found; homophone lookup disabled")

    print(f"wrote hints.lua ({len(hints)} chars), prefixes.lua "
          f"({len(prefixes)} prefixes), completion_data.lua "
          f"({len(completion)} prefixes)")
    if bad:
        print(f"warning: skipped {bad} invalid table entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
