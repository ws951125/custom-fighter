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

目前產品與驗證基準至少參考：
- `AGENTS.md`
- `docs/MVP.md`
- `docs/STATUS.md`
- `docs/ONLINE_TESTING.md`
- `docs/WEB_LOADING.md`

## 2. 開始工作前必讀與 GitHub 真實狀態

任何 Agent 在修改前必須先確認 GitHub 當下真實狀態，不得只依聊天記憶、舊截圖或先前回報推測。

至少確認：
1. `Agent.md` 與 `AGENTS.md`。
2. `docs/MVP.md`、`docs/STATUS.md`、`docs/ONLINE_TESTING.md`。
3. 與本次工作直接相關的程式、測試與文件。
4. 目前 feature branch 與 head SHA。
5. 目前相關 PR 的 open / closed / merged / mergeable 狀態。
6. 最新相關 GitHub Actions / Web deployment 狀態。
7. 若子目錄存在 nested `AGENTS.md`，一併遵守。

若聊天內容與 Repository 現況衝突，以 Repository / GitHub 真實狀態為準，並在回報中指出差異。

## 3. 修改必須直接寫入 feature branch

- 正式程式、測試與文件修改直接寫入目前工作的 GitHub feature branch。
- 不把 patch / diff 當成主要交付方式。
- 不要求使用者手動複製貼上 source code 或手動套 patch 才能完成工作。
- 除非使用者明確要求，不直接提交到 `main`。
- 同一個 work unit 的修正優先留在同一 feature branch / PR，避免無必要分裂。

## 4. GitHub-only / Online-only 驗證硬規則

`custom-fighter` 的工程驗證必須完全在 GitHub 線上環境完成。不得連線、啟動、操作或依賴使用者本機電腦進行任何專案測試、建置、Git 同步、除錯或驗證；不得使用 Remote Desktop Commander 或其他遠端桌面／遠端終端工具作為本專案驗證路徑。

允許且優先的驗證層級：
1. GitHub Actions 上的 pure logic / domain / unit tests。
2. GitHub Actions 上的 Godot headless parse / import / boot。
3. GitHub Actions 上的 Godot headless integration / domain tests。
4. GitHub Actions 上的 Web export。
5. GitHub Actions 上的 Web size / artifact budget checks。
6. GitHub-hosted runner 上的 Chromium browser smoke / E2E。
7. GitHub-hosted Windows runner 上的 Microsoft Edge browser smoke。
8. GitHub Pages deployment 與 public reachability smoke。
9. GitHub Pages 線上網址的人工作品手感／視覺／UX 驗收。

硬性禁止：
- 不 clone / pull / checkout 到使用者電腦做驗證。
- 不在使用者電腦執行 Godot、Node、npm、Playwright、PowerShell、Python 或其他專案命令。
- 不使用 Remote Desktop Commander、遠端桌面、SSH 到使用者機器或其他本機代理。
- 不以「CI 暫時不可用」為理由改成本機測試。
- 不要求使用者執行本機指令並貼結果作為正常工程 gate。

若某項驗證無法在 GitHub Actions / GitHub Pages 完成，必須明確標示為 `Blocked` / `Residual Risk`，而不是改走本機。主觀遊戲手感或視覺驗收可請使用者直接開 GitHub Pages 線上網址操作，但不得要求下載或啟動本機專案。

## 5. GitHub Actions 異常處理

若 GitHub Actions 因 quota、runner、平台暫時錯誤、workflow stuck / cancelled、log 無法取得等外部因素不能正常完成：
- 先區分「程式失敗」與「GitHub 平台失敗」。
- 不把平台異常誤判為產品 bug。
- 不反覆浪費 Actions 額度重跑無意義流程。
- 可在 GitHub 內採取合理的線上處理，例如重跑 failed job、重跑 failed workflow、調整 workflow、改用 GitHub-hosted runner 或等待平台恢復。
- 不得改用使用者本機、Remote Desktop Commander 或其他非 GitHub 本機替代 gate。
- 若 GitHub 線上驗證暫時無法完成，標記 `Blocked` / `Residual Risk`，不得宣告 PASS 或提前 merge。

若 CI 顯示真正 code/test failure，必須先在 feature branch 修正，再由新的 GitHub Actions 證據確認通過。

## 6. Data-driven 與架構邊界

- Core combat / character / skill 規則與 UI / rendering 盡量分離。
- CharacterDefinition / SkillRegistry / skill data 應是 runtime source of truth；不得偷偷以 controller 內硬編碼 sample path 取代資料定義。
- 正常新增角色或技能不應要求修改 combat engine。
- Registry / loader 必須 fail closed：unknown id、unsafe path、錯誤 type、任意欄位或 controller/type mismatch 不得默默接受。
- Input 應以 action / intent 表示，而不是把核心邏輯綁死單一鍵盤或裝置。
- Creator tooling 可以 PC/Web-first，但輸出的 runtime data format 必須可攜。

