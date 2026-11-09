# 手動驗收清單

在小狼毫實際選字測試（方案：泡芙輸入法）。

> 預設 `tools\build.ps1` 使用 `data/liu7.cin`；若用 `-Source lime`，
> `he` 等短碼的候選數量會不同，其餘測項相同。

## 安裝

- [ ] `tools\install-weasel.ps1` 完成，無錯誤
- [ ] `tools\build.ps1` 完成，`dist\` 有兩個 dict 與 schema
- [ ] `tools\deploy.ps1` 完成，WeaselServer 重啟
- [ ] `Ctrl+`` ` `` 或 `F4` 看得到「泡芙輸入法」

## 嘸蝦米

- [ ] `a` + 空白 → 對
- [ ] `aa` + 空白 → 寸
- [ ] `,` + 空白 → `,`（預設半形）
- [ ] `[` + 空白 → `「`（預設半形，`[`/`]` 例外保留「」）
- [ ] Shift+Space → 自然符號；`,` + 空白 → `，`
- [ ] Shift+Space 兩次 → 全形；`,dol` + 空白 → `＄`
- [ ] Shift+Space 三次回到半形；`,dol` + 空白 → `$`
- [ ] `yneu` + 空白 → 殼
- [ ] `ak` 的候選固定是 駐(1)、鐵(2)
- [ ] 按 `v` 選鐵之後，再打 `ak` 仍然是 駐、鐵（順序不會因選字改變）
- [ ] `ak` + `v` → 鐵（第 2 個直接上屏）
- [ ] `a` + `v` → 輸入 `av`（族），不是選第 2 個
- [ ] `v` + 空白 → 要
- [ ] `feba` + 空白 → 對，候選旁 `a`
- [ ] 候選註記字級比候選字小（10pt）、顏色灰色
- [ ] 在候選列按 `2` 可選第二個候選
- [ ] 候選列用 PageUp/PageDown 可翻頁

## 前綴候選（逐碼縮小、常用字優先）

- [ ] `i` 第一頁候選：後、我、說、這、讓、話、請…
- [ ] `i` + `2` → 我
- [ ] `a` 第一頁候選：對、也、會、點、過…
- [ ] `a` + `2` → 也
- [ ] `aa` 候選變少：寸、丶、錢、鋪、鑫…
- [ ] `aaa` 只剩 鑫、龘、鑆
- [ ] `a` 下的「或」候選旁顯示 `aqoe`（不是全域最短碼 `he`）
- [ ] `a` + PageDown 可看到更多以 `a` 開頭的字
- [ ] `a` 再按 Backspace 回空，候選消失
- [ ] `feba` + 空白 → 對（完整碼的第一候選不變）
- [ ] `ak` 仍是 駐(1)、鐵(2)，補全候選排在後面

## 同音字查詢（`'`）

- [ ] `'neo` 候選第一個是 **同**，後面是 銅、童、桐、彤…
- [ ] `'neo` + 空白 → 同
- [ ] `'neo` + `2` → 銅
- [ ] `'neo` + `3` → 童
- [ ] `'qnmr` 候選第一個是 **規**，後面有 歸、龜…
- [ ] `'qnmr` + `3` → 龜
- [ ] `'doo` 候選第一個是 **加**，後面有 家、嘉、佳…
- [ ] `'uoo` 候選第一個是 **台**，後面是 臺、抬、苔…（不是 一、宜）
- [ ] 同音候選旁有最短拆碼；原字不重複顯示自己的碼
- [ ] 同音候選太多時 PageUp/PageDown 可翻頁
- [ ] Shift+Space 到自然符號；`'` + 空白 → 、（不影響標點）
- [ ] 自然符號：`''` + 空白 → “
- [ ] `a'b` 這種 `'` 不在第一碼的輸入不會觸發同音
- [ ] Android/Trime 也有相同行為

## 英文

- [ ] `the` + 空白 → 棫（有效碼）
- [ ] `the` + Enter → the
- [ ] `the` + `2` → the
- [ ] `was` + 空白 → 不送出，preedit 變成 `was `（空白進緩衝）
- [ ] `was` + Enter → was
- [ ] `hello` + 空白 → 不送出，preedit 變成 `hello `
- [ ] `hello` + Enter → hello
- [ ] `hello world` + Enter → hello world（整句含空白）
- [ ] `hello` + 空白 + `world` + 空白 + `Enter` → `hello world `（尾端空白保留）
- [ ] `was` + `1` → 不送出，preedit 變成 `was1`（不會選字第 1 個上屏）
- [ ] `hello123` + Enter → hello123（數字進緩衝）
- [ ] `test 42` + Enter → test 42
- [ ] `the` + `1` → 棫（有中文候選時數字仍是選字）
- [ ] 打過數字後 preedit 仍完整顯示，候選窗收起；Enter 上屏整串
- [ ] `zzzz` + 空白 → 不送出，preedit 變成 `zzzz `（可 Backspace）
- [ ] `zzzz` + Enter → zzzz
- [ ] `out` + 空白 → 嚅（`out` 是 `outr` 的前綴，補全候選會被空白上屏）
- [ ] `,` + 空白 → `,`（符號不受影響）
- [ ] `he` 的候選列最後有 `he(英)`
- [ ] `CapsLock` 進 ASCII，打英文正常；再按一次回中文

## 注音

- [ ] `` ` `` + `su3` + `Enter` → 你
- [ ] `` ` `` + `su3` + 空白 → 不上屏（空白是聲調鍵）
- [ ] `` ` `` + `su` + `Enter` → 你（列出所有聲調：你、呢、擬、尼…）
- [ ] `` ` `` + `su` + 空白 → 縮小到 ㄋㄧ 一聲，再 `Enter` 上屏
- [ ] `` ` `` + `su3` → 只剩三聲（你、擬、妳…），不再有呢/尼
- [ ] `` ` `` + `ji` + `Enter` → 我（所有聲調，我排第一）
- [ ] `` ` `` + `1` → preedit 顯示 `ㄅ`（不是 `1`），候選列是 ㄅ 開頭常用字（不、吧、把…）
- [ ] `` ` `` + `1` + `Enter` → 不
- [ ] `` ` `` + `1` + 空白 → 不上屏
- [ ] `` ` `` + `1` + `Shift+2` + `Enter` → 吧
- [ ] `` ` `` + `1` 後按 `8` → preedit 變 `ㄅㄚ`（不是選第 8 個）
- [ ] `` ` `` + `5` → 之、只、至… 之後才出現 中、這…
- [ ] `` ` `` + `18` → 只有 ㄅㄚ 的字，不會出現 ㄅㄢ（班、半…）
- [ ] `` ` `` + `1` + `u` + `6` + `Enter` → 鼻
- [ ] `` ` `` + `q` → preedit 顯示 `ㄆ`
- [ ] `` ` `` + `su3` + `c` → preedit 顯示 `ㄋㄧˇㄏ`，空白與 Enter 都不上屏
- [ ] `` ` `` + `u` + 空白 + `Enter` → 一（空白＝一聲）
- [ ] `` ` `` + `wu0` + `Enter` → 天
- [ ] `` ` `` + `su3cl3` + `Enter` → 你好
- [ ] 注音 preedit 顯示 `ㄋㄧˇ`，一聲顯示 `ㄐㄧˉ`
- [ ] `` ` `` + `ji3` + `2` → 只選取第二個（highlight，不送出）
- [ ] 再按 `Enter` → 婑
- [ ] `` ` `` + `ji3` + `2` + `3` + `Enter` → 捰（第三個）
- [ ] `` ` `` + `w8` + `Enter` → 他（不是上屏 `` `w8 ``）
- [ ] `` ` `` + `ji3` + `Enter` → 我
- [ ] `` ` `` + `ji3` + `2` + `Enter` → 婑
- [ ] `` ` `` + `ji2` + `Enter` → 不會送出 `ji2`（留在緩衝）
- [ ] `` ` `` + `ru` + 空白 + `Enter` → 機（ㄐㄧ 一聲第一個）
- [ ] `` ` `` + `ru` + 空白 + PageDown ×2 + `Enter` → 稽
- [ ] `` ` `` + `ru` + 空白 + `t86` + `Enter` → 稽查
- [ ] `the` + Enter → the（嘸蝦米／英文段不受影響）
- [ ] `` ` `` + `su` + `2` → 2 是輸入（ㄉ），不是選字
- [ ] `` ` `` + `su` + `Shift+2` + `Enter` → 呢（所有聲調的第 2 個）
- [ ] `` ` `` + `ji2` + 空白 → 不會送出 `ji2`（留在緩衝，可 Backspace）
- [ ] 注音候選旁**沒有** `簡/拆`（候選窗維持窄）

## 符號選單

- [ ] `/jt` + 空白 → ↑（箭頭）
- [ ] `/sx` + 空白 → ±（數學）
- [ ] `/bq` + 空白 → ☻（表情）
- [ ] `/fh` 有符號/電腦分類候選
- [ ] `,` + 空白 → `,`（預設半形；符號選單不會搶走嘸蝦米字碼）
- [ ] `[` + 空白 → `「`（預設半形，`[`/`]` 例外保留「」）
- [ ] Shift+Space → 自然符號；`,` + 空白 → `，`
- [ ] `/jt` 在自然符號、全形模式下仍能開箭頭選單

## 符號形狀

- [ ] 預設 `c.` + 空白 → `!`
- [ ] Shift+Space → 自然符號；`c.` + 空白 → `！`
- [ ] Shift+Space 兩次 → 全形；`c.` + 空白 → `！`
- [ ] 自然符號：`,dol` + 空白 → `$`
- [ ] 全形：`,dol` + 空白 → `＄`
- [ ] 自然符號：`@` / `#` / `$` 這類直接按鍵是半形
- [ ] 半形：直接按 `!` / `?` 是 ASCII，不經 IME 上屏
- [ ] 半形：`[` / `]` 仍輸出 `「` / `」`
- [ ] `（）「」『』【】` 在自然符號下保持全形
- [ ] Shift+Space 切換不會插入空白，也不會清掉目前輸入

## 簡碼提示與忘記清單

- [ ] `feba` + 空白 → 對，候選旁顯示 `a`
- [ ] `` ` `` + `su3` → 注音候選旁沒有 `簡/拆`
- [ ] 用注音上屏幾個字之後，打 `,,fk` → 出現清單（preedit 顯示 `k`）
- [ ] 清單依最後使用時間新→舊
- [ ] 清單候選旁有 `簡/拆` 與次數
- [ ] 打 `,,fl` → 只出現最新一次上屏的字（preedit 顯示 `l`），候選旁有 `簡/拆`
- [ ] 先上屏「天」，再打 `,,fl` → 第一個候選是天（`簡: edn`）
- [ ] 選一個清單候選 → 上屏該字
- [ ] `%APPDATA%\Rime\puffime_forgotten.tsv` 有記錄

## 邊界

- [ ] `a` 之後按 `` ` `` → 不會進注音，也不會把 `a` 上屏
- [ ] 連按兩次 backtick → 上屏兩個 backtick
- [ ] 單一 backtick + Enter → 上屏一個 backtick
- [ ] 空白在沒有候選時不會送出奇怪東西
- [ ] 切到別的方案再切回來，設定仍正常

## 配色

- [ ] `tools\theme.ps1 -Name dark` → 重新部署後候選窗變深色
- [ ] `tools\theme.ps1 -Name gray` → 灰色主題
- [ ] `tools\theme.ps1 -Name macaron` → 馬卡龍粉彩
- [ ] `tools\theme.ps1 -Name mediterranean` → 地中海沙色／海藍
- [ ] `tools\theme.ps1 -Name light` → 回到淺色
- [ ] 套件內的 `theme-package.ps1 -Name dark` 也能切換
- [ ] 候選字、註記、highlight 在深色主題下仍清楚可讀

## 圖示

- [ ] 語言列／方案圖示是朱紅方印 `puff.ico`
- [ ] ASCII 模式圖示變成灰階 `puff_ascii.ico`
- [ ] 重新部署後圖示仍正常顯示
- [ ] 如果語言列沒更新，重啟 WeaselServer 或 Explorer 後再看

## 疑難排解

- 部署後沒看到方案：確認 `%APPDATA%\Rime\default.custom.yaml` 的 `schema_list`；再跑一次 `tools\deploy.ps1`。
- 英文候選沒出現：看 `%APPDATA%\Rime\rime.lua` 是否有 `english_raw = require("english_raw")`，以及 `%APPDATA%\Rime\lua\english_raw.lua` 是否存在。
- 簡碼提示沒出現：確認 `%APPDATA%\Rime\lua\boshiamy_hints.lua` 存在，且 build 有跑 `tools\make_hints.py`。
- 同音字沒出現：確認 `%APPDATA%\Rime\lua\boshiamy_homophones.lua` 存在，且 `rime.lua` 有 `boshiamy_homophone = require("boshiamy_homophone")`。distribution-safe 安裝需要 `data\terra_pinyin.dict.yaml`，`make_dict.exe` 才會產生同音資料。
- `,,fk` 沒清單：確認 `%APPDATA%\Rime\lua\forgotten.lua` 存在，並先從注音上屏幾個字。
- `,,fk` 空白但 `,,fl` 有紀錄：確認 WeaselServer 用的是新版 `forgotten.lua`（只認 `PUFF_HARNESS_USER_DIR`，真實 IME 固定 `%APPDATA%\Rime`）。從一般 PowerShell 重跑 `tools\deploy.ps1` 或直接重啟 WeaselServer。`run_harness.ps1` / `install-package.ps1` 現在會在啟動 WeaselServer 前清掉測試變數。
- 注音段打不出字：確認 `%APPDATA%\Rime\build\puffzhuyin.table.bin` 存在。
- 看日誌：`%TEMP%\rime.weasel\`。
