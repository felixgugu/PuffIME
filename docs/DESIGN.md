# 設計說明

## 目標

在同一個輸入流程裡使用：

1. 嘸蝦米（主要）
2. 英文（自動候選，不切模式）
3. 注音（第一碼 `` ` `` 進入，不設全域模式）

## 為什麼注音要用 `` ` `` 觸發

嘸蝦米和注音共用 `a-z`、`, .`，若完全自動合流，`su`（嘸蝦米碼）和 `su`（ㄋㄧ）無法區分。第一碼 `` ` `` 明確指定該段是注音，就沒有撞碼問題；注音用空白輸入一聲，按 Enter 上屏。

第一碼限制由 `recognizer` pattern 保證：

```yaml
recognizer:
  patterns:
    zhuyin: '^`[0-9a-z,.;/-]*$'
```

只有在 input 以 `` ` `` 開頭時才會 match；後面的字元才能進入緩衝。

## Rime 元件

```
abc segment
  ├─ table_translator                 # puffime.dict.yaml（只做精確碼）
  ├─ lua_translator@boshiamy_completion  # 前綴候選，依 essay 字頻排序
  └─ lua_translator@english_raw       # 原文候選，quality = -1000000，comment = 英

zhuyin segment（前綴 `）
  ├─ recognizer pattern
  ├─ matcher
  ├─ affix_segmentor@zhuyin
  └─ table_translator@zhuyin       # puffzhuyin.dict.yaml（有聲調 + 無聲調單字碼）
```

### 數字路由

- `speller/alphabet` 只有 `a-z , . [ ] '`，**不含數字**。
- 嘸蝦米段：`1`–`0` 不被 speller 吃掉，落到 `selector` → 選候選。
- 注音段：`recognizer` 在 speller 之前接受 `0-9 ; / -`，所以是輸入。
- 注音段要選候選時，用 `key_binder` 把 `Shift+數字` 轉成 `KP_n`，再由 `selector` 選字。

### Enter

嘸蝦米／英文段使用 `express_editor`；它把 `Return` 綁到 `commit_raw_input`，所以 Enter 把目前字母原樣上屏（英文）。

注音段則由 `zhuyin_digits.lua` 在 `express_editor` 之前攔截 `Return`（`0xFF0D`）與數字鍵盤
`KP_Enter`（`0xFF8D`）：

- 有候選且不是殘碼佔位 → `ctx:select(seg.selected_index)` + `ctx:commit()` 上屏
  highlight 的候選。走 context 是為了讓 `forgotten.lua` 的 `commit_notifier`
  讀到 `get_commit_text()`。
- 沒有候選或只有殘碼佔位 → 吞掉 Return，**不會**把 `` `w8 ``、`` `ji2 `` 之類的原文上屏；
  留在緩衝讓使用者 Backspace。

