# Agent Instructions — custom-fighter

本文件定義任何 AI Agent / Codex / 自動化開發工具在 `custom-fighter` 中的共同工作規則。所有開發、修正、文件、測試、PR 與部署工作都必須遵守。

## 1. 專案定位

`custom-fighter` 是以 Godot 為核心、可於 Web 執行的資料驅動格鬥遊戲／角色技能平台。

核心原則：
- Cloud-first / CI-first：優先由 Agent 在 GitHub、Godot headless、Web export 與 browser smoke 完成驗證。
- Online-test-first：可線上驗收的功能優先提供部署網址，不把例行測試丟給使用者本機處理。
- Data-driven：角色、技能、VFX、套件與設定以驗證過的資料／Resource 驅動，正常新增內容不應要求修改 combat engine。
- Cross-platform runtime：核心 combat / character / skill / package 邏輯不得綁死單一桌面平台。
- Safe content：玩家內容不得執行任意 GDScript、native library、exe、Python、shell 或其他任意程式碼。
- Replaceable providers：未來 AI/VFX provider 必須可替換，不得讓 runtime 綁死單一雲端供應商。
- Regression protected：任何 bug fix 應盡可能新增或強化自動化 regression test。
- Secrets never enter Git。

目前產品與驗證基準至少參考：`AGENTS.md`、`docs/MVP.md`、`docs/STATUS.md`、`docs/ONLINE_TESTING.md`、`docs/WEB_LOADING.md`。

## 2. 開始工作前必讀與 GitHub 真實狀態

任何 Agent 在修改前必須先確認 GitHub 當下真實狀態，不得只依聊天記憶、舊截圖或先前回報推測。至少確認 `Agent.md`、`AGENTS.md`、相關狀態/測試文件、相關程式與測試、feature branch/head SHA、PR 狀態、GitHub Actions/Web deployment 狀態及任何 nested `AGENTS.md`。若聊天內容與 Repository 現況衝突，以 Repository / GitHub 真實狀態為準，並在回報中指出差異。

## 3. 修改必須直接寫入 feature branch

- 正式程式、測試與文件修改直接寫入目前工作的 GitHub feature branch。
- 不把 patch / diff 當成主要交付方式，不要求使用者手動套用。
- 除非使用者明確要求，不直接提交到 `main`。
- 同一 work unit 優先留在同一 feature branch / PR。

## 4. GitHub-only / Online-only 驗證硬規則

`custom-fighter` 的工程驗證必須完全在 GitHub 線上環境完成。不得連線、啟動、操作或依賴使用者本機電腦進行專案測試、建置、Git 同步、除錯或驗證；不得使用 Remote Desktop Commander、遠端桌面、SSH 或其他本機代理作為驗證路徑。

允許且優先：GitHub Actions pure logic/domain/unit、Godot headless import/boot/integration、Web export/size budget、GitHub-hosted Chromium、GitHub-hosted Windows Edge、GitHub Pages/public reachability，以及 GitHub Pages 上的人工 UX/手感驗收。

若無法在線上完成，標示 `Blocked` / `Residual Risk`，不得改走本機，也不得宣告 PASS。

## 5. GitHub Actions 異常處理

- 區分程式失敗與 GitHub 平台失敗。
- 平台暫時錯誤可合理重跑 failed job/workflow，但不得浪費額度反覆重跑。
- 不得以 CI 異常為理由改成本機測試。
- 真正 code/test failure 必須先在 feature branch 修正，再以新的 GitHub Actions 證據確認。

## 6. Data-driven 與架構邊界

- Core combat / character / skill 與 UI/rendering 盡量分離。
- CharacterDefinition / SkillRegistry / skill data 是 runtime source of truth。
- Registry/loader 對 unknown id、unsafe path、錯誤 type、任意欄位或 controller/type mismatch 必須 fail closed。
- Input 以 action/intent 表示；Creator 可 PC/Web-first，但輸出 runtime data format 必須可攜。

