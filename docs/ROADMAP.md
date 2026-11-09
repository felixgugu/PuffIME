# Roadmap

## 已完成（MVP）

- [x] `liu7.cin`（CIN）與 `boshiamy.lime`（LIME）雙來源轉檔
- [x] 嘸蝦米候選與選字
- [x] 嘸蝦米前綴候選：打一碼列出所有以該碼開頭的字，逐碼縮小
- [x] 前綴候選依 `essay.txt` 字頻排序（精確碼維持字碼表順序）
- [x] 英文原文候選（quality 最低，Enter 原文上屏）
- [x] 連續英文：只剩英文時空白與數字留在緩衝，Enter 一次上屏整句
- [x] 含符號的無效拆碼按空白不送出（留在緩衝）；Enter 無條件原文上屏
- [x] 第一碼 `` ` `` → 大千注音（含 preedit、詞語）
- [x] 注音段數字輸入 + Shift+數字選字
- [x] 注音段空白＝一聲（帶 `=` 別名碼）、Enter 才上屏；`稽` 等一聲字可用翻頁選取
- [x] 注音段 Enter 上屏 highlight 候選（沒有候選時不送出原文）
- [x] 注音無聲調查詢：`su` 列出所有聲調，`su3` 縮小到三聲（單音節）
- [x] 注音前綴候選：只打 `1`（ㄅ）等聲母時列出該碼開頭的常用字，依字頻排序
      （精確碼候選仍排最前面）
- [x] 符號分類選單（Weasel 內建 `/X`，例如 `/jt`、`/sx`、`/bq`）
- [x] `, . [ ] '` 不被翻頁鍵吃掉
- [x] 中途 `` ` `` guard
- [x] 簡碼提示：嘸蝦米候選顯示最短碼
- [x] `v` 快速選第 2 個候選（前綴檢查，避開有效碼）
- [x] 候選註記字級 10pt / 灰色
- [x] 五款配色（淺／深／灰／馬卡龍／地中海）與切換工具
- [x] 自訂方案圖示（朱紅方印 `puff.ico`、ASCII 灰階 `puff_ascii.ico`）
- [x] 符號形狀三態（Shift+Space：半形／自然符號／全形）
- [x] 連按兩次 backtick 直接上屏兩個 backtick
- [x] 忘記清單 `,,fk`：注音上屏自動記錄，依最後使用時間排序
- [x] `,,fl`：只查最新一次注音上屏的字碼
- [x] 注音候選不顯示 `簡/拆`（候選窗較窄；字碼改用 `,,fl` / `,,fk` 查）
- [x] 轉檔器單元測試 + headless 引擎測試
- [x] 一鍵 build / deploy（`rime_deploy.exe`，無 UI）

## Android / Trime

- [x] 目錄重整：`platforms/windows/`、`platforms/android/trime/`
- [x] Trime 方案包打包腳本 `tools/build_trime.ps1`
- [x] Android 版移除 `,,fk` / `,,fl` 與 Windows 主題／圖示
- [x] Trime 注音鍵：底部「中文／注音」按一下切中文＋進注音
- [x] 注音鍵切換 ㄅㄆㄇ 注音鍵盤；上屏後自動返回 QWERTY，左下「嘸蝦米」可取消
- [x] 一鍵安裝到其它手機：`tools/install_trime_phone.ps1`（adb 複製＋自動部署）
- [x] 免電腦安裝：Trime 外部資料夾同步
- [x] Android 16 實機測試（Trime 3.3.13）：嘸蝦米、英文、注音、ㄅㄆㄇ 鍵盤、`v`、符號三態、`/X`、雙 backtick 正常
- [ ] 更舊 Android / Trime 版本相容性
- [ ] APK（後續）

## 下一步

### 1. 英文詞庫補完

- 產生 `puffenglish.dict.yaml`（例如從 `easy_en` 過濾 `^[a-z]+$`）
- `table_translator@english`，`enable_completion: false` 先做精確匹配
- 之後加「英文補完」開關（`enable_completion: true` 或前綴模式）
- 英文候選註記 `英`、大小寫變體

### 2. 嘸蝦米完整體驗

- 快打模式（` ,,sp`）
- 前綴候選的個人選字學習（像 LIME 一樣記住常選字；目前是靜態 essay 字頻）
- 可選的使用者詞庫學習（`enable_user_dict` 開關；目前固定順序）
- 同音字查詢
- 詞庫/造詞
- 繁簡過濾（用 essay/OpenCC 字頻或字集）
- 20 個 PUA 字對應到 Unicode

### 3. 注音

- 無聲調詞語（例如 `sucl` → 你好；目前只支援單音節）
- 注音 abbreviation（只打聲母）
- 句子連打（需要 script_translator/prism 或自建 sentence 模型）
- 詞頻調整：目前用 essay，之後可加使用者詞頻

### 4. 安裝與發佈

- [x] zip 套件 + `install.bat` 雙擊安裝（winget 安裝 Weasel、備份、rime_deploy）
- [x] release 不含字碼表/衍生字典；`make_dict.exe` 用使用者自己的字碼表本機 build
- NSIS 安裝包（含 Weasel + 設定）
- 方案選單圖示、主題
- 首次安裝說明
- 資料來源確認（嘸蝦米表、terra、essay）

### 5. 其他

-  Shift+數字選字提示（注音段）
-  可選的「強制英文」鍵
-  自訂詞庫編輯介面
-  如果 Rime 的限制太多，再把引擎核心搬到 PIME/TSF
