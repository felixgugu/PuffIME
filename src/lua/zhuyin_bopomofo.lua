-- Dachen (大千) key -> Bopomofo, shared by the Zhuyin Lua components.
--
-- zhuyin_partial.lua uses it for the placeholder preedit and
-- zhuyin_completion.lua uses it to keep the preedit Bopomofo while a
-- frequency-ordered completion candidate is the first candidate.

local MAP = {
  ["1"] = "ㄅ", ["q"] = "ㄆ", ["a"] = "ㄇ", ["z"] = "ㄈ",
  ["2"] = "ㄉ", ["w"] = "ㄊ", ["s"] = "ㄋ", ["x"] = "ㄌ",
  ["e"] = "ㄍ", ["d"] = "ㄎ", ["c"] = "ㄏ",
  ["r"] = "ㄐ", ["f"] = "ㄑ", ["v"] = "ㄒ",
  ["5"] = "ㄓ", ["t"] = "ㄔ", ["g"] = "ㄕ", ["b"] = "ㄖ",
  ["y"] = "ㄗ", ["h"] = "ㄘ", ["n"] = "ㄙ",
  ["u"] = "ㄧ", ["j"] = "ㄨ", ["m"] = "ㄩ",
  ["8"] = "ㄚ", ["i"] = "ㄛ", ["k"] = "ㄜ", [","] = "ㄝ",
  ["9"] = "ㄞ", ["o"] = "ㄟ", ["l"] = "ㄠ", ["."] = "ㄡ",
  ["0"] = "ㄢ", ["p"] = "ㄣ", [";"] = "ㄤ", ["/"] = "ㄥ",
  ["-"] = "ㄦ",
  ["6"] = "ˊ", ["3"] = "ˇ", ["4"] = "ˋ", ["7"] = "˙", ["="] = "ˉ",
}

local M = {}

function M.to_bopomofo(code)
  return (code:gsub(".", MAP))
end

return M