## 7. 玩家內容與安全規則

允許的玩家內容以 validated structured data 與核准資產為主。

禁止直接由角色／技能套件載入或執行：
- user-supplied GDScript
- native library
- executable
- Python / shell / PowerShell script
- 其他任意可執行程式碼

所有外部路徑、resource type、skill id、character id 與 package metadata 都必須經 allow-list / schema / registry 驗證。

## 8. 測試與 Regression 規則

- Bug fix 應盡可能加入可重複 regression test。
- Domain / loader / registry 變更必須有 deterministic fixture 或明確 assertions。
- Gameplay input / skill binding 變更至少要有對應 browser smoke 或等價 runtime test。
- Web export 變更需確認 production export 可產生、可 boot，且不突破既有合理 size budget。
- 所有上述測試證據必須來自 GitHub Actions / GitHub Pages 線上流程。
- 不得 merge 已知 failing checks。
- 不得宣稱測試 PASS，除非有實際 GitHub 線上執行證據。

## 9. 錯誤經驗必須永久記錄

只要 Agent / Codex 的修改、測試流程、部署或操作曾出現問題，而且已找到原因並修正，就必須記錄工程經驗；不因問題很小、很快修好、只發生在 CI、Godot parser、browser smoke 或工具操作而省略。

使用 `docs/LESSONS_LEARNED.md` 作為永久工程記憶。若檔案尚不存在，第一次需要記錄時必須建立。

每筆 lesson 至少包含：
- Symptom
- Root Cause
- Fix
- Prevention Rule
- Validation
- Status（例如 Verified / Pending）

同類 recurrence 優先更新既有 lesson，而不是刪除有效歷史。

## 10. 文件與專案進度同步

每完成一個可辨識 work unit，都必須同步 `docs/STATUS.md`；若 MVP / milestone scope 有實質變化，再同步 `docs/MVP.md`。

狀態紀錄至少應能回答：
- 日期／work unit 或 milestone
- 已完成內容
- 驗證方式與結果
- 主要檔案
- 尚未完成事項
- 下一步

不得出現「程式已完成，但 Repository 完全沒有進度紀錄」。

## 11. Definition of Done

功能只有在下列適用項目完成後才能標示 Done：
1. 功能已實作。
2. 基本錯誤處理與 fail-closed 行為已完成。
3. 有可重複的 GitHub 線上驗證方式。
4. Relevant unit / domain / integration / regression tests 在 GitHub Actions 通過。
5. Godot import / boot / parse gate 在 GitHub Actions 通過。
6. 若影響 Web runtime，Web export 與 browser smoke 在 GitHub-hosted runner 通過。
7. 文件已同步。
8. `docs/STATUS.md` 已更新。
9. 若曾發生錯誤並完成修正，`docs/LESSONS_LEARNED.md` 已同步。
10. PR / branch / merge 狀態已重新查證。
11. 尚未能由 GitHub 線上流程驗證的項目已明確標為 Residual Risk / Manual Acceptance。
12. 需要使用者主觀驗收的遊戲手感／視覺變更，已提供 GitHub Pages 線上測試網址。

## 12. PR / Merge 規則

- Commit 聚焦單一邏輯工作單位。
- Commit message 清楚描述內容。
- 不提交 secrets、credentials、private tokens、production dumps。
- PR merge 前必須確認 required GitHub online validation 已完成。
- 若當輪仍需要使用者 GitHub Pages gameplay / UX acceptance，在使用者明確回報 PASS 前不得提前 merge。
- 使用者回報失敗時，保持同一 feature branch / PR 修正，再由 GitHub Actions / Pages 重新驗證。

每次回報必須列出：
- 上一個相關 PR 是否已 merge。
- 本次 PR 編號／標題／branch。
- 本次 PR 是否已 merge 到 `main`。
- 若已 merge，列出 GitHub 實際 merge SHA。

回報前必須重新查 GitHub，不得憑記憶。

## 13. 線上測試網址規則

只要有可測 Web build，每次開發結果／進度回報都必須提供直接可用網址。

Production 預設：
`https://ws951125.github.io/custom-fighter/`

若 production 尚未包含當前 PR：
- 必須明確寫「production 尚未包含本 PR」。
- 若有 branch / preview URL，需標示為 Preview。
- 若沒有 preview，不得暗示 production 已經可以驗收新功能。
- 不得以本機網址、localhost 或使用者電腦上的 build 取代 GitHub 線上測試網址。

## 14. 每次開發回報的強制格式

每次回報開發、修正、測試、文件或部署工作時，至少包含：
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

### 總進度百分比規則

