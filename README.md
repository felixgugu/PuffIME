> **本 repo 沒有嘸蝦米字碼表，要自己去下載。**
>
> Windows 安裝包也不含嘸蝦米字碼表或嘸蝦米字典；請把你自己合法取得的
> `liu7.cin` 或 `boshiamy.lime` 放進 `data/`，雙擊 `install.bat` 會在本機 build 後安裝。

# PuffIME（泡芙輸入法）

Windows / Android 的**嘸蝦米輸入法**，用 Rime 打造。

- **嘸蝦米**：打一碼就列出所有候選字，常用字優先；每多打一碼就縮小。
- **注音**：打 `` ` `` 直接切注音，不用換輸入法。
- **英文**：直接打，候選列最後有原文；可連打整句，Enter 上屏。
- **順手功能**：`v` 快速選第 2 個、同音字查詢、符號形狀、`/X` 符號選單、15 款配色。

## Windows 安裝

1. 下載 [PuffIME-win64.zip](https://github.com/felixgugu/PuffIME/releases/latest/download/PuffIME-win64.zip)。
2. 下載你自己合法取得的 `liu7.cin`（或 `boshiamy.lime`）。
3. 解壓縮 `PuffIME-win64.zip`，把字碼表放進裡面的 `data\` 資料夾。
4. **雙擊 `install.bat`**。它會用你的字碼表在本機 build 字典，然後安裝。
5. 看到 `Done.` 就完成了。
6. 在輸入框按 **Ctrl + &#96;** 或 **F4**，選「泡芙輸入法」。

> 安裝程式會自動安裝小狼毫（需要網路）、備份原本的 Rime 設定，然後重新部署。
> 字碼表只留在你的電腦上，不會上傳；套件本身不含嘸蝦米字碼表或嘸蝦米字典。
> 如果 Windows 跳出「已保護您的電腦」：按「更多資訊」→「仍要執行」。
> 如果跳出「開啟檔案」警告：按「執行」。
> 如果防毒軟體誤擋 `make_dict.exe`：請允許執行，它只會讀你的字碼表並在本機產生字典。

安裝完如果語言列沒有小狼毫，到 `C:\Program Files\Rime\weasel-0.17.4\` 執行
`WeaselSetup.exe`，把它加入鍵盤。

### 配色

內建 15 款配色。安裝後在 `PuffIME-win64` 資料夾執行：

```powershell
powershell -ExecutionPolicy Bypass -File theme-package.ps1 -List
powershell -ExecutionPolicy Bypass -File theme-package.ps1 -Name dark
```

`-Name` 可用：`light`、`dark`、`gray`、`macaron`、`mediterranean`、`sakura`、
`cherry`、`ocean`、`mint`、`lavender`、`morandi_blue`、`morandi_tea`、
`amber_dark`、`forest_dark`、`ink_dark`（也可用中文「淺、深、灰、馬卡龍、
地中海、櫻、櫻桃、海洋、薄荷、薰衣草、莫蘭迪藍、莫蘭迪茶棕、琥珀深、森林深、墨黑」）。
不帶 `-Name` 會列出編號讓你選。

### 反安裝

雙擊 `uninstall.bat`，或執行：

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-package.ps1
```

它會移除 PuffIME 的字典、Lua、方案、配色與使用者資料，並重新部署 Rime；
小狼毫本身會保留。常用選項：

- `-UninstallWeasel`：連小狼毫一起移除（winget）。
- `-RestoreBackup`：還原安裝前自動備份的 `%APPDATA%\Rime.backup-*`。
- `-KeepUserData`：保留忘記清單與使用者詞庫。
- `-NoBackup`：不另外保留安全備份。

## 怎麼打字