## 7. 玩家內容與安全規則

玩家內容只允許 validated structured data 與核准資產。禁止由角色/技能套件執行 user-supplied GDScript、native library、executable、Python/shell/PowerShell 或其他任意程式碼。外部路徑、resource type、skill/character id 與 package metadata 必須經 allow-list/schema/registry 驗證。

## 8. 測試與 Regression 規則

- Bug fix 應盡可能加入 regression test。
- Domain/loader/registry 變更要有 deterministic fixture/assertions。
- Gameplay input/skill binding 變更至少有 browser smoke 或等價 runtime test。
- Web 變更確認 export、boot、size budget。
- 測試證據只接受 GitHub Actions/GitHub Pages；不得 merge 已知 failing checks。

## 9. 錯誤經驗必須永久記錄

找到原因並修正的修改、測試、部署或操作問題必須記錄於 `docs/LESSONS_LEARNED.md`。每筆至少包含 Symptom、Root Cause、Fix、Prevention Rule、Validation、Status；同類 recurrence 優先更新既有 lesson。

## 10. 文件與專案進度同步

每完成一個可辨識 work unit，都必須同步 `docs/STATUS.md`；若 MVP/milestone scope 有實質變化，再同步 `docs/MVP.md`。狀態至少包含 work unit/milestone、完成內容、驗證方式與結果、主要檔案、未完成事項、下一步。

## 11. Definition of Done

適用項目必須完成：功能實作、fail-closed/error handling、可重複 GitHub 線上驗證、相關 tests PASS、Godot import/boot/parse PASS、Web export/browser smoke PASS、文件與 STATUS 同步、錯誤 lesson 同步、PR/branch/merge 重新查證、Residual Risk 明示、需要人工 UX 驗收時提供 GitHub Pages URL。

## 12. PR / Merge 規則

- Commit 聚焦單一 work unit，不提交 secrets/credentials/private tokens/production dumps。
- PR merge 前確認 required GitHub online validation 完成。
- 若需使用者 Pages gameplay/UX acceptance，使用者 PASS 前不得提前 merge。
- 回報前重新查 GitHub，並列出上一相關 PR merge 狀態、本次 PR/branch、是否 merge main、實際 merge SHA。

## 13. 線上測試網址規則

只要有可測 Web build，每次進度回報都提供直接網址。Production：`https://ws951125.github.io/custom-fighter/`。若 production 尚未包含本 PR，必須明確標示；沒有 preview 時不得暗示 production 已包含新功能。

## 14. 每次開發回報的強制格式

每次回報至少包含：
- `📊 整個專案總進度`
- `📈 整個專案總進度百分比`
- `✅ 已完成`
- `🟡 進行中`
- `⏳ 未完成 / 下一步`
- `⚠️ Blocked / Residual Risk`
- `🆕 New / changed functionality`
- `🎮 Current controls / buttons`
- `🧪 Validation`
- `🐞 Errors / Fixes`
- `🔗 Test link`
- `🌿 Branch / PR / Merge`
- `🧩 功能說明`

總進度百分比必須依 Repository 正式 milestone/roadmap 的固定分母與已達 Done 的分子推導，不得憑感覺給權重。

## 15. 每次修改後必須列出完整控制表

每次 code/content/config 修改後，`Current controls / buttons` 必須列出目前 playable/testable build 的所有 user-facing actionable input，包含 keyboard、mouse/touch、action、purpose、contextual/disabled/diagnostic-only 狀態。沒有可點擊 gameplay/touch UI 時也要明示。

## 16. 高風險變更

任務涉及任意程式碼執行、不可信 package、自動下載 executable、secret/credential、重大架構替換或破壞資料格式 migration，且現有規範沒有明確答案時，先停止高風險部分並向使用者確認。一般可逆低風險工程細節自行處理並驗證。

## 17. 工作原則摘要

