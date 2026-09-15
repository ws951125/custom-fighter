# Lessons Learned — custom-fighter

本文件是 `custom-fighter` 的永久工程記憶。任何已定位並修正的程式、測試、CI、部署或工具流程問題都應留下可重用的經驗。

## L-001 — Godot dynamic call return type cannot always be inferred with `:=`

- **Date:** 2026-09-12
- **Area:** Godot / GDScript / Character loadout skill resolver
- **Symptom:** PR #45 第一輪 CI 在 Godot parser 階段失敗；四個 child controller 經由動態 `host` 呼叫 resolver 時，使用 `:=` 接回傳值，Godot 無法推斷 collection 型別。
- **Root Cause:** GDScript 對動態 method call 的回傳型別推斷不足。
- **Fix:** 將相關變數改為明確的 `PackedStringArray` 等實際型別，不依賴動態呼叫的型別推斷。
- **Prevention Rule:** 任何透過 dynamic host / `call()` / runtime-resolved method 取得的 typed collection，不使用 `:=` 猜型別。
- **Validation:** 修正後 CI Run #84 通過 Godot import、main boot、Domain/Character tests、Web export、Web size budget 與 Chromium `smoke:all`。
- **Status:** Verified

## L-002 — Frame-polled Godot Web input must stay down long enough to be sampled

- **Date:** 2026-09-12
- **Area:** Playwright / Godot Web / GitHub Actions browser smoke
- **Symptom:** Chromium smoke 在等待 `playerJumping === true` 時 timeout；測試使用極短的 synthetic key down/up。
- **Root Cause:** Godot Web gameplay input 依遊戲 frame 取樣，瞬間 press 可能在兩個取樣 frame 之間完成。
- **Fix:** Frame-sensitive gameplay input 改為 held input，等待 runtime acknowledgement 後再放開。
- **Prevention Rule:** Web smoke 驗證 frame-polled action 時，不用裸 `keyboard.press()` 作為唯一輸入證據。
- **Validation:** PR #45 CI Run #93 與 merge 後 main Run #94 通過 Chromium、Edge、Pages/public production flow。
- **Status:** Verified

## L-003 — Mutation tools must be selected by exact operation before writing GitHub state

- **Date:** 2026-09-12
- **Area:** GitHub connector / repository operations
- **Symptom:** 原本要建立 feature branch，卻誤觸 issue creation action，產生不需要的 tracking issues。
- **Root Cause:** 未先鎖定正確 mutation schema 就執行寫入。
- **Fix:** 關閉誤建 issues，重新載入 branch-specific action 後才建立 branch。
- **Prevention Rule:** GitHub 寫入前先確認 mutation 類型與目標物件完全一致；不要用測試性寫入確認工具能力。
- **Validation:** 誤建 issues 已關閉，正式工作回到正確 branch/PR。
- **Status:** Verified

## L-004 — Transient browser diagnostics must be distinguished from runtime state evidence

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright runtime observation
- **Symptom:** Edge 等待短暫 dataset boolean timeout，但 runtime diagnostics 明確顯示實際 gameplay state 已成立。
- **Root Cause:** Observation window / runner scheduling flake，不是 gameplay runtime regression。
- **Fix / Operational Mitigation:** 只重跑失敗的 Edge gate，不修改無關 runtime；後續完整 production flow 通過。
- **Prevention Rule:** 先比對 runtime diagnostics、同 SHA 跨瀏覽器結果與重現性，再決定是否修改產品程式。
- **Validation:** Targeted Edge retry 與 production gates PASS。
- **Status:** Verified; assertion hardening deferred unless recurrence

## L-005 — Dynamic autoload boundaries must not rely on inferred GDScript types