| 動作 | 說明 |
|---|---|
| 打嘸蝦米碼 | 例如 `a` → 對；空白上屏 |
| 選字 | 數字鍵 `1`–`0` |
| 翻頁 | `PageUp` / `PageDown` |
| 英文 | 直接打；`Enter` 上屏原文，可連打英文句子 |
| 注音 | 先打 `` ` ``，再打注音，例如 `` `su3 `` + `Enter` → 你；空白是一聲、Enter 才上屏 |
| `v` | 有候選時，快速上屏第 2 個候選 |
| `'` + 字碼 | 同音字查詢：例如 `'neo` → 同、銅、童、桐… |
| `Shift+Space` | 切換符號形狀（半形 → 自然 → 全形） |
| `CapsLock` | 英文模式（長英文用） |
| `,,fk` / `,,fl` | 忘記清單 / 上一次從注音上屏的字 |

### 前綴候選（這個最特別）

打一碼就會列出所有以這個碼開頭的字，依**常用度**排序；每多打一碼，候選就減少。

- `i` → 後、我、說、這、讓、話、請…
- `a` → 對、也、會、點、過…
- `aa` → 寸、丶、錢、鋪、鑫…

精確碼的候選一定排最前面（維持字碼表順序），後面才是依字頻排序的補全候選。
候選旁邊會顯示「打這個碼可以到它」的最短碼，例如 `a` 下的「或」顯示 `aqoe`。

### 同音字查詢（知道讀音、忘記拆碼）

先按 `'`，再打你知道的那個同音字的正常拆碼。例如不會拆「龜」，但知道「規」是
`qnmr`：

```
'qnmr
```

候選會先列出原字（規），後面是所有同音字（歸、龜…），同音字旁會顯示它的最短拆碼。
另一個例子：`'neo` → 同、銅、童、桐、彤…

- 第一個候選是原本字碼會出來的字；按空白會上屏它。
- 後面的同音字依 `essay.txt` 字頻排序，聲調要相同。
- 破音字（例如台、行、長）取最常用讀音。
- 候選太多時用 PageUp/PageDown 翻頁，或直接按數字選。
- `'` 單獨按仍然是「、」；`''` 仍然是「“」，不影響原本的標點碼。
- 同音字只收字碼表裡有的字，所以每個候選都查得到拆碼。

## Android（Trime 同文輸入法）

Android 版**要先安裝 Trime（同文輸入法）**。目前不提供預編譯的字典，請用你自己的
字碼表在 Windows build 後再放到手機。

### 1. 手機先安裝 Trime