注音段的空白不是 commit 鍵：空白是一聲，由 `zhuyin_digits.lua` 吃掉（或 replay
隱藏的 `=`），不會傳到 `express_editor`。這個攔截只在注音段生效（input 以 `` ` `` 開頭），
所以 `the` + Enter 仍然是 `the`。

### 英文候選

`english_raw.lua`：

```lua
local cand = Candidate("raw", seg.start, seg._end, input, "英")
cand.quality = -1000000
yield(cand)
```

- 只對 `^[a-z][a-z']*$` 的輸入產生候選。
- quality 很低，所以永遠排在嘸蝦米候選後面。
- 沒有中文候選時（`was`、`hello`、`hell`），它就是第一個；空白不會直接上屏（見下節），要按 Enter。
- `rime.lua` 把模組指定給全域 `english_raw`，因為 librime-lua 的
  `lua_translator@english_raw` 是用 `lua_getglobal("english_raw")` 解析。

### 前綴候選（常用字優先）

Rime 內建的 `translator/enable_completion: true` 會用 predictive 查表，但它的
排序是「精確碼 → 剩餘碼短 → 字碼表順序」，不是字頻。例如打 `i` 時，所有
2 碼字（應、応、讀、鞏、誤、工…）一定排在 3 碼字（這、電、請、記）前面。

因此本方案改成：

```yaml
translator:
  dictionary: puffime
  enable_completion: false       # 主表只給精確碼

boshiamy_completion:
  tag: abc
```

並新增 `lua_translator@boshiamy_completion`。build 時
`tools/make_hints.py` 讀字碼表與 `data/essay.txt`，產生：

```text
dist/lua/boshiamy_completion_data.lua
```

格式是 `prefix -> "字<TAB>最短符合碼\n..."`，每個 prefix 的字依 essay 字頻
由高到低排序。精確碼的字會排除，交給主 table translator，所以：

- 精確碼候選：維持字碼表順序（例如 `ak` → 駐、鐵）。
- 補全候選：依字頻排序（例如 `i` → 我、說、這、讓、話、請…）。
- 候選註記是「以目前輸入碼開頭」的最短碼，例如 `a` 下的「或」是 `aqoe`
  （它的全域最短碼 `he` 不符合目前前綴）。

quality 的安排：

| 來源 | quality | 順序 |
|---|---|---|
| 主 table translator（精確碼） | `exp(weight)` = inf | 最前 |
| `boshiamy_completion` | `0` | 中間 |
| `english_raw` | `-1000000` | 最後 |

- `boshiamy_completion_data.lua` 約 0.7MB；librime-lua 只按需求 yield，
  不會一次把整個 prefix 的清單塞進候選窗。
- 只有嘸蝦米段有前綴候選；注音段仍是精確碼查表。
- 副作用：任何「某個碼的前綴」都會有中文候選，所以空白鍵會上屏第一個候選。
  `was`、`hello` 不是任何碼的前綴，才維持「空白不送出」。
- 這是靜態字頻，不會學習個人選字；LIME 式學習需要另外的使用者詞庫或紀錄。

### 無效拆碼的空白與連續英文

`english_raw.lua` 會為每個純字母輸入加一個 `(英)` 候選，所以無效拆碼也一定會有 menu。
`boshiamy_space.lua` 是 `lua_processor`，在 `speller` / `selector` / `express_editor`
之前攔截 Space 與數字：

- 有真正中文候選（第一個候選 `type ~= "raw"`）→ 空白回 kNoop，讓
  `express_editor` 照舊上屏 highlight 的候選；數字回 kNoop，交給 `selector` 選字。
- 只剩英文（input 符合 `^[a-z][a-z0-9' ]*$`，且第一個候選是 `raw`）→
  - 空白：`ctx:push_input(" ")`
  - 數字 `0`–`9`：`ctx:push_input(string.char(keycode))`
  preedit 會顯示 `hello world 42`，可以一直打下去，最後按 Enter 由
  `commit_raw_input` 上屏整句。
- 其他無效碼（含 `, . [ ]` 等字元）→ 空白 kAccepted，留在緩衝讓使用者
  Backspace 修正，不會把錯碼上屏。

為了讓空白留在 commit 的文字裡，`speller` 加了：

```yaml
speller:
  delimiter: " "    # abc_segmentor 會把空白視為片段內的分隔符
  use_space: false  # 空白仍不是一般字碼，只由 boshiamy_space 主動 push
```

如果沒有 `delimiter`，abc 片段會在空白處斷開，`Composition::GetCommitText()`
會漏掉片段之間的空白。`english_raw.lua` 的 pattern 也放寬成
`^[a-z][a-z' ]*$`，讓含空白的原文仍有 `(英)` 候選。

數字不在 `speller/alphabet`，所以 push 之後 `abc_segmentor` 會在數字處切開，
尾巴由 `fallback_segmentor` 變成 `raw` 片段；`Composition::GetPreedit()` 與
`GetCommitText()` 都會把它接回去。副作用是打了數字後候選窗會收起（`raw`
尾巴沒有候選），preedit 仍完整顯示。

行為對照：

| 輸入 | 結果 |
|---|---|
| `the` + 空白 | 棫（有效中文碼優先，不變） |
| `out` + 空白 | 嚅（有補全候選，不變） |
| `hello` + 空白 | 緩衝變 `hello `，不上屏 |
| `hello world` + Enter | 上屏 `hello world` |
| `zzzz` + 空白 | 緩衝變 `zzzz `，Enter 才上屏 |
| `hello123` + Enter | 上屏 `hello123` |
| `the` + `1` | 棫（有效中文碼，數字仍是選字） |
| `,` + 空白 | `,`（符號，不變） |

補全候選的 `type` 是 `completion`（不是 `raw`），所以 `out` 這類「碼的前綴」
也會被視為有中文候選。

### 符號形狀

`symbol_shape.lua` 是 `lua_processor`，攔截 Shift+Space，使用 Rime 內建的
`ascii_punct` / `full_shape` 表示三態：

| 狀態 | `ascii_punct` | `full_shape` |
|---|---|---|
| 半形 | 1 | 0 |
| 自然符號 | 0 | 0 |
| 全形 | 0 | 1 |

- `symbol_shape_filter.lua` 是 `lua_filter`，只處理 `abc` 段的已知符號候選：
  - 半形：中文標點與 ASCII 符號都轉半形；`[` / `]` 例外保留 `「` / `」`。
  - 自然符號：中文標點／中文括號保持全形，ASCII 符號轉半形。
  - 全形：不轉。
  - 多字詞、英文 raw、`/X` 選單不處理；filter 放在 `uniquifier` 前，轉完後去重。
- `punctuator/half_shape` 自訂成自然符號的映射；半形用 `ascii_punct=1`
  （Rime 的 punctuator 直接讓按鍵通過）；全形用 `full_shape=1` 的預設表。
- 半形模式下 `/` 不會經過 punctuator，`symbol_shape.lua` 會把 `/` push 進 input，
  讓 `recognizer` 仍能啟動 `/X` 符號選單。
- 這兩個 option 在 `default.yaml` 的 `switcher/save_options` 內，所以會記住上次選擇。
- 切換無聲；沒有狀態列提示。

### 中途的 `` ` ``

`grave_guard.lua` 是 `lua_processor`：composing 時收到 `` ` `` 就處理：

- 如果 input 只有一個 `` ` ``（也就是剛按下 Zhuyin 前綴），這是連按兩次 backtick：
  `commit_text("``")` + `ctx:clear()`，直接上屏兩個 backtick。
- 其他情況回傳 `kAccepted`（1）把它吃掉，避免 `express_editor` 的
  `DirectCommit` 意外把目前輸入上屏。
- 非 composing 時回傳 `kNoop`（2），讓 `recognizer` 處理第一碼。

### 注音段的聲調、數字與空白

`zhuyin_digits.lua` 是 `lua_processor`，處理注音段的聲調、空白、Enter 與數字：

- **空白 = 一聲**。完整音節尚未帶聲調時，空白會 replay 一個隱藏的 `=` 鍵，
  把字典裡帶 `=` 的一聲別名送進 input（`ru` → `ru=`），preedit 顯示 `ˉ`，
  候選只留一聲。已帶 3/4/6/7/`=` 時空白不動作。
- **空白永遠不上屏**；即使有候選也一樣，只有 `Enter` 上屏。
- **Enter**：有候選且不是殘碼佔位時，用 `ctx:select(seg.selected_index)` +
  `ctx:commit()` 上屏 highlight 的候選。走 context 是為了讓
  `forgotten.lua` 的 `commit_notifier` 讀到 `get_commit_text()`；殘碼／無候選時
  吞掉，不會上屏 `` `w8 `` 原文。
- input **已帶聲調**（結尾是 3/4/6/7/`=`）→ 平數字**只選取**第 n 個候選
  （highlight），不送出。
- `Shift+數字`（有候選時）→ 同樣只選取，不送出。
- input **尚未帶聲調** → 平數字是注音輸入（1=ㄅ、2=ㄉ、5=ㄓ、8=ㄚ、9=ㄞ、0=ㄢ）。
- 殘碼／只有補全候選時按空白 → 吃掉，不會加聲調，也不會送出。

實作上有一個坑：Weasel 0.17.4 內建的 librime-lua **沒有 `ctx:highlight()`**，
`ctx:select()` 只會把 segment 標成 selected，還要 `ctx:commit()` 才會上屏；
直接改 `Segment.selected_index` 也只改到副本。因此 `zhuyin_digits.lua` 用
`env.engine:process_key(KeyEvent("Tab"))` / `Shift+Tab` 來移動 highlight，
並在 schema 加上：

```yaml
selector:
  bindings:
    Tab: next_candidate
    Shift+Tab: previous_candidate
    ISO_Left_Tab: previous_candidate
```

這樣 Tab/Shift+Tab 只改 `selected_index`、不 confirm；按 `Enter` 才 confirm。

**Release 事件**：Weasel 會把按鍵的 release 也送進 engine。Lua processor 一定要
先檢查 `key:release()` 並回傳 `kNoop`；否則聲調鍵（例如 `3`）的 release 會被
當成第二次按下，input 已經以 `3` 結尾，於是 `zhuyin_digits` 把它當成「選第 3 個
候選」，光標就跳到第 3 個。`zhuyin_digits.lua` 與 `grave_guard.lua` 都有這個 guard。

因為數字同時是注音鍵，無法同時支援「所有情況都用數字選字」；目前規則是
「有聲調（含一聲 `=`）才用平數字選」。若已打了一個有聲調的音節，要接一個數字
開頭的新音節（例如 ㄉ），先按 `Enter` 上屏目前候選，再打數字。

### 殘碼與前綴候選

注音字典只收完整音節。像 `1`（ㄅ）、`q`（ㄆ）這種單獨的聲母不是合法音節，
字典裡沒有條目；Rime 的 `table_translator` 查不到碼時會讓片段進入 kVoid，
`preedit_format` 不生效，preedit 就顯示原始按鍵 `1`，而不是 `ㄅ`。修正方式
不是把字典灌滿殘碼，而是：

- `zhuyin/enable_completion: true`：未完成的碼至少能對到「以它開頭」的完整碼，
  片段不會消失。
- `lua_translator@zhuyin_completion`：`tools/make_zhuyin.py` 從字典產生
  `dist/lua/zhuyin_completion_data.lua`（前綴 → 字，依 essay 字頻排序）。
  - `1` → 不、吧、把、被、比…（所有 ㄅ 開頭的字）
  - `5` → 先列精確的 ㄓ 字（之、只、至…），再列 ㄓㄨ／ㄓㄜ…（中、這…）
  - 有精確碼的字會從補全清單排除，所以精確候選一定排最前面。
  - 目前 54 個前綴、約 5.6 萬筆；只有 1–2 鍵的前綴會有補全清單。像 `18`
    （ㄅㄚ）這種完整音節沒有延伸碼，清單是空的，所以不會冒出 ㄅㄢ 的字。
- `lua_filter@zhuyin_partial`：丟掉 Rime 內建的 completion 候選（它的排序是
  剩餘碼長，不是字頻），保留精確候選與 `zhuyin_completion`。若兩者都沒有
  （例如 `su3c`、`ji2`），才輸出一個 `zhuyin_partial` 佔位候選，並把它的
  `preedit` 設成注音字串（`1` → `ㄅ`、`su3c` → `ㄋㄧˇㄏ`）。
- `zhuyin_digits.lua`：佔位候選是唯一候選時，空白與 Enter 都會被吞掉，
  未完成的音節不會被上屏；平數字仍可繼續輸入（`1` → `u` → `6` = ㄅㄧˊ）。
  有真正候選時，Enter 上屏 highlight 的候選；空白是一聲（見「注音段的聲調、
  數字與空白」），不會上屏。

因此 `` ` `` + `1` 會顯示 `ㄅ` 並列出 ㄅ 開頭的常用字，按 Enter 上屏「不」；
`` ` `` + `su3c` 會顯示 `ㄋㄧˇㄏ`，空白與 Enter 都不會送出。

### 注音字典

Rime 的 `SchemaUpdate` 只會編譯每個 schema 的 **primary**
`translator/dictionary`。`table_translator@zhuyin` 的字典不會自動編譯，因此需要
`puffzhuyin.schema.yaml` 這個依賴方案，並在主 schema 加上：

```yaml
schema:
  dependencies:
    - puffzhuyin
```

依賴方案不列入 `default.custom.yaml` 的 `schema_list`，所以不會出現在方案選單。

### 無聲調查詢

`make_zhuyin.py` 除了原本帶聲調的碼，還會為每個單字產生「去掉聲調鍵」的
無聲調碼，合併進同一份 `puffzhuyin.dict.yaml`：

```
你  su3    （帶聲調）
你  su     （無聲調）
呢  su
擬  su3
擬  su
```

- 打 `su` → 兩種碼都匹配，候選是所有聲調的單字，依 essay 字頻排序。
- 打 `su3` → 只有 `su3` 條目匹配，縮小到三聲。
- 只做單音節；多音節詞仍用原本的帶聲調碼（例如 `su3cl3` = 你好）。
- 一聲另有帶 `=` 的別名（例如 `稽` 同時有 `ru` 與 `ru=`）；`ru=` 只列 ㄐㄧ
  一聲的字，空白鍵就是送這個別名。正常碼完全保留，所以舊打法不會壞。

**為什麼不開第二個 translator**：若用 `table_translator@zhuyin_toneless`
搭配 `initial_quality`，Rime 會先把 exact 字典的候選排完，才排無聲調字典，
造成 `ji` 先出現一排一聲的「窩、渦…」，最常用的「我」反而在後面。把兩種碼
放進同一份字典，`table_translator` 就會用同一個字頻排序，行為才像標準注音 IME。

## 簡碼提示與忘記清單

### 資料

`tools/make_hints.py` 從同一個 CIN/LIME 表建立：

```
字 → { short = 最短碼, full = 最長碼 }
```

輸出 `dist/lua/boshiamy_hints.lua`（build 時產生）。表沒有官方「簡碼」標記，
所以先用最短／最長推；如果之後有官方簡碼表，換掉這一步即可。

同一個腳本也用 `data/essay.txt` 產生
`dist/lua/boshiamy_completion_data.lua`（前綴 → 字頻排序的候選與符合碼）。

### 候選註記

`boshiamy_hint.lua` 是 `lua_filter`：

- 嘸蝦米段：`<short>`（只有當打進去的碼不是最短碼時才顯示；不帶 `簡:` 標籤）
- 前綴補全候選：`boshiamy_completion.lua` 已把 comment 設成「以目前輸入碼
  開頭」的最短碼（例如 `a` 下的「或」是 `aqoe`），`boshiamy_hint.lua` 不再覆蓋。
- 注音段：**不顯示** `簡/拆`。Weasel 會用最長的 comment 決定整排候選窗寬度，
  把拆碼放在注音候選旁會讓候選窗變得很大；上屏後改用 `,,fl` / `,,fk` 查。
- `,,fk` / `,,fl` 清單自己已有註記，filter 會跳過
- 英文 raw 候選（型別 `raw`）不註記，保留原本的 `英`

filter 也會把目前輸入來源記到 `_G.PUFF_SOURCE`：

- `zhuyin` / `boshiamy` / `nil`（忘記清單）

### 自動記憶

`forgotten.lua` 的 `init` 連接 `context.commit_notifier`。commit notifier 會在
`Context::Clear()` **之前**觸發，所以 `ctx:get_commit_text()` 還讀得到上屏文字。

只有 `PUFF_SOURCE == "zhuyin"` 時才記錄，逐字寫入：

```
%APPDATA%\Rime\puffime_forgotten.tsv
char <TAB> short <TAB> full <TAB> count <TAB> last-epoch
```

同時把這次上屏的字存進 `M.last_commit`，供 `,,fl` 使用；若引擎重啟後
`M.last_commit` 是空的，就退回讀 TSV 中 `last` 最大的那組。

測試時可用 `PUFF_HARNESS_USER_DIR` 指到暫存目錄（`rime_harness` 本身仍用
`PUFF_RIME_USER_DIR` 指定 Rime user dir）。`forgotten.lua` 只認
`PUFF_HARNESS_USER_DIR`；真實 IME 一律用 `%APPDATA%\Rime`，所以即使部署腳本
洩漏 `PUFF_RIME_USER_DIR` 也不會影響 `,,fk`。測試腳本在啟動真正的 WeaselServer
前仍會清掉這兩個變數；override 目錄無法寫入時也會退回 `%APPDATA%\Rime`。

### `,,fk` 與 `,,fl`

Rime 的 `affix_segmentor` 在「只有前綴、沒有後面的碼」時不會建立 code segment，
translator 不會被呼叫。因此用：

```yaml
forgotten:
  tag: forgotten
  prefix: ",,f"
  tips: "〔忘記清單〕"
```

使用者打 `,,fk` → 前綴 `,,f` + code `k`（非空）→ affix segmentor 建立
`forgotten` 段；`recognizer` pattern `^,,f.*$` 讓輸入被接受。

`forgotten.lua` 同時是 `lua_translator@forgotten`；它的 `func` 讀 TSV：

- `input == "k"`（`,,fk`）：全部歷史，依 `last` 新→舊排序（同時間再比次數），
  comment 是 `簡/拆` 與次數。
- `input == "l"`（`,,fl`）：只取 `M.last_commit`（或 TSV 最新時間那組），
  comment 只有 `簡/拆`，不顯示次數。

兩者選了都會上屏該字；查詢時按 `Esc` 關閉即可。

**Tag 檢查**：`LuaTranslator` 不會替我們過濾 segment tag；Lua 的 `func` 必須
自己檢查 `seg:has_tag(...)`。`english_raw.lua` 檢查 `abc`，`forgotten.lua` 檢查
`forgotten`，否則它們會對每個 segment 都產生候選。

### `v` 選第二候選

`make_hints.py` 另外產生 `dist/lua/boshiamy_prefixes.lua`（所有碼的前綴集合，
24,850 筆）。`boshiamy_v.lua` 是 `lua_processor`，在 `speller` 前攔截 `v`：

- 必須是 `abc` segment、有候選、至少 2 個、且不是 key release。
- 若 `ctx.input .. "v"` 在 prefixes 裡 → 回傳 kNoop，`v` 當正常字碼輸入。
- 否則選目前頁的第 2 個候選：`ctx:select(page_start + 1)` +
  `ctx:confirm_current_selection()`，直接上屏。

用前綴而不是只看完整碼，是為了避免 `xxxv` 剛好是某個更長碼的前綴時被攔截。
例：`ak` → 駐、鐵，`akv` 不是前綴 → `v` 選鐵；`av` 本身是碼（族）→ `v` 輸入。

注意：第 2 個候選可能是英文 raw（例如 `the` 的第 2 個是 `the(英)`），這時 `v`
會上屏英文。只有 1 個候選時不攔截。

### 候選順序固定

Rime 的 `table_translator` 若 `enable_user_dict: true`，會依 commit 次數把選過的
候選提前；這就是「候選順序自己改變、和標準不一樣」的原因。我們把 Boshiamy 與
Zhuyin 的 `enable_user_dict` 都設為 `false`，並刪除舊的
`puffime.userdb` / `puffzhuyin.userdb`，所以候選順序固定：

- 精確碼：字碼表順序。
- 嘸蝦米前綴補全：`essay.txt` 字頻順序（`boshiamy_completion_data.lua`）。
- 注音：essay 字頻順序。

`v` 的快速選字也直接 commit，不寫入使用者詞庫。

### 註記字級與顏色

Weasel 的候選註記（我們的 `簡/拆`、`英`）有獨立的字體與顏色：

```yaml
style:
  font_point: 14
  comment_font_point: 10
  comment_font_face: "Microsoft JhengHei"
  label_font_point: 12
preset_color_schemes:
  puff:
    comment_text_color: 0x888888
    hilited_comment_text_color: 0x666666
```

`comment_font_point` 控制註記大小；`comment_text_color` / `hilited_comment_text_color`
控制灰色深淺。若字體變小後基線不齊，可調 `style/layout/linespacing` 或 `baseline`。

## 配色

`platforms/windows/weasel.custom.yaml` 的 `preset_color_schemes` 定義五款：

| key | 名稱 | 風格 |
|---|---|---|
| `puff` | Puff 淺 | 近白底、淡藍 highlight |
| `puff_dark` | Puff 深 | 深藍灰底、淺色字 |
| `puff_gray` | Puff 灰 | 灰色底、低對比 |
| `puff_macaron` | Puff 馬卡龍 | 粉紅底、薄荷／薰衣草 highlight |
| `puff_mediterranean` | Puff 地中海 | 沙色底、海藍／陶土色 |

Weasel 的顏色值是 **`0xBBGGRR`（BGR）**，不是 RGB。`style/color_scheme` 決定目前使用哪一款。

- 開發機：`tools/theme.ps1 -Name <light|dark|gray|macaron|mediterranean>` 會改
  `platforms/windows/weasel.custom.yaml`、同步 `dist`，再呼叫 `deploy.ps1` 重新部署。
- 已安裝的套件：`theme-package.ps1 -Name <name>` 會改
  `%APPDATA%\Rime\weasel.custom.yaml` 與套件內的 `app\weasel.custom.yaml`
  （後者讓重新安裝仍保留選擇），再用內附的 `rime_deploy.exe` 部署並重啟 WeaselServer。

## 方案圖示

`platforms/windows/icons/puff.ico`（朱紅方印）與 `platforms/windows/icons/puff_ascii.ico`（灰階版）都是含
16／20／24／32／40／48／64／128／256 px 的 ICO。`puffime.schema.yaml`：

```yaml
schema:
  icon: puff.ico
  ascii_icon: puff_ascii.ico
```

- build 會把 `src/*.ico` 複製到 `dist`；deploy 再複製到 `%APPDATA%\Rime`。
- 原圖是 `platforms/windows/icons/puff-source.png`；`tools/make_icon.py` 會產生 `puff.ico`（紅）與
  `puff_ascii.ico`（灰 `#B0B0B0`），需要 Pillow。
- Weasel 的語言列與托盤會從 Rime 使用者資料夾載入這兩個檔名。
- 換圖示後要重新部署；Windows 語言列有快取，必要時重啟 WeaselServer 或 Explorer。
- `style/display_tray_icon` 預設 `false`；設 `true` 會多一個托盤圖示（Windows 11 可能重複）。

## 符號選單

直接用 Weasel 內建的 `symbols.yaml`：

```yaml
engine:
  processors: [..., punctuator, ...]
  segmentors: [..., punct_segmentor, fallback_segmentor]
  translators: [punct_translator, table_translator, ...]

punctuator:
  import_preset: symbols

recognizer:
  patterns:
    punct: '^/([0-9]0?|[A-Za-z]+)$'
```

`/` 不在嘸蝦米 `speller/alphabet`，所以 `/jt` 不會被嘸蝦米吃掉；
`punct_segmentor` 建立 `punct` 段，`punct_translator` 從 `symbols.yaml`
取分類。`, . [ ] '` 仍是嘸蝦米字碼，punctuator 在 speller 後面，不會搶走。

## 平台目錄

- `src/`：Windows/Android 共用的 schema、Lua、`rime.lua`
- `platforms/windows/`：`weasel.custom.yaml` 與方案圖示
- `platforms/android/trime/`：Trime 的 `default.custom.yaml` 與安裝說明
- `tools/build_trime.ps1`：產生 `release/PuffIME-trime.zip`
- `tools/make_trime_files.py`：產生 Android 版 schema/`rime.lua`，移除
  `forgotten` 與 Windows icon 欄位
- Android 版目前不含 `,,fk` / `,,fl`、Weasel 五款配色與圖示

## 部署方式

`WeaselDeployer /deploy` 只做 workspace update，不會可靠地重編譯 schema；
`/install` 也不保證在 build cache 存在時重建。因此 `tools/deploy.ps1`：

1. 停掉 `WeaselServer`
2. 刪掉 `%APPDATA%\Rime\build`
3. 執行 `tools/rime_deploy.exe`（直接呼叫 librime C API 的 `deploy()`）
4. 啟動 `WeaselServer`

`rime_deploy.exe` 沒有 UI，不會出現安裝器的「中」語言設定頁。`deploy.ps1`
會在 exe 不存在時用 `tools/build_deploy.bat` 自動編譯（需要 VS 2022 BuildTools）。

## 資料轉換

### 嘸蝦米表 → puffime.dict.yaml

`tools/lime2rime.py` 自動偵測兩種格式：

- **CIN**（`%gen_inp` / `%chardef`）：預設使用 `data/liu7.cin`。
  - 31,556 筆、22,778 個碼，最長 4 碼。
  - 無 PUA、無簡體/日文變體。
- **LIME**（`code<TAB>text`）：`data/boshiamy.lime`，用 `-Source lime` 啟用。
  - 41,492 筆、27,248 個碼，最長 5 碼。
  - 含簡體/日文變體、5 碼 `v` 符號碼、20 個 PUA。
  - 檔案內有 **4 個 BOM**（第 1、33583、39903、40152 行），全部剝除；否則
    `\ufeffa` 會變成另一個碼，`a` 的繁/簡/日變體會分裂。

共同處理：

- 移除完全重複的 `(code, text)`。
- 表沒有權重，用 `1,000,000 - 全域序號` 產生嚴格遞減權重，保留原檔候選順序。
- 碼字元：`a-z , . [ ] '`；沒有數字。

### terra_pinyin + essay → puffzhuyin.dict.yaml

- `terra_pinyin.dict.yaml` 提供讀音（pinyin + 聲調 + 百分比）。
- `essay.txt` 提供字頻／詞頻，用來排序候選。
- pinyin → bopomofo → 大千鍵碼：
  - 一聲不帶鍵（正常碼）；另外產生帶 `=` 的一聲別名（`ru=`），由空白鍵使用。
    二聲 `6`、三聲 `3`、四聲 `4`、輕聲 `7`。
  - 例：`ni3 → ㄋㄧˇ → su3`、`yi1 → ㄧ → u`、`shi4 → ㄕˋ → g4`、
    `zhong1 → ㄓㄨㄥ → 5j/`、`nv3 → ㄋㄩˇ → sm3`、`er2 → ㄦˊ → -6`。
- 單字：terra 的每個讀音都產生條目，權重 = essay 字頻 + 讀音百分比。
  - `su3` 第一候選是「你」、`g4` 是「是」、`ji3` 是「我」。
- 詞語：
  - terra 自己的多字條目全部保留。
  - essay 中長度 2–5、權重 ≥ 1000 的詞，用每個字的前 3 個讀音產生最多 8 種
    組合，權重 = essay 詞頻。
  - 例：`你好 → su3cl3`、`中國 → 5j/eji6`、`今天 → rupwu0`。
- 目前 254,568 筆（含約 6.2 萬筆一聲別名）；18 筆無法轉換（`yai2`、`eh1`、`wong4` 等罕見音）。

## 已知取捨

- 注音段用精確碼查表，殘碼（例如 `1`）有字頻前綴候選；不支援 abbreviation、
  句子連打；詞語以 essay 常見詞為主。
- 無聲調查詢只支援單音節；`su` 會列所有聲調，但 `sucl`（無聲調「你好」）尚未支援。
- 破音字詞語用前 3 個讀音組合，可能仍有少數詞的讀音沒被涵蓋。
- 繁簡字同時存在，尚未過濾。
- 英文只做原文候選；沒有詞庫補完。
- `, . [ ] '` 是字碼，因此不能用它們翻頁；翻頁改用 PageUp/PageDown。
- Shift 被保留給 `Shift+數字` 選字，因此 ASCII 模式改用 CapsLock。
- 符號選單依賴 Weasel 內建 `symbols.yaml`；自訂分類要改該檔或自帶 preset。