- **Date:** 2026-09-12; recurrence 2026-09-13
- **Area:** Godot / GDScript parser / dynamic and Variant boundaries
- **Symptom:** Dynamic autoload / provider helper 回傳 `Variant` 時，caller 使用 `:=` 觸發 warning-as-error parser failure。
- **Root Cause:** Runtime/dynamic 邊界沒有足夠靜態型別資訊。
- **Fix:** 明確宣告 `Variant` / `bool` / `Dictionary` / `PackedStringArray` 等型別，並封裝 dynamic calls。
- **Prevention Rule:** 對 `get_node_or_null()`、autoload、dynamic host/provider/interface 與 `-> Variant` helper 不用 `:=` 推斷。
- **Validation:** PR #57 Run #105 與 M6 PR #69 Run #138 完整 GitHub gates 通過。
- **Status:** Verified

## L-006 — Mobile browser capability detection and gameplay validation need separate deterministic gates

- **Date:** 2026-09-12
- **Area:** Playwright / Godot Web / touch capability detection
- **Symptom:** Mobile smoke 將 emulation、Godot readiness、touch auto-detection 與 gameplay assertion 綁成單一 opaque wait，失敗時難以定位。
- **Root Cause:** Browser capability emulation 被當成功能路徑唯一 enable oracle，且缺少 diagnostics。
- **Fix:** JS capability 明確回傳 1/0；功能測試用 `?mobile_controls=1` 建 deterministic path，另測 production auto-detection，並輸出 dataset diagnostics。
- **Prevention Rule:** Capability detection、功能 enablement 與 gameplay assertion 分開驗證。
- **Validation:** PR #62 Run #115 通過 Godot、Chromium mobile flow 與 hosted Edge。
- **Status:** Verified

## L-007 — An isolated hosted Edge readiness timeout must not trigger unrelated runtime changes without reproducible evidence

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright startup readiness
- **Symptom:** Hosted Edge 在 unchanged Character Selection readiness timeout，其他同 SHA gates 正常。
- **Root Cause:** 孤立的 hosted-browser startup/readiness flake，缺乏 runtime regression 證據。
- **Operational Fix:** 不修改無關 runtime，只做 targeted retry / fresh latest-head run。
- **Prevention Rule:** 修改 runtime 前先比對 changed paths、同 job 前序、同 SHA cross-browser evidence 與重現性。
- **Validation:** PR #63 latest-head Run #126 全綠。
- **Status:** Verified

## L-008 — Hosted-browser movement helpers need tolerance for one-frame position overshoot

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright deterministic positioning
- **Symptom:** 固定時間 held-input 的最後一次 nudge 跨過測試 lower bound，雖 gameplay 仍可能有效。
- **Root Cause:** 位移受 hosted runner frame cadence 影響，helper 沒有 overshoot tolerance。
- **Operational Fix:** 當次只重跑 Edge；後續將相同類型 helper 改成以 runtime-observed movement 與 geometry-derived corridor 為準。
- **Prevention Rule:** Position helper 要容忍合理 one-frame overshoot，或依剩餘距離縮短最後一步。
- **Validation:** 後續完整 `smoke:all` / production flow 成功。
- **Status:** Verified; helper hardening applied on later recurrences

## L-009 — Verify successful GitHub mutations before repeating them

- **Date:** 2026-09-13; recurrence 2026-09-15
- **Area:** GitHub connector / branch and file mutation workflow
- **Symptom:** 曾在 branch-create 成功後重送 create 而得到 422；另一次在 branch 尚未建立前直接送 file mutation。2026-09-15 follow-up 又在 `fix/p3-free-tier-project-verification` 尚未真正建立前誤送 PR create，GitHub 回 422；沒有建立 PR、沒有 repository mutation。
- **Root Cause:** 非冪等 mutation 前後未把 branch/file/PR existence 與依賴順序當 source of truth。
- **Fix:** 停止重送；本次 recurrence 先精確載入 branch action，建立 branch，再依序建立 blobs/commits，最後才開 PR。
- **Prevention Rule:** 嚴格遵守 branch → files/commits → PR 的依賴順序。成功回傳即視為 source of truth，不以重送 mutation 驗證狀態。
- **Validation:** `fix/p3-free-tier-project-verification` 已由 GitHub connector 正確建立並承載後續 commits；誤送的 PR create 只回 422，未產生 PR。
- **Status:** Verified recurrence handled

## L-010 — Inherited GDScript constants must not be redeclared when a child becomes a direct dependency