- 以 `docs/MVP.md` 已定義的 M0–M8 正式 milestone 為固定分母，除非 Repository 後續正式改變 milestone 結構。
- 只有 milestone 已達正式 Done 才計入完成分子；In Progress 不自行給半分或主觀權重。
- 若 Roadmap / MVP 正式新增或移除 milestone，分母跟著 Repository 真實文件調整。
- 百分比必須能從 Repository 狀態推導，不得憑感覺填寫。

## 15. 每次修改後必須列出完整控制表

每次 code / content / config 修改後，回覆中的 `Current controls / buttons` 必須列出目前 playable/testable build 的所有 user-facing actionable input，不只列本次改動項目。

至少包含：
- Keyboard key / combination
- Mouse / touch UI（若有）
- Action name
- Gameplay / tooling purpose
- Contextual / disabled / diagnostic-only 狀態

目前若沒有可點擊 gameplay UI / touch UI，必須明確寫出，而不是省略。

## 16. 高風險變更

若任務涉及任意程式碼執行、外部不可信 package、自動下載可執行檔、secret / credential、重大架構替換、會破壞既有角色／技能資料格式的 migration，且現有規範沒有明確答案，必須先停止高風險部分並向使用者確認。

一般可逆、低風險工程細節不應反覆詢問；Agent 應自行採合理方案並驗證。

## 17. 工作原則摘要

對 `custom-fighter`：
- 先讀 Repository / GitHub 真實狀態，再動手。
- 直接修改 feature branch，不把 patch 丟給使用者。
- 所有工程驗證只使用 GitHub Actions / GitHub Pages；完全不使用使用者本機或 Remote Desktop Commander。
- GitHub 線上驗證不可用時就標記 Blocked，不以本機繞過。
- 每次錯誤修正留下 lesson。
- 每次進度同步 STATUS。
- 每次回報列整體進度、完整 controls、GitHub 驗證證據、Test URL、PR/Merge 真實狀態。
- 沒有 GitHub 線上證據就不宣稱 PASS，沒有驗收就不提前 merge。

## 18. 每次回覆必須明確列出下一步

- 每次對使用者回覆，不論是進度更新、完成回報、錯誤回報、測試結果或 blocker，都必須明確列出 `➡️ 下一步要進行的是什麼`。
- 下一步必須寫成具體可執行的工程動作，例如「等待 Run #225 Chromium 完成後檢查 Windows Edge smoke」，不得只寫「繼續處理」或「下一步繼續」。
- 若目前被外部條件阻擋，必須同時寫明 blocker 與解除 blocker 後第一個會執行的工程動作。
- 若仍有安全且不受 blocker 影響的工作可做，應先連續完成，不因單一 blocker 提前停止。
- 此欄位是每次回覆固定必填項目，即使本次 work unit 已完成也不得省略。
## 18. Production AI cost policy — free Gemini only

- Production AI must use Google Gemini's API free tier only; do not connect OpenAI or any other paid AI provider unless the user explicitly reverses this policy.
- The default production model is `gemini-2.5-flash`; only models explicitly verified to have a Gemini Developer API free tier may enter the allow-list.
- Production must also require `GEMINI_FREE_TIER_ONLY=true`, and the configured `GEMINI_API_KEY` must belong to an AI Studio project that has not enabled paid billing. The flag is an assertion/guard, not proof of Google account billing state.
- Gemini native image-generation models are not valid fallbacks when their API pricing has no free tier.
- The AI path should use free Gemini for prompt/reference understanding and structured design output, then use project-owned deterministic rendering/processing for final VFX assets.
- `AI_IMAGE_PROVIDER` must fail closed outside `gemini`; paid-provider fallback is prohibited.
- Provider credentials stay server-side; secrets never enter Git, browser storage, query parameters, fixtures or Creator data.
- Before changing the allow-list, verify current Google pricing/model availability from official documentation.

## 19. Connector / deployment retry rule

- A single transient connector, authorization, device-routing, network or provider error is not enough to declare GitHub/Render/other authorized tooling unavailable.
- Retry transient failures multiple times with corrected explicit identifiers or parameters when available (for example device ID or workspace ID), while preserving tool safety requirements.
- Distinguish transient transport/auth/session errors from hard permission, configuration or destructive-operation blockers.
- Do not bypass connector safety gates such as explicit workspace confirmation merely to make a retry succeed.
- Record repeated failures and the final root cause/fix in `docs/LESSONS_LEARNED.md` when the issue affects project execution.

## 20. Retry safety for mutating connectors

- Read-only connector failures may be retried several times after correcting session, device, workspace, or request parameters.
- Mutating connector calls (for example Render environment updates/deploy triggers) must not be blindly replayed. After an uncertain result, first inspect current remote state before retrying.
- If a mutation already succeeded, do not send the same mutation again merely to confirm it; use a read/status endpoint instead.
- When repeated mutations accidentally occur, stop issuing writes, inspect the resulting deploy/action queue, keep only the latest valid operation in flight, and record the incident in `docs/LESSONS_LEARNED.md`.