- 在 Google Play 搜尋「Trime 同文輸入法」，或到
  [Trime 的 GitHub Releases](https://github.com/osfans/trime/releases) 下載 APK。
- 安裝後到 Android 設定 → 系統 → 語言與輸入 → 螢幕鍵盤，啟用 Trime。

### 2. 在 Windows 產生 Trime 方案包

需要這個 repo 和 Python。

1. 下載這個 repo（GitHub → Code → Download ZIP，或 `git clone`）。
2. 把 `liu7.cin` 或 `boshiamy.lime` 放進 `data\`。
3. 執行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_trime.ps1
```

4. 會產生 `release\PuffIME-trime.zip`。

### 3. 放到手機並部署

1. 把 `PuffIME-trime.zip` 傳到手機。
2. 解壓到 `Download/PuffIME`，檔案要**直接放在這個資料夾**，不要多一層。
3. 開 Trime：
   - 第一次啟動：選「選擇外部資料夾…」→ `Download/PuffIME`
   - 已設定過：設定 → 使用者資料夾 → 資料儲存模式 →
     **從外部存儲同步** → 選同一個資料夾
4. 回 Trime 按 **「部署」**。
5. 選「泡芙輸入法」。

### 4. 注音鍵

底部空白鍵左邊有 **「中文／注音」** 鍵：

- 按一下：切中文並換成 **ㄅㄆㄇ 注音鍵盤**
- 長按：切換中文／英文

注音上屏後會自動回嘸蝦米 QWERTY 鍵盤。詳細圖解與測試清單在
`platforms/android/trime/README.md`。

> 如果鍵盤看起來還是 Gboard（空白鍵寫 English），先到 Android 設定 →
> 系統 → 語言與輸入 → 螢幕鍵盤啟用 Trime，再用鍵盤切換鍵選 Trime。

## Mac / iOS（未實機測試）

> 目前沒有 Mac / iPhone 實機測試，以下是可行方向。

### macOS：Squirrel（鼠鬚管）

1. 安裝 [Squirrel](https://github.com/rime/squirrel/releases/latest)（macOS 13+）。
2. 用 Python 3 產生字典（或從 Windows 版複製 `puffime.dict.yaml`、`puffzhuyin.dict.yaml`、`lua/`）：

   ```bash
   python3 tools/make_zhuyin.py
   python3 tools/make_dict.py --input data/liu7.cin --essay data/essay.txt --out dist
   ```

3. 把檔案放到 `~/Library/Rime`：

   ```bash
   mkdir -p ~/Library/Rime
   cp src/puffime.schema.yaml src/puffzhuyin.schema.yaml src/rime.lua src/default.custom.yaml ~/Library/Rime/
   cp -R src/lua ~/Library/Rime/
   cp dist/lua/*.lua ~/Library/Rime/lua/
   cp dist/puffime.dict.yaml dist/puffzhuyin.dict.yaml ~/Library/Rime/
   ```

4. 點 Squirrel 選單 →「重新部署」，再選「泡芙輸入法」。
5. 注意：
   - `install.bat`、`make_dict.exe`、`rime_deploy.exe` 是 Windows 專用。
   - `weasel.custom.yaml` 不適用；Mac 要用 `squirrel.custom.yaml`（目前未提供）。
   - `,,fk` / `,,fl` 的 `forgotten.lua` 目前寫死 `%APPDATA%`，macOS 可能無法使用，需另外改路徑。
   - `.ico` 圖示是 Windows 用，Mac 會忽略。

### iOS：Hamster（仓输入法）或 iRime

iOS 不能在本機 build，必須先在 Mac / Windows 產生字典。

1. 安裝 [Hamster（仓输入法）](https://apps.apple.com/app/id6446617683)（iOS 16+）或 iRime。
2. 在電腦上 build 出字典（同 macOS 步驟）。
3. 把以下檔案放在 zip 的根目錄（不要多一層資料夾）：
   - `puffime.schema.yaml`
   - `puffzhuyin.schema.yaml`
   - `puffime.dict.yaml`
   - `puffzhuyin.dict.yaml`
   - `rime.lua`
   - `lua/`
   - `default.custom.yaml`
4. Hamster → 輸入方案設定 → `+` → 匯入方案 → 選 zip；或用 Wi-Fi 上傳。
5. 按「重新部署」，到 iOS 設定 → 一般 → 鍵盤 → 加入 Hamster，開啟「允許完全訪問」。
6. 選「泡芙輸入法」。

注意：

- iOS 鍵盤擴充有記憶體限制，字典＋Lua 要實測。
- Hamster 對 `rime.lua` 全域載入、`lua_processor` / `lua_filter` 的相容性要測；如果不支援，要改成模組化 Lua。
- `forgotten.lua` 在 iOS sandbox 可能無法使用。
- 目前沒有官方 iOS 套件，以上是自行嘗試方向。

## 注意

- 只支援 Windows 10/11 x64。
- Windows 套件不含嘸蝦米字碼表或嘸蝦米字典；第一次安裝會用你自己的字碼表在本機 build。
- 請不要把你 build 出來的字典再散布；字碼表請使用合法來源。
- 前綴候選是靜態字頻排序，不會學習個人選字。

## 免責聲明 (Disclaimer)

1. **版權聲明**：本專案為獨立開發之開源輸入法程式，**本專案原始碼及發布版本中均不包含、不內建、亦不散布任何未經授權之字碼對照表檔案**。
2. **商標宣告**：「嘸蝦米」及「Boshiamy」為行易有限公司之註冊商標。本專案（PuffIME）與行易有限公司無任何投資、授權或合作關係，文中所提及之商標名稱僅供相容格式與拆碼規格之客觀說明使用。
3. **使用者責任**：使用者需自行提供合法授權之參考碼表檔案（如自行購買正版軟體取得之對照檔或使用開源字碼檔）。

## 給開發者

build、測試、字碼表放法、設計說明都在 `docs/` 和 `tools/`。