- **Date:** 2026-09-13
- **Area:** Godot / GDScript inheritance / AI provider preload boundary
- **Symptom:** Child provider 重新宣告 parent 已有 preload constant，加上 generic `max()` Variant inference，造成 parser failure。
- **Root Cause:** Parent inherited members 與 warning-as-error typed numeric boundary未被正確處理。
- **Fix:** 移除 child 重複 preload；數值改明確型別與 `maxi()`。
- **Prevention Rule:** Child 不重宣告 parent constants；warning-as-error 專案優先 typed numeric helpers。
- **Validation:** PR #71 Run #143 與後續 main runs 通過。
- **Status:** Verified

## L-011 — Browser regressions must evolve with intentional package schema changes

- **Date:** 2026-09-13
- **Area:** Character Packages / Playwright / schema evolution
- **Symptom:** Package schema 刻意升級 v2，但舊 browser regression 固定要求 v1。
- **Root Cause:** 舊 export version assertion 被當成永久 invariant。
- **Fix:** Browser regression 改驗證 current export contract；legacy v1 compatibility 留給專門 domain tests。
- **Prevention Rule:** Schema 升級時盤點所有 hard-coded version assertions，分離 current-export 與 legacy-import tests。
- **Validation:** 後續 latest-head CI 通過。
- **Status:** Verified

## L-012 — Windows Godot CI should use process exit codes and preserve quoted preset arguments

- **Date:** 2026-09-13
- **Area:** GitHub Actions / Windows PowerShell / Godot export
- **Symptom:** `$LASTEXITCODE` 不可靠，且 `Windows Desktop` preset 在 `Start-Process` argument serialization 中被拆 token。
- **Root Cause:** Process exit-code 取得方式與含空白參數 quoting 不正確。
- **Fix:** 使用 `Start-Process -Wait -PassThru` / process exit code，並保留含空白 preset/path 引號。
- **Prevention Rule:** Windows runner 執行 Godot process 時用真實 process API 取 exit code，明確驗證 quoting。
- **Validation:** PR #79 Run #164 Windows native / Chromium / Edge gates 通過。
- **Status:** Verified

## L-013 — Directional melee smoke positioning must guarantee facing, not only numeric range

- **Date:** 2026-09-14
- **Area:** GitHub Actions / Windows Edge / directional melee smoke
- **Symptom:** 角色雖在 melee range，最後一次 movement 是 `A`，導致面向左側而 dummy 在右側，攻擊未命中。
- **Root Cause:** Test helper 只保證數值距離，沒有保證 facing。
- **Fix:** 先穩定放在 dummy 左側，最後只以 `D` 接近並驗證 gap。
- **Prevention Rule:** Directional attack tests 必須同時保證幾何距離與面向方向。
- **Validation:** PR #117 Run #229 通過。
- **Status:** Verified

## L-014 — Combo browser tests should validate the input buffer instead of sampling READY between hits

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / combo regression smoke
- **Symptom:** Combo helper 每擊等待短暫 READY frame，hosted runner 可能錯過 observation window。
- **Root Cause:** 測試把 runner observation cadence 變成 combo buffer 是否成立的額外條件。
- **Fix:** 每個 `J` 都以跨 Godot frame held input 送達，讓 runtime buffer 接續，再驗證 combo step/HP/recovery state。
- **Prevention Rule:** Buffered combo tests 不以中間 READY observation 作下一擊前置條件。
- **Validation:** PR #117 Run #232 Chromium/Edge PASS。
- **Status:** Verified

## L-015 — Correlated transient runtime state and flags must be observed atomically

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright runtime observation
- **Symptom:** 先等 `INVULNERABLE`，再讀 `dummyInvulnerable` 時 runtime 已可能進 READY，造成 false failure。
- **Root Cause:** Correlated transient fields 被拆成兩次 browser round-trip。
- **Fix:** 合併成單一 `waitForFunction()` predicate 同時驗證 state + flag。
- **Prevention Rule:** 多個欄位描述同一 transient phase 時，必須原子觀察一致性。
- **Validation:** PR #117 Run #232 全綠。
- **Status:** Verified

