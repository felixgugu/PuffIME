-- rime.lua
-- Load PuffIME Lua modules as globals.
--
-- librime-lua resolves `lua_translator@english_raw` with
-- lua_getglobal("english_raw"), so the module must be assigned here.

english_raw = require("english_raw")
boshiamy_completion = require("boshiamy_completion")
boshiamy_homophone = require("boshiamy_homophone")
grave_guard = require("grave_guard")
zhuyin_digits = require("zhuyin_digits")
zhuyin_partial = require("zhuyin_partial")
zhuyin_completion = require("zhuyin_completion")
boshiamy_v = require("boshiamy_v")
boshiamy_space = require("boshiamy_space")
symbol_shape = require("symbol_shape")
symbol_shape_filter = require("symbol_shape_filter")
boshiamy_hint = require("boshiamy_hint")
forgotten = require("forgotten")
