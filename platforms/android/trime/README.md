# 泡芙輸入法 for Trime（Android）

這個資料夾是 Trime 用的 Rime 方案包。Windows 版仍然保留在
`platforms/windows/`，兩邊共用 `src/` 的 schema 與 Lua。

> **Release 不提供預編譯的 Trime zip。** 請先安裝 Trime（同文輸入法），
> 再用 `tools\build_trime.ps1` 搭配你自己的字碼表在本機 build
> `release\PuffIME-trime.zip`。

## 安裝

### 方法 A：用電腦 + USB（最快）

1. 手機先安裝 Trime（同文輸入法）。
2. 手機開啟「開發人員選項 → USB 偵錯」，接上電腦並允許授權。
3. 在 repo 目錄執行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\install_trime_phone.ps1
```

腳本會把方案複製到 Trime 的 Rime 資料夾、啟用 Trime、開啟 App 並按「部署」。
如果有多台裝置，加 `-Serial <序號>`；手機還沒裝 Trime，可加
`-TrimeApk <apk路徑>`；只想複製檔案不部署，加 `-SkipDeploy`。

### 方法 B：不用電腦

1. 安裝 Trime。
2. 把本機 build 出來的 `PuffIME-trime.zip` 解壓到手機的一般資料夾，例如
   `Download/PuffIME`。**檔案要直接放在這個資料夾裡**，不要多一層。
3. 開 Trime：
   - 第一次啟動：在「選擇同文輸入法如何儲存 Rime 資料」按
     **「選擇外部資料夾…」**，選 `Download/PuffIME`。
   - 已經設定過：設定 → 使用者資料夾 → 資料儲存模式 →
     **從外部存儲同步** → 選擇同一個資料夾。
4. 回 Trime 按 **「部署」**。
5. 到 Android 設定 → 系統 → 語言與輸入 → 螢幕鍵盤，啟用並選擇 Trime。

> Trime 3.3.x 的預設使用者資料夾是
> `/storage/emulated/0/Android/data/com.osfans.trime/files/rime`。
> 如果你的檔案管理器可以直接進入 `Android/data`，也可以把 zip 內容
> 直接放到這個資料夾，再按「部署」。

> **從舊的 PuffBoshiamy 升級**：如果之前裝過舊版，使用者資料夾與 `build/`
> 裡會留著 `puffboshiamy.*`。只覆蓋新檔案的話，Trime 可能仍選用舊的
> `puffboshiamy` 方案，注音的修正就不會生效。請刪除這些舊檔（包含
> `puffboshiamy.userdb`），或在電腦上跑 `tools\install_trime_phone.ps1`
> （會自動移除），再按「部署」並在「方案」選擇 **泡芙輸入法**。

> 注意：如果鍵盤看起來還是 Gboard（英文 QWERTY、空白鍵寫 English），
> 要先在 Android 設定 → 系統 → 語言與輸入 → 螢幕鍵盤 啟用 Trime，
> 並用鍵盤切換鍵選 Trime。這不是本方案的問題。

## 轉注音（ㄅㄆㄇ 注音鍵盤）

Trime 鍵盤底部、空白鍵左邊有一顆 **「中文」/「注音」** 鍵：

- **按一下**：切回中文，換成 **ㄅㄆㄇ 注音鍵盤**，並直接進入注音
- **長按**：切換中文／英文

注音鍵盤就是大千鍵位，按鍵上直接顯示注音符號：

```
1 ㄅ   q ㄆ   a ㄇ   z ㄈ
2 ㄉ   w ㄊ   s ㄋ   x ㄌ
3 ˇ    e ㄍ   d ㄎ   c ㄏ
4 ˋ    r ㄐ   f ㄑ   v ㄒ
5 ㄓ   t ㄔ   g ㄕ   b ㄖ
6 ˊ    y ㄗ   h ㄘ   n ㄙ
7 ˙    u ㄧ   j ㄨ   m ㄩ
8 ㄚ    i ㄛ   k ㄜ   , ㄝ
9 ㄞ    o ㄟ   l ㄠ   . ㄡ
0 ㄢ    p ㄣ   ; ㄤ   / ㄥ   - ㄦ
```

例如在注音鍵盤按 `ㄋ`、`ㄧ`、`ˇ`、`Enter` → 你；
按 `ㄅ`、`ㄚ`、`Enter` → 吧；按 `ㄐ`、`ㄧ`、空白（一聲）、`Enter` → 機，
翻頁可選 `稽`。

注音段的空白是一聲，不會上屏；上屏請按 `Enter`。
輸入上屏後（Enter 或點候選）會**自動切回嘸蝦米 QWERTY 鍵盤**，
可以接著打嘸蝦米。若打到一半想取消注音，按注音鍵盤左下角的
**「嘸蝦米」** 鍵即可返回，不會上屏。

> 注音鍵盤沿用 Trime 預設主題內建的 Bopomofo 布局；請使用 Trime 的
> 預設主題（不要換成其他第三方主題），否則按鍵位置可能不同。

## 這個版本包含

- `puffime.schema.yaml`
- `puffzhuyin.schema.yaml`
- `puffime.dict.yaml`（由本機字碼表產生）
- `puffzhuyin.dict.yaml`
- `rime.lua` 與 `lua/`
- `default.custom.yaml`

## Android 版先不包含

- `,,fk` / `,,fl` 忘記清單（`forgotten.lua` 與相關 schema 已移除）
- Windows 的五款配色與朱紅圖示（Trime 使用自己的主題）
- Windows 安裝腳本與 `rime_deploy.exe`

## 測試清單

- [x] 嘸蝦米：`a` + 空白 → 對
- [x] `aa` + 空白 → 寸
- [x] 英文：`the` + Enter → the
- [x] 無效碼：`zzzz` + 空白 → 留在緩衝
- [x] 注音：`` ` `` + `su3` → 你
- [x] 注音：`` ` `` + `su` → 所有聲調
- [x] 注音鍵：按一下 → ㄅㄆㄇ 注音鍵盤
- [x] 注音鍵盤：`ㄅ` + `ㄚ` + `Enter` → 吧
- [x] 注音鍵盤：`ㄋ` + `ㄧ` + `ˇ` + `Enter` → 你
- [x] 注音上屏後自動切回 QWERTY 嘸蝦米鍵盤
- [x] 注音鍵盤「嘸蝦米」鍵 → 取消並回到 QWERTY
- [x] `v` 選第二個候選
- [x] 符號形狀 Shift+Space
- [x] `/jt` → 箭頭
- [x] 雙 backtick → 兩個 backtick

## 注意

- 自行 build 時，`puffime.dict.yaml` 會由你的本機字碼表產生；請不要
  散布 build 出來的字典。字碼表請使用合法來源。
- 如果 Trime 的 Lua 版本不支援某個 processor，該功能可能要先停用；
  回報 Trime 日誌就可以針對舊機調整。

## 實機驗證

Android 17 + Trime 3.3.14 已測試：

- [x] 底部「中文／注音」鍵：按一下切中文＋換成 ㄅㄆㄇ 注音鍵盤＋進注音
- [x] 注音鍵盤上按 `ㄅ` + `ㄚ` + `Enter` → 吧
- [x] 只按 `ㄅ` → preedit 顯示 `ㄅ`，不是按鍵 `1`；空白不上屏
- [x] `ㄅ` + `ㄚ` 的候選列正常（吧、把、八…）
- [x] 注音鍵盤上按 `ㄋ` + `ㄧ` + `ˇ` + `Enter` → 你
- [x] 注音上屏後自動切回 QWERTY；可直接打 `a` + 空白 → 對
- [x] 注音選字（`2` + `Enter`）上屏後也自動返回
- [x] 「嘸蝦米」鍵可取消注音並返回，不會上屏
- [x] 返回後標點恢復半形（`,` → `,`）
- [x] `the` + Enter → the
- [x] `` `su3 `` + `Enter` → 你
- [x] `` `su `` + `Enter` → 你（所有聲調）
- [x] `` `su3 `` + `2` + `Enter` → 擬（注音數字選字正常）
- [ ] 新版：注音空白＝一聲、Enter 上屏（需在 Trime 重測）
- [x] `ak` + `v` → 鐵
- [x] 半形 `,` → `,`；自然符號 `,` → `，`；全形 `,` → `，`
- [x] 半形 `[` → `「`、`]` → `」`
- [x] 半形 `c.` → `!`；自然符號 `c.` → `！`
- [x] 全形 `,dol` → `＄`
- [x] `/jt` → `↑`
- [x] 雙 backtick → 兩個 backtick
- [x] `zzzz` + 空白 → 不送出，留在緩衝