## L-016 — Hosted-browser coordinate helpers must wait for runtime-observed movement before issuing the next nudge

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright deterministic positioning
- **Symptom:** Fixed-duration nudges 配上 stale coordinate samples 累積多次 movement，從目標 corridor overshoot 到 62.5 px gap。
- **Root Cause:** Helper 以 sleep/read pacing，而非 runtime-observed movement 作 command pacing。
- **Fix:** 每次 movement 後等待 `playerX` 真實變化，接近目標時縮短 hold；overshoot 則 re-stage。
- **Prevention Rule:** Position loops 必須以 runtime telemetry pacing，並具 distance-adaptive movement 與 overshoot recovery。
- **Validation:** PR #119 Run #237 Windows Native/Chromium/Edge 首輪 PASS。
- **Status:** Verified

## L-017 — Heavy Strike smoke corridors must follow authored hitbox geometry

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Heavy Strike regression smoke
- **Symptom:** 31 px gap 被 hard-coded 40 px lower bound 拒絕，但 authored hitbox geometry 實際允許。
- **Root Cause:** Test-authored spacing preference 被誤當 gameplay invariant。
- **Fix:** Lower corridor 改依 authored range / hitbox geometry 推導，同時保留實際 damage/MP/cooldown/hit assertions。
- **Prevention Rule:** Combat test coordinate preconditions 要由 authored geometry 或明確 gameplay invariant 推導。
- **Validation:** PR #120 Run #246 通過 Native/Chromium/Edge。
- **Status:** Verified

## L-018 — Directional buff damage smoke must preserve facing while stabilizing melee range

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / buff regression smoke
- **Symptom:** Buff 已成功啟動、攻擊 input 也被接受，但 HP 不下降，因 bidirectional positioning 最後可能以 `A` 收尾而朝錯方向。
- **Root Cause:** Helper 同時有 facing 與 stale-coordinate/overshoot 風險。
- **Fix:** Runtime-observed movement、stage-left placement、只以 `D` 最終接近、adaptive hold 與 overshoot recovery。
- **Prevention Rule:** Directional melee outcome smoke 的 positioning contract 必須包含 facing。
- **Validation:** PR #120 Run #246 通過。
- **Status:** Verified

## L-019 — Coordinator-gated browser tests must distinguish pre-claim blocking from rejected claims

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Playwright / skill coordinator runtime contract
- **Symptom:** Smoke 預期 coordinator rejection counter 增加，但 runtime 在 `can_claim()` pre-claim gate 就擋住 Area，根本不會進 `try_claim()`。
- **Root Cause:** Test assertion 編碼了錯誤層級的 contract。
- **Fix:** Browser smoke 改驗證 input sampled、cast 未開始、MP 未消耗、claim count 未變；低層 rejection 留給 domain test。
- **Prevention Rule:** Integration test 應驗證真正 drive 的 public runtime path，不期待 earlier guard 阻止執行的 downstream telemetry。
- **Validation:** PR #120 Run #250 通過。
- **Status:** Verified

## L-020 — Provider name alone does not prove a zero-cost AI path

- **Date:** 2026-09-15
- **Area:** Production AI / Gemini / cost policy
- **Symptom:** P3 曾支援 OpenAI image generation 與 Gemini native image model；即使 provider 名稱是 Gemini，仍可能產生付費 API call。
- **Root Cause:** Provider boundary 沒有編碼 model-level billing eligibility，且曾把 vendor name 誤當成本保證。
- **Fix:** PR #121 移除 OpenAI production adapter，只 allow-list `gemini-2.5-flash` / `gemini-2.5-flash-lite`，以免費層 Gemini 做 prompt/reference understanding + structured design，再由 Sharp deterministic renderer 產 PNG；production 暫時 `AI_IMAGE_PROVIDER=disabled` 直到 Free Tier credential 可被安全啟用。
- **Prevention Rule:** 新增/變更 production AI model 前必須核對官方 model pricing；provider 名稱與 model 名稱都不能單獨證明零成本。
- **Validation:** PR #121 latest-head CI Run #256 PASS；merged as `9fe7f3d3f72e779fa050d1b2cff734dc999f1510`；Render 已 live on exact merge SHA and `/healthz` exposes only Gemini support while selected provider is safely disabled.
- **Status:** Code/provider boundary verified; real Free Tier credential acceptance remains blocked