先讀 GitHub 真實狀態；直接修改 feature branch；工程驗證只用 GitHub Actions/Pages；線上驗證不可用就標 Blocked；錯誤修正留 lesson；work unit 同步 STATUS；回報列整體進度、完整 controls、GitHub 證據、Test URL、PR/Merge 真實狀態；沒有線上證據不宣稱 PASS。

## 18. 每次回覆必須明確列出下一步

- 每次回覆都必須明確列出 `➡️ 下一步要進行的是什麼`。
- 下一步寫成具體可執行工程動作，不得只寫「繼續處理」。
- 若被外部條件阻擋，寫明 blocker 與解除後第一個動作；仍有安全且不受阻擋工作時先連續完成。

## 18A. Production AI cost policy — free Gemini only

- Production AI 只使用 Google Gemini API Free Tier；除非使用者明確改變政策，不接 OpenAI 或其他付費 AI provider。
- 預設 production model `gemini-3.6-flash`；allow-list 變更前須查官方目前 pricing/model availability。
- 必須要求 `GEMINI_FREE_TIER_ONLY=true`；API key 所屬 AI Studio project 不得啟用 paid billing。此 flag 是 guard/assertion，不是 Google billing 自動證明。
- Gemini native image generation 若沒有 API free tier，不得作 fallback。
- free Gemini 做 prompt/reference understanding 與 structured design output，最終 VFX 由專案 deterministic renderer 處理。
- `AI_IMAGE_PROVIDER` 在 gemini 以外 fail closed；credentials server-side，secrets 不進 Git/browser/query/fixtures/Creator data。

## 19. Connector / deployment retry rule

單次 transient connector/auth/device/network/provider error 不足以宣告工具不可用。Read failure 可用正確 identifiers 合理重試；不得繞過安全 gate。重複失敗且影響專案執行時記錄 lesson。

## 20. Retry safety for mutating connectors

Mutating connector call 不得盲目重播；結果不確定時先讀 remote state。若 mutation 已成功，只讀 status 確認。若意外重複 mutation，停止寫入、檢查 queue、只保留最新有效操作並記錄 lesson。

## 21. 每次回覆的進度必須先同步到 GitHub

- 任何進度回覆只要宣告程式、測試、文件、設定、修正或 work unit 已新增/修改/完成/推進，對應變更必須在回覆前 commit 到目前 GitHub feature branch。
- local-only、未 push、暫存或只存在聊天中的內容不得算正式進度；未同步時標示 `尚未同步到 GitHub` 且不得計入 Done/進度。
- 回覆前重新核對 branch、head SHA、相關 PR；完成 work unit 同步 STATUS，有錯誤經驗同步 LESSONS。
- merge 後重新確認 main merge SHA；GitHub synchronization 與 production deployment/verification 必須區分。
- 此規則適用每一次回覆。

## 22. 每次回報必須說明「這輪實際專案功能」的用途

- 每次對使用者回報時，固定加入 `🧩 功能說明`。
- 此欄位只解釋**本輪實際修改、新增、修正或驗證的專案產品功能**：說明該功能是做什麼、使用者或系統在什麼情境使用、它解決什麼問題或帶來什麼行為。
- 不得把 Agent 規則、進度文件、PR、CI、GitHub 同步、測試流程、部署流程等工程管理工作的用途冒充為「功能說明」。
- 若本輪只是文件/Agent 規則/PR/CI/部署/狀態查核等工作，且**完全沒有修改專案中的產品功能**，`🧩 功能說明` 必須直接寫：`這輪沒有產品功能變更`。
- 若本輪只有驗證既有產品功能而沒有修改功能，可說明本輪驗證的是哪個產品功能及其用途，但必須明確註明「僅驗證，沒有修改該產品功能」。
- 若同一輪同時修改多個產品功能，逐項說明各功能用途，且只列本輪真正有 GitHub 變更/驗證證據的項目。
- 此規則與第 21 節 GitHub 同步規則共同適用：尚未同步到 GitHub 的產品修改不得當成本輪已完成的功能來說明。