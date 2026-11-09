-- Homophone lookup for the `'` prefix.
--
-- Type ' followed by a normal Boshiamy code:
--   'neo   -> 同 (reference, 音:ㄊㄨㄥˊ), 銅, 童, 桐, ...
--   'qnmr  -> 規 (reference), 歸, 龜, ...
--
-- The reference character is the first character of the code in the table.
-- Its pronunciation (the most common reading) determines the group; every
-- character in the Boshiamy table with the same reading is listed, ordered by
-- essay frequency.  boshiamy_homophones.lua is generated at build time by
-- tools/make_homophones.py.
--
-- The leading ' is only meaningful as the first input key.  A lone ' (or '')
-- still goes through the normal table translator for 、 / “ etc., because
-- no homophone entry exists for those punctuation codes.

local ok, data = pcall(require, "boshiamy_homophones")
if not ok or type(data) ~= "table" then
  data = { codes = {}, groups = {} }
end

local codes = data.codes or {}
local groups = data.groups or {}

local function translator(input, seg, env)
  if not seg:has_tag("abc") then
    return
  end
  if input:sub(1, 1) ~= "'" then
    return
  end

  local code = input:sub(2)
  if code == "" then
    return
  end

  local entry = codes[code]
  if not entry then
    return
  end

  local ref, reading, bopomofo = entry:match("^([^\t]+)\t([^\t]+)\t(.*)$")
  if not ref then
    return
  end
  local group = groups[reading]
  if not group then
    return
  end

  local comment = ""
  if bopomofo ~= "" then
    comment = "音 " .. bopomofo
  end
  local cand = Candidate("homophone", seg.start, seg._end, ref, comment)
  cand.quality = 0
  yield(cand)

  for ch in group:gmatch("[^\t]+") do
    if ch ~= ref then
      local c = Candidate("homophone", seg.start, seg._end, ch, "")
      c.quality = 0
      yield(c)
    end
  end
end

return translator