## L-021 — Retry read failures, but verify state before retrying mutations

- **Date:** 2026-09-15
- **Area:** Render connector / deployment operations
- **Symptom:** 切換 Render 設定時相同 env mutation 曾被重複送出，每次成功寫入都觸發另一個 deploy。
- **Root Cause:** Generic retry 規則被錯套到 mutating operation，未先確認前一次寫入是否已成功。
- **Fix:** 停止重複寫入、查 deploy state、保留最新有效 deploy；新增 mutation retry 規則。
- **Prevention Rule:** Read-only failure 可合理 retry；任何 write/deploy trigger 若結果不確定，先讀遠端 state，不能用同一 mutation 當 confirmation。
- **Validation:** 重複 deploy 被 supersede/cancel，最新有效 deploy 到達 live；Agent rules 已區分 read retry 與 mutation retry。
- **Status:** Verified

## L-022 — A free-tier policy flag is not proof of project billing state

- **Date:** 2026-09-15
- **Area:** Production AI / Gemini billing guard / readiness contract
- **Symptom:** PR #121 的 `/healthz` 將 `free_tier_confirmed=true` 直接等同於 `GEMINI_FREE_TIER_ONLY=true`。這只能證明應用程式政策旗標被打開，不能證明 Google AI Studio / Cloud project 真的沒有啟用 paid billing。
- **Root Cause:** Application policy assertion 與 external account/project billing verification 被合併成同一欄位，命名又暗示已完成外部確認。
- **Fix:** Follow-up `fix/p3-free-tier-project-verification` 新增獨立 `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` gate；`configured=true` 必須同時具備 API key、allow-listed free-tier model、`GEMINI_FREE_TIER_ONLY=true` 與 project verification。Readiness 改為 `free_tier_policy_asserted`、`free_tier_project_verified`、`verification_mode=operator-asserted`，不再把 policy 稱為 confirmation。
- **Prevention Rule:** 對 billing、permissions、external account state 等無法由應用本身證明的條件，必須將「政策」與「外部驗證/attestation」分開建模；名稱不得暗示比實際證據更強的保證。
- **Validation:** Code/tests committed on branch at `ef96d39ad88608f74e1795cdf09ca49329ad636f`; final GitHub CI pending.
- **Status:** Fix committed; latest-head CI pending

## L-023 — Repository execution policy must be read before choosing a local/remote tool path

- **Date:** 2026-09-15
- **Area:** Agent execution workflow / GitHub-only policy
- **Symptom:** 在 follow-up 開始時，尚未完整核對 `Agent.md` 的 GitHub-only hard rule，就使用 Remote Desktop Commander 做了 branch/local-file inspection 與未提交修改；這與 custom-fighter 明確禁止本機/遠端桌面作為專案 Git/修改/驗證路徑的規則衝突。
- **Root Cause:** 先依聊天中的舊工作習慣選工具，後讀完整 repository policy，順序錯誤。
- **Fix:** 一發現規則衝突就停止 Remote Desktop Commander 專案操作，以一次 `git reset --hard origin/main` 清除該工具造成的所有未提交變更；後續 branch、blob、commit、PR 與 validation 全部改用 GitHub connector / GitHub Actions。沒有把任何 Remote Desktop 產生的 code commit 到 GitHub。
- **Prevention Rule:** 對任何 repo，第一個 mutation 前必須先從 repository source of truth 讀完整 Agent/AGENTS policy，再決定允許的工具與 validation path；聊天記憶不能覆蓋 repository hard rule。
- **Validation:** GitHub branch `fix/p3-free-tier-project-verification` 從 merge SHA `9fe7f3d3f72e779fa050d1b2cff734dc999f1510` 重新建立；正式 follow-up commits 均透過 GitHub Git data APIs 建立。
- **Status:** Verified process correction; final PR validation pending
