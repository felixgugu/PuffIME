-- Zhuyin digit / tone / space routing.
--
-- The zhuyin segment follows the standard Dachen tone keys:
--   空白 = 一聲 ˉ, 6 = ˊ, 3 = ˇ, 4 = ˋ, 7 = ˙
--
-- Unlike the English and Boshiamy segments, Space never commits text here.
-- Enter is the only commit key.  The first tone is stored as a hidden `=`
-- marker in the dictionary (`ru` = ㄐㄧ all tones, `ru=` = ㄐㄧ first tone);
-- Space appends that marker so an untoned syllable narrows to first tone.
--
--   * complete untoned syllable + Space -> append `=` (first tone)
--   * input already ends with 3/4/6/7/= + Space -> swallow (no second tone)
--   * incomplete code + Space -> swallow (never commit raw input)
--   * menu open + Enter -> select and commit the highlighted candidate
--   * placeholder / no menu + Enter -> swallow (never commit raw `w8 text)
--   * input ends with a tone + plain digit -> highlight candidate
--   * otherwise plain digit -> zhuyin input (1=ㄅ, 2=ㄉ, 5=ㄓ, 8=ㄚ...)
--   * Shift+digit (menu open) -> highlight candidate
--   * only the zhuyin_partial placeholder + Space/Enter -> swallow
--
-- Candidate selection only highlights; Enter commits.  This applies to both
-- plain digits and Shift+digits in the zhuyin segment.  (Boshiamy digits still
-- use the normal selector, which commits immediately.)

local SHIFT_DIGIT = {
  ["!"] = "1", ["@"] = "2", ["#"] = "3", ["$"] = "4", ["%"] = "5",
  ["^"] = "6", ["&"] = "7", ["*"] = "8", ["("] = "9", [")"] = "0",
}

local function is_zhuyin(ctx)
  if not ctx:is_composing() then
    return false
  end
  local input = ctx.input
  return input ~= "" and input:sub(1, 1) == "`"
end

local function digit_from_key(key)
  local ch = key.keycode
  if ch >= 0x30 and ch <= 0x39 then
    return string.char(ch)
  end
  if ch < 1 or ch > 255 then
    return nil
  end
  return SHIFT_DIGIT[string.char(ch)]
end

-- True for a real dictionary candidate.  Completion candidates and the
-- zhuyin_partial placeholder are not enough to decide that the code is a
-- complete syllable.
local function is_real_candidate(cand)
  return cand ~= nil
     and cand.type ~= "completion"
     and cand.type ~= "zhuyin_completion"
     and cand.type ~= "zhuyin_partial"
end

local function has_exact_candidate(ctx)
  local seg = ctx.composition:back()
  if not seg or not seg.menu then
    return false
  end
  if seg.menu:prepare(1) < 1 then
    return false
  end
  return is_real_candidate(seg:get_candidate_at(0))
end

-- True when the only thing keeping the segment alive is zhuyin_partial.lua's
-- placeholder.  This happens for codes with neither an exact entry nor any
-- longer code starting with them (e.g. `su3c = ㄋㄧˇㄏ).
local function is_partial(ctx)
  local seg = ctx.composition:back()
  if not seg or not seg.menu then
    return false
  end
  if seg.menu:prepare(1) < 1 then
    return false
  end
  local cand = seg:get_candidate_at(0)
  return cand ~= nil and cand.type == "zhuyin_partial"
end

local function select_candidate(ctx, env, digit)
  local seg = ctx.composition:back()
  if not seg or not seg.menu then
    return false
  end
  local n = tonumber(digit)
  if n == 0 then
    n = 10
  end
  local page_size = env.engine.schema.page_size
  if not page_size or page_size <= 0 then
    page_size = 9
  end
  local page_start = math.floor(seg.selected_index / page_size) * page_size
  local target = page_start + n - 1
  local current = seg.selected_index
  local delta = target - current
  if delta == 0 then
    return true
  end
  -- The bundled librime-lua has neither ctx:highlight() nor a functional
  -- Segment.selected_index setter.  Move the highlight with Tab/Shift+Tab;
  -- the selector changes selected_index without confirming the segment.
  local key_name = delta > 0 and "Tab" or "Shift+Tab"
  for _ = 1, math.abs(delta) do
    env.engine:process_key(KeyEvent(key_name))
    local now = ctx.composition:back()
    if not now or now.selected_index == current then
      break
    end
    current = now.selected_index
  end
  return true
end

local function processor(key, env)
  if key:release() then
    return 2  -- kNoop: never treat a key release as a second press
  end
  local ctx = env.engine.context
  local ch = key.keycode

  if not is_zhuyin(ctx) then
    return 2  -- kNoop
  end

  if ch == 0x20 then  -- space
    if key:shift() or key:ctrl() or key:alt() then
      return 2  -- Shift+Space cycles symbol shape; let symbol_shape handle it
    end
    -- Space is the first-tone key, never a commit key.  If the syllable
    -- already carries a tone, a second tone makes no sense: swallow it.
    if ctx.input:match("[3467=]$") then
      return 1
    end
    -- Only a complete syllable can take a tone.  Bare initials and partial
    -- next syllables keep the plain space behaviour: swallow, never commit.
    if ctx:has_menu() then
      -- Replay the hidden first-tone marker through the recognizer so the
      -- table translator sees the `...=` alias code.  This also works in
      -- the middle of a phrase (`rup=wu0` + Space -> `rup=wu0=`).
      env.engine:process_key(KeyEvent("="))
      -- Some multi-syllable codes have no alias for a final first tone
      -- (e.g. `rupwu0` for 今天).  If the marker produced no real candidate,
      -- undo it and leave the normal code intact for Enter.
      if not has_exact_candidate(ctx) then
        env.engine:process_key(KeyEvent("BackSpace"))
      end
    end
    return 1
  end

  if ch == 0xFF0D or ch == 0xFF8D then  -- Return / KP_Enter
    if ctx:has_menu() and not is_partial(ctx) then
      -- express_editor binds Return to commit_raw_input, which would send
      -- the letters (`su3).  Select the highlighted candidate and commit it
      -- through the context so get_commit_text() (used by forgotten.lua)
      -- still sees the candidate text.
      local seg = ctx.composition:back()
      if seg and ctx:select(seg.selected_index) then
        ctx:commit()
      end
    end
    return 1  -- swallow: never commit the raw `w8 text
  end

  local digit = digit_from_key(key)
  if not digit then
    return 2
  end
  if not ctx:has_menu() then
    return 2  -- no candidate yet: let the digit be zhuyin input
  end

  if is_partial(ctx) then
    if key:shift() then
      return 1  -- do not select the incomplete-syllable placeholder
    end
    return 2  -- plain digit continues the syllable
  end

  if not key:shift() then
    local input = ctx.input
    if not input:match("[3467=]$") then
      return 2  -- syllable not toned yet: plain digit is input
    end
  end

  select_candidate(ctx, env, digit)
  return 1  -- kAccepted
end

return processor
