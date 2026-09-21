# Lessons Learned — custom-fighter

本文件是 `custom-fighter` 的永久工程記憶。任何已定位並修正的程式、測試、CI、部署或工具流程問題都應留下可重用的經驗。

## L-001 — Godot dynamic call return type cannot always be inferred with `:=`

- **Date:** 2026-09-12
- **Area:** Godot / GDScript / Character loadout skill resolver
- **Symptom:** PR #45 第一輪 CI 在 Godot parser 階段失敗；四個 child controller 經由動態 `host` 呼叫 resolver 時，使用 `:=` 接回傳值，Godot 無法推斷 `errors`` 的型別。
- **Root Cause:** GDScript 對動態 method call 的回傳型別推斷不足；用 `:=` 讓 parser 必須自行推斷，導致 parse failure。
- **Fix:** 將相關 `errors` 變數改為明確的 `PackedStringArray` 型別，不依賴動態呼叫的型別推斷。
- **Prevention Rule:** 任何透過 dynamic host / `call()` / runtime-resolved method 取得的 typed collection，不使用 `:=` 猜型別；在 parser 邊界明確宣告 `PackedStringArray`、`Dictionary`、`Array[...]` 或其他實際型別。
- **Validation:** 修正後 CI Run #84 通過 Godot import、main boot、Domain/Character tests、Web export、Web size budget 與 Chromium `smoke:all`。
- **Status:** Verified

## L-002 — Frame-polled Godot Web input must stay down long enough to be sampled

- **Date:** 2026-09-12
- **Area:** Playwright / Godot Web / GitHub Actions browser smoke
- **Symptom:** PR #45 CI Run #87 的 Godot import、main boot、domain tests、Web export 與 size budget 全部通過，但 Chromium `smoke:web` 在等待 `playerJumping === true` 時於 `tests/web_smoke.mjs` timeout；測試使用 `page.keyboard.press('Space')` 產生極短的 synthetic key down/up。
- **Root Cause:** Godot Web gameplay input 是依遊戲 frame 取樣；在 hosted browser runner 的 frame cadence 下，瞬間 `keyboard.press()` 可能在兩個 Godot 取樣 frame 之間完成，造成實際按鍵事件未被 gameplay loop 看見。相同風險也會讓 cooldown rejection 測試出現 false positive：按鍵若根本未被取樣，看起來也像成功拒絕重複施放。
- **Fix:** 將 frame-sensitive gameplay input 改為跨 Godot frame 的 held input。`Space` 與 `K` 先 `keyboard.down()`，等待 runtime diagnostics 確認 Jump/Dash 狀態後再 `keyboard.up()`；`U` 初次施放與 cooldown recast 改用既有 `nudge()` held-input helper，與 `I`、`J` 的既有策略一致。
- **Prevention Rule:** Web smoke 若驗證的是 Godot frame-polled gameplay action，不使用裸 `keyboard.press()` 作為唯一輸入證據；應持續按鍵至少跨一個 game frame，或等待 runtime acknowledgement 後再放開。拒絕／cooldown 類測試也必須證明輸入真的被送達，而非把 dropped input 當成成功拒絕。
- **Validation:** PR #45 CI Run #93 通過 Chromium 與 GitHub-hosted Windows Edge；merge 後 main CI Run #94 再通過 Chromium、Windows Edge、GitHub Pages public reachability 與 production Edge real-game flow。
- **Status:** Verified

## L-003 — Mutation tools must be selected by exact operation before writing GitHub state

- **Date:** 2026-09-12; recurrence 2026-09-15; recurrence 2026-09-16
- **Area:** GitHub connector / repository operations
- **Symptom:** 開始 M3 Slice 5 時，原本要建立 feature branch，卻誤觸 issue creation action，產生兩個不需要的 tracking issues (#47、#48)。2026-09-15 PR #125 文件同步時，又在原本要建立 pull request 的步驟誤觸 `create_file`，於 feature branch 暫時建立不需要的 `noop` 檔案。2026-09-16 Gemini 3.6 migration 準備開 PR 時，同類 recipient-selection 錯誤再次誤觸 `create_file`，在 `fix/gemini-3-6-flash` 暫時建立 `noop_should_not_create`。
- **Root Cause:** 在多個 GitHub mutation actions 可用時，未在送出寫入前再次鎖定「操作類型 + 目標物件 + recipient」，造成 action selection 錯誤；recurrence 都發生在 resource discovery 後切換寫入 recipient 時沒有做最後 schema/recipient 對照。
- **Fix:** 初次事件立即將 #47 以 `not_planned` 關閉、#48 以 `duplicate` 關閉；2026-09-15 recurrence 立即刪除 `noop`。2026-09-16 recurrence 先讀取 accidental file 的 blob SHA `e69de29b...`，再用 `delete_file` 從同一 feature branch 刪除；未讓任何 accidental file 進入 `main`。
- **Prevention Rule:** GitHub 寫入前必須先確認 mutation 類型、目標物件與 tool recipient 完全一致（issue / branch / file / PR），並在送出前做一次 recipient/schema final check。特別是在剛做過 tool discovery 或 recipient 切換後，不得依操作慣性送出；不要用測試性寫入確認工具能力。
- **Validation:** #47、#48 均已關閉；PR #125 accidental `noop` 未進最終 diff；2026-09-16 `noop_should_not_create` 已於 branch 上立即刪除。Gemini 3.6 branch 必須在開 PR 前再次 compare `main...fix/gemini-3-6-flash`，確認最終 changed files 僅包含預期 runtime/tests/docs。
- **Status:** Recurrence cleaned before PR; final branch diff re-check pending

## L-004 — Transient browser diagnostics must be distinguished from runtime state evidence

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright runtime observation
- **Symptom:** PR #55 merge 後 main CI Run #102 的第一個 GitHub-hosted Windows Edge attempt，在 `tests/web_smoke.mjs` 等待 `playerRunning === 'true'` 時 timeout；同一份 runtime log 卻持續印出 `CUSTOM_FIGHTER_STATE ... state=RUN`。PR 上相同程式與 artifact 的 Edge gate 先前已通過，Ubuntu/Chromium gate 亦成功。
- **Root Cause:** 證據顯示 gameplay runtime 已進入 `RUN`，失敗發生在 Playwright 對短暫 dataset boolean 的觀察時窗／runner scheduling，而非 movement runtime regression。這是 observation-gate flake，不能與實際 gameplay failure 混為一談。
- **Fix / Operational Mitigation:** 只重跑失敗的 Windows Edge job，而非重跑所有成功 gate；第二次 attempt 通過，後續 GitHub Pages deployment、public reachability 與 production Edge `smoke:all` 亦全部通過，包含 Creator Skill Editor regression。
- **Prevention Rule:** 遇到 transient state timeout 時先比對 runtime 自身 diagnostics、相同 SHA 的跨瀏覽器結果與重現性。只有 runtime evidence 也失敗時才視為 gameplay regression。若 `playerRunning` 這個 observation timeout 再次出現，將 assertion 改成較穩定的 `playerState === 'RUN'` 或增加穩定 observation window；不可用廣泛 retry 掩蓋真正錯誤。
- **Validation:** Run #102 targeted Edge retry PASS；Deploy Web Demo、Verify Public Web Demo、Windows Edge Production Game 全部 PASS。
- **Status:** Verified; assertion hardening deferred unless recurrence

## L-005 — Dynamic autoload boundaries must not rely on inferred GDScript types

- **Date:** 2026-09-12; recurrence 2026-09-13
- **Area:** Godot / GDScript parser / dynamic and Variant boundaries
- **Symptom:** PR #57 CI Run #103 在 `Import project headlessly` 失敗。Godot 無法解析 `preview_selectable_main.gd` 作為 `animation_main.gd` 的 parent，並明確回報 `animation_main.gd` 的 `preview_active := session != null and session.has_active_preview()` 無法推斷型別。M6 PR #69 CI Run #135 再次出現同類型問題：新 `ai_vfx_provider_test_runner.gd` 的 `_valid_request()` 明確回傳 `Variant`，六個 caller 卻用 `var request := _valid_request(...)`，在 warning-as-error 設定下被 parser 拒絕。
- **Root Cause:** `CreatorPreviewSession`、provider adapter、helper function `-> Variant` 等 runtime/dynamic 邊界都無法提供足夠的靜態型別資訊。對這類值直接使用 `:=`，會讓 GDScript 以 Variant 推斷告警；CI 將該告警視為錯誤。
- **Fix:** Preview runtime 邊界改成明確 `Variant` / `bool` / `Dictionary` / `PackedStringArray` 型別，並以 `has_method()` + `call()` 封裝 autoload 的動態方法呼叫。M6 recurrence 則將六個 `_valid_request()` fixture caller 全部改成 `var request: Variant = ...` / `var invalid_reference: Variant = ...`，不再依賴 `:=`。
- **Prevention Rule:** 對 `get_node_or_null()`、autoload lookup、dynamic host/plugin/provider/interface，以及任何宣告 `-> Variant` 的 helper，不用 `:=` 推斷結果。跨 script / provider / fixture boundary 時，明確宣告 `Variant` 或實際 collection/scalar 型別。
- **Validation:** PR #57 修正後 CI Run #105 通過完整 GitHub gate；M6 PR #69 latest-head CI Run #138 亦通過 Godot import/boot/domain、Web export/size budget、Chromium 與 hosted Windows Edge。
- **Status:** Verified

## L-006 — Mobile browser capability detection and gameplay validation need separate deterministic gates

- **Date:** 2026-09-12
- **Area:** Playwright / Godot Web / touch capability detection
- **Symptom:** PR #62 CI Run #113 通過 Godot import、boot、domain tests、Web export、size budget 與所有既有 Chromium regressions，但新的 `smoke:mobile` 在第一個 readiness assertion timeout。第一版測試把 `isMobile` / `hasTouch` emulation、Godot readiness、touch auto-detection、HUD enablement與 automation bridge 全綁在同一個 60 秒 assertion，因此失敗時沒有足夠證據指出是哪個條件未成立。
- **Root Cause:** Hosted-browser emulation 是測試環境能力，不應成為功能路徑唯一的 enable oracle；另外 JavaScript bridge 回傳值跨 GDScript `Variant` 邊界時，直接依賴 JS boolean 表示也比明確的 0/1 contract 更難診斷。測試本身又缺少 readiness snapshot / page console diagnostics，放大了定位成本。
- **Fix:** production touch detector 改成 JS 回傳明確 `1/0` 再由 GDScript `int(result) == 1` 正規化；功能性 mobile gameplay gate 使用既有 `?mobile_controls=1` 明確啟用，另開獨立 `hasTouch` context 驗證真實 production auto-detection；測試加入 dataset snapshot、console/pageerror diagnostics，並保留 `?mobile_controls=0` 桌機隱藏驗證。
- **Prevention Rule:** 對裝置能力／媒體查詢／權限等 browser capability，不要把 emulation availability、應用啟用邏輯與核心 gameplay assertion 綁成單一 opaque wait。功能測試使用明確 override 建立 deterministic path，再用獨立 assertion 驗證 capability auto-detection，並輸出診斷 snapshot。
- **Validation:** 修正後 PR #62 CI Run #115 通過 Godot import、main boot、domain tests、Web export、size budget、Chromium `smoke:all`（含 mobile touch flow）與 GitHub-hosted Windows Microsoft Edge `smoke:all`。
- **Status:** Verified

## L-007 — An isolated hosted/production Edge readiness or observation timeout must not trigger unrelated runtime changes without reproducible evidence

- **Date:** 2026-09-12; recurrence 2026-09-18 during Grab production validation; recurrences 2026-09-19 during V2-3 WU1/WU2 production validation; recurrences 2026-09-20 during V2-3 WU4 and WU7 main validation; recurrence 2026-09-21 during V2-3 WU13 PR validation
- **Area:** GitHub Actions / Windows Edge / Playwright readiness and short observation windows
- **Symptom:** PR #63 CI Run #119 passed Godot import/boot/domain tests, Web export/size budget and Chromium, but hosted Windows Edge timed out in unchanged `character_selection_web_smoke.mjs` while waiting for Web/Godot readiness. During Grab Main CI #400 attempt #1, production Edge passed every stage through the twelve-family Creator Preview flow (including Grab) and then timed out in unchanged `smoke:creator-vfx` at `waitForRevision()`'s 5-second observation window. During V2-3 WU1 Main CI #416 attempt #1, production Edge passed `smoke:character-animation` and the WU1-specific Creator animation-map regression before unchanged `smoke:creator-preview` missed its 5-second `timeline-overlap-window`; the failure snapshot showed the timeline had already completed with transitionCount=9. During V2-3 WU2 Main CI #418, hosted Edge attempt 1 missed the unchanged 2-second Dummy `RECOVERING` observation in `web_smoke.mjs`, while logs showed the runtime had actually transitioned `DOWN -> RECOVERING -> INVULNERABLE -> READY`. Attempt 2 then passed WU2-specific character-animation, semantic Creator and semantic Preview round-trip stages before timing out in a different unchanged 5-second Creator dataset synchronization window in `creator_vfx_runtime_binding_web_smoke.mjs`. During V2-3 WU4 Main CI #428, hosted Edge attempt 1 passed the merged WU4 feature in Chromium but sampled unchanged `web_smoke.mjs` only after the fireball cooldown had already returned to zero. The targeted Edge retry then progressed through the base Web, melee, coordination, character, character-animation, Creator and Creator-skill stages before timing out at a different unchanged 5-second unsupported-composition error observation in `creator_timeline_editor_web_smoke.mjs`. During V2-3 WU7 Main CI #441, attempt 1 passed Windows Native/Chromium and then unchanged `web_smoke.mjs` observed `playerJumping=true` but missed the separate 2-second `playerJumpOffset > 5` sample; attempt 2 passed the WU7-specific `wavRuntimePlayback=true` Creator Preview stage and then timed out at a different unchanged 5-second `creator_vfx_editor_web_smoke.mjs` revision observation. During V2-3 WU13 PR CI #471, attempt 1 passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and the new Edge Creator Preview runtime-rendering assertions (`animationPngRuntimeRendering=true`, `animationPngRuntimeFrameAdvance=true`, `animationPngSemanticFallback=true`) before timing out later in the unchanged 10-second fresh-session Character Package import observation at `creator_package_vfx_web_smoke.mjs:131`. A targeted retry of only the failed hosted-Edge job on the exact same SHA then passed the fresh-session package restore/runtime-render stage and all 24 stages without code changes.
- **Evidence / Diagnosis:** In both cases the failing path was outside the feature changes and same-SHA evidence contradicted a deterministic product regression. For Main #400, PR latest-head Chromium/hosted Edge were green, production Grab coverage itself passed before the failure, Pages/public reachability and Render exact-revision readiness were already green, and the exact same deployed revision passed Creator VFX plus all 24 production Edge stages on targeted retry. The same evidence pattern held for Main #416: PR #162 latest-head CI #415 was green, Pages/public/Render exact-revision gates were green, WU1 production animation/Creator stages passed before the timeout, and exact SHA `65489e41d66bed5af2eb44b3c2ad63222b240b78` passed all 24 production Edge stages on targeted retry. For Main #418, PR #163 CI #417 had already passed hosted Edge; attempts 1 and 2 failed at two different unchanged timing windows; WU2-specific semantic animation regressions passed before the second timeout; and attempt 3 passed hosted Edge, Pages/public reachability, Render exact-revision readiness and all 24 production Edge stages on the exact same merge SHA. For Main #441, PR #170 latest-head CI #440 had already passed hosted Edge, the squash merge tree exactly matched the green PR tree, Chromium remained green, and the second hosted-Edge attempt explicitly passed the new WU7 WAV runtime playback regression before failing later in unchanged Creator VFX telemetry synchronization. For WU13 PR #177 CI #471, the failed assertion was inside a changed fresh-session package regression, so it was not assumed harmless merely because it was a timeout. Diagnosis instead relied on stronger same-SHA evidence: Chromium passed the same package flow, Edge attempt 1 had already passed the new direct Creator Preview runtime-rendering assertions, and a targeted retry of only the failed Edge job on exact head `346d2fe64855ba34b09eb3fa3f5d1bbeef906abe` passed the fresh-session package flow and the complete 24-stage suite. That pattern supports a one-off state-convergence/runner timing miss rather than a deterministic runtime defect.
- **Operational Fix:** Treat a single non-reproducible readiness/observation timeout as an isolated browser/runner timing result only after comparing changed paths and same-SHA evidence. Retry only the failed gate when appropriate; do not modify unrelated runtime code merely to satisfy one isolated timeout. If the same exact SHA then fails a second time at a different unchanged short observation window, stop blind retries and harden the tests instead: capture transient state inside the browser-side wait itself and use bounded state-driven timeouts that tolerate hosted-runner scheduling without changing product/runtime semantics.
- **Prevention Rule:** Before changing runtime code for a hosted/production browser timeout, compare changed paths, earlier steps in the same job, same-SHA cross-browser evidence and a fresh targeted run. A retry must never replace required latest-head PR validation or hide a reproducible failure. Do not add fixed sleeps to mask timing; prefer browser-side state capture plus a reasonable bounded timeout.
- **Validation:** PR #63 latest-head CI Run #126 passed the original Character Selection case. Grab Main CI #400 (`35349720100`) targeted production Edge retry on exact revision `d0b4dc9529a81466e03afe74511819efe14152d7` passed `WEB_CREATOR_VFX_EDITOR_SMOKE_PASSED`, `WEB_CREATOR_VFX_RUNTIME_BINDING_SMOKE_PASSED`, the twelve-family Grab flow, and `SMOKE_SUITE_PASSED count=24` without code changes. V2-3 WU1 Main CI #416 (`35431205627`) targeted retry on exact revision `65489e41d66bed5af2eb44b3c2ad63222b240b78` passed WU1 Creator/package animation-map coverage and `SMOKE_SUITE_PASSED count=24` with no product change. V2-3 WU2 Main CI #418 (`35444847516`) attempt 3 on exact revision `2111f3b27dfbd3fa0de8380fc72f3167ff4be461` passed hosted Edge, GitHub Pages/public reachability, `PRODUCTION_AI_BACKEND_READY ... revision=2111f3b27dfbd3fa0de8380fc72f3167ff4be461`, and production Edge `SMOKE_SUITE_PASSED count=24` without product changes between attempts. WU7 timing-stability PR #171 head `7ff377a4b759933286c8bb69d88f2da0efc051b0` passed PR CI #443 on attempt 1; after squash merge as `6d1c40878cd8988a6d27e8438c402ba706c020cd`, exact-main CI #444 (`35509107038`) passed Chromium, hosted Edge, Pages/public reachability, Render exact-revision readiness and production Edge `SMOKE_SUITE_PASSED count=24`, including both the hardened base jump observation and Creator VFX revision path. WU13 PR #177 CI #471 (`35552084482`) passed Windows Native, Godot/domain/backend/Web/Chromium on exact head `346d2fe64855ba34b09eb3fa3f5d1bbeef906abe`; hosted Edge attempt 1 timed out only at the later fresh-session import convergence wait after the direct WU13 Creator Preview rendering regression had passed, and the targeted hosted-Edge retry on the exact same head emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true animationPngSemanticFallback=true`, `WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED ... animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true`, and `SMOKE_SUITE_PASSED count=24`.
- **Status:** Verified; WU4 and WU7 recurrences were resolved by test-only timing-stability hotfixes and exact-main production validation; WU13 recurrence resolved on exact-SHA targeted retry with no product/test change; latest-head docs-sync validation remains required.

## L-008 — Hosted-browser movement helpers need tolerance for one-frame position overshoot

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright deterministic positioning
- **Symptom:** M5 Slice 2 merge 後 main CI Run #132 的第一個 hosted Windows Edge attempt，在既有 `tests/melee_web_smoke.mjs` 的 `approachDummy()` 失敗。測試目標是把 player/dummy gap 停在 45–115 px，但最後一次 `D` nudge 從可接受區間外直接跨到約 23.53 px，因而由測試自身的 lower-bound assertion 判定失敗；同 SHA 的 Godot/Web/Chromium gate 已成功。
- **Root Cause:** `nudge()` 是固定時間 held input，實際位移取決於 hosted runner 當下 frame cadence。helper 的 loop 只以 `gap > 105` 決定是否再走一步，沒有在下一個 frame step 可能跨越下限時保留 overshoot tolerance，因此位置採樣與 frame scheduling 可以讓最後一次移動越過 45 px 測試窗。這不是 Heavy Strike runtime semantics 的失敗證據。
- **Operational Fix:** 沒有修改無關 gameplay runtime；只針對失敗的 hosted Windows Edge gate重跑。第二次 attempt 的完整 `smoke:all` 通過，隨後 GitHub Pages deploy、public reachability、production Edge real-game flow 全部成功。
- **Prevention Rule:** 對以固定 held-input 時間逼近座標的 browser helper，測試成功條件要容忍單一 frame/nudge 的合理 overshoot，或改成根據剩餘距離縮短最後一步；不要把 hosted frame cadence 差異誤判成 combat regression。若相同 melee positioning failure 再次出現，應 harden helper，而不是只持續 retry。
- **Validation:** main CI Run #132 attempt 2 最終 `conclusion=success`，五個 production gates 全部通過。
- **Status:** Verified; helper hardening deferred unless recurrence

## L-009 — Verify successful GitHub mutations before repeating them

- **Date:** 2026-09-13; recurrence during M7 Slice 2; recurrence 2026-09-15
- **Area:** GitHub connector / branch and file mutation workflow
- **Symptom:** 建立 `feature/m6-ai-vfx-provider-boundary` 成功後，同一個 branch-create mutation 被重複送出，GitHub 回傳 HTTP 422 `Reference already exists`。M7 Slice 2 又曾在 feature branch 尚未建立前直接送出 `create_file`，GitHub 正確回傳 404 `Branch ... not found`。2026-09-15 follow-up 又在 `fix/p3-free-tier-project-verification` 尚未建立前誤送 PR create，GitHub 回傳 422；沒有建立 PR、沒有 repository mutation。PR #125 工作中，`docs/agent-github-sync-rule` 已成功建立後又被重送一次 create-branch，GitHub 再次回傳 422 `Reference already exists`。
- **Root Cause:** 非冪等 GitHub mutation 前後沒有把 branch/file/PR existence 當成明確前置條件與 source of truth；早期 recurrence 是成功後重送 create 或 file mutation 早於 branch creation，後續 recurrence 則是已經有成功 branch response 卻仍再次送出 create。
- **Fix:** 停止重送 branch creation；M7 recurrence 先建立 branch再提交檔案；P3 follow-up 重新載入 branch-specific action schema後依序建立 branch、commits、PR；PR #125 recurrence 收到 422 後立即沿用既有 branch，不再嘗試第二次建立。
- **Prevention Rule:** 任何 create branch / issue / PR / file 等非冪等 mutation 都要按依賴順序執行。成功回傳即視為 source of truth；建立 feature file / PR 前必須先確認 target branch 已存在。不得用重送 create 動作確認狀態。
- **Validation:** M7 Slice 2 branch 建立後所有 commit 均正確落在該 branch，PR #75 最終 merge 且 production Run #151 全綠；P3 follow-up 後續正式 commits 均由 GitHub connector 正確建立；PR #125 的 422 沒有建立第二個 branch，也沒有改變既有 branch head。
- **Status:** Verified

## L-010 — GDScript inheritance and Variant-derived inference must be explicit at new direct-load boundaries

- **Date:** 2026-09-13; recurrence 2026-09-19 during Summon WU10
- **Area:** Godot / GDScript inheritance / dynamic-host type inference / direct-load boundaries
- **Symptom:** M6 Slice 2 PR #71 CI Run #141 failed `Import project headlessly` when a newly direct-loaded Creator AI studio exposed both a child/parent preload collision and `radius := max(...)` Variant inference. Summon PR #160 CI #403/#404 later failed before domain tests because `summon_skill_controller.gd` used `var target_eligible := ...` where the expression traversed dynamic `host` members; Godot 4.7 reported `Cannot infer the type of "target_eligible"`.
- **Root Cause:** GDScript static analysis becomes stricter when a script enters a direct scene/preload/export path. Parent members must not be redeclared in children, and `:=` cannot safely infer a concrete type from expressions whose inputs originate from dynamic/Variant-typed objects even when the runtime value is conceptually boolean or numeric.
- **Fix:** For PR #71, remove the duplicate inherited constant and use typed numeric helpers/results. For Summon, a temporary GitHub-only `--check-only` diagnostic located `summon_skill_controller.gd:104`; commit `88b671bd85437ff8fa354d95c2d340ffb0302fb1` changed the declaration to `var target_eligible: bool = ...`, and cleanup commit `12930f7ac5cbe903e206358e2cca4d774ab7783c` removed the temporary diagnostic step.
- **Prevention Rule:** At any new direct-load boundary, do not redeclare inherited preload/constants and do not use `:=` for values derived through dynamic `host`, `Variant`, reflection, dictionary, or loosely typed node access when the intended type is known. Declare the concrete type explicitly; use typed numeric helpers such as `maxi`/`maxf` where applicable. Required validation remains the normal Godot import/export gate; temporary syntax diagnostics must be removed after root cause is identified.
- **Validation:** PR #71's corrected head passed its full PR/main validation chain. Summon product-fix head `12930f7ac5cbe903e206358e2cca4d774ab7783c` passed CI #406 (`35369838845`) across Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium and hosted Microsoft Edge, including `SUMMON_TESTS_PASSED`, thirteen-family Creator Preview coverage and 24-stage browser suites.
- **Status:** Verified; recurrence covered by explicit-type rule

## L-011 — Browser regressions must evolve with intentional package schema changes

- **Date:** 2026-09-13
- **Area:** M7 Character Packages / Playwright / schema evolution
- **Symptom:** M7 Slice 3 PR #77 CI Run #152 通過 Godot import/boot、所有 domain tests、Web export與 size budget，但 Chromium 在既有 `tests/creator_package_web_smoke.mjs` 失敗：Slice 2 regression 固定要求 `exported.schema_version === 1`，而 Slice 3 已刻意將新 export contract 升級為 schema v2 以容納 optional embedded VFX。
- **Root Cause:** Runtime/package implementation 的 schema evolution是預期行為，但既有 end-to-end 測試把舊版本號當成永久 invariant；domain tests 已覆蓋 schema-v1 backward compatibility，browser test 應驗證「目前 export contract」而不是凍結 legacy export 版本。
- **Fix:** 將既有 Creator package browser regression 更新為要求目前 export schema v2，並在沒有 authored VFX 的情境額外確認輸出不包含 `vfx_asset`，因此仍驗證 prototype-fallback/no-asset 行為。Schema-v1 backward compatibility繼續由 self-contained package domain tests專門驗證。
- **Prevention Rule:** 每次有意識地升級持久化/交換 schema 時，同一 change set 必須盤點所有 hard-coded version assertions。測試應分成 current-export contract 與 legacy-import compatibility 兩類，不以舊 export version assertion 阻擋合法 schema evolution。
- **Validation:** Fix 已提交至 PR #77；fresh latest-head CI Run #153 正在執行，需等待 Chromium 與 hosted Windows Edge 全綠後才標記完成。
- **Status:** Fix committed; fresh CI pending

## L-012 — Windows Godot CI should use process exit codes and preserve quoted preset arguments

- **Date:** 2026-09-13
- **Area:** GitHub Actions / Windows PowerShell / Godot export
- **Symptom:** M8 PR #79 的早期 Windows native runs 在 `Verify Godot` / export 階段失敗。直接呼叫 Godot 後讀取 `$LASTEXITCODE` 時，runner 上可看到 Godot 正常輸出版本，但 `$LASTEXITCODE` 仍為空值；改用 `Start-Process -Wait -PassThru` 後，下一輪才暴露真正錯誤：Godot 回報 `Invalid export preset name: Windows`，雖然 `export_presets.cfg` 中正確 preset 名稱是 `Windows Desktop`。
- **Root Cause:** 這個 GitHub-hosted Windows PowerShell invocation path 不應依賴 `$LASTEXITCODE` 作為 Godot process 的可靠結果來源；另外 `Start-Process -ArgumentList` 的參數序列化會讓含空白的 `Windows Desktop` 在未保留引號時被拆成兩個 command-line token。
- **Fix:** 改用 `Start-Process -Wait -PassThru` 並以 `$process.ExitCode` 判斷 Godot version/export 結果；export 則改成明確的 argument string，將 `"Windows Desktop"` 與輸出路徑保留為帶引號的單一參數。
- **Prevention Rule:** GitHub-hosted Windows runner 執行 Godot native process 時，優先用 `Start-Process -Wait -PassThru` 或等價 process API 取得真實 exit code；任何含空白的 export preset/path 必須在送入 Godot 前驗證其 command-line quoting，不可假設 PowerShell array serialization 一定保留 token 邊界。
- **Validation:** PR #79 latest-head CI Run #164 通過 `Verify Godot`、Windows x86_64 export、bounded native executable smoke、artifact upload、Godot/Web/Chromium regression，以及 GitHub-hosted Windows Microsoft Edge smoke。
- **Status:** Verified

## L-013 — Directional melee smoke positioning must guarantee facing, runtime-observed pacing and overshoot recovery

- **Date:** 2026-09-14; recurrence 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright / production regression smoke
- **Symptom:** PR #116 merge 後 main CI Run #228 的 final production Edge smoke first exposed that a bidirectional `approach()` could finish with `A`, leaving the player in numeric melee range but facing away. Main Run #260 later passed every preceding build, browser, Pages and backend-readiness gate, then the same `tests/match_restart_web_smoke.mjs` helper failed before combat with `playerX=971.21`, `dummyX=979.32`, `gap=8.11`: the fixed 45 ms final `D` nudge overshot the accepted 45–100 px corridor。
- **Root Cause:** The first fix guaranteed final facing but the helper still issued fixed-duration movement commands and immediately re-read `playerX`. Hosted Edge can publish telemetry after a keyboard event completes, so stale samples can queue another nudge and overshoot substantially. Directional melee setup therefore requires distance, facing, runtime-observed pacing and explicit overshoot recovery together.
- **Fix:** PR #123 ports the proven movement invariant already used by the buff/melee smokes into `match_restart_web_smoke.mjs`: wait for runtime-observed `playerX` change after each movement command, use distance-adaptive D holds, stage left, finish with D, and re-stage/retry after overshoot. The 45–100 px acceptance corridor, combo assertions, damage and gameplay runtime remain unchanged.
- **Prevention Rule:** Any browser helper that positions for a directional melee outcome must guarantee geometry + facing + runtime-observed command pacing + overshoot recovery. Once the same hosted-runner positioning class recurs, harden the helper rather than relying on targeted reruns.
- **Validation:** PR #123 latest-head CI Run #263 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all`; PR #123 merged as `6902f7e475c30e90689e4bdab887a8a660b19501`; main Run #264 then passed every production gate, and the real GitHub Pages Microsoft Edge suite logged `WEB_MATCH_RESTART_SMOKE_PASSED victory=true restart=true returnCreator=true`.
- **Status:** Verified on PR #123 and production main Run #264

## L-014 — Combo browser tests should validate the input buffer instead of sampling READY between hits

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright / combo regression smoke
- **Symptom:** PR #117 Run #230 在 Windows Edge 的 `tests/match_restart_web_smoke.mjs` 第二輪 combo 失敗於 `hit(28)` timeout；同一輪第一個 combo `100 → 88 → 74 → 54` 與第二輪第一擊 `54 → 42` 都已成功，顯示 facing 修正有效，但舊 helper 每一擊都等待 runner 觀察到 `playerState === READY` 後才送下一個 `J`。
- **Root Cause:** 真實 combo 設計依 recovery 期間的 input buffer 接續後續攻擊；把 browser smoke 寫成「每擊後等待短暫 READY frame，再送下一擊」會把 hosted runner 的 observation cadence 變成 combo 能否成立的額外條件。Windows Edge 排程延遲時，測試可能錯過預期輸入窗口，即使 gameplay combo buffer 本身正常。
- **Fix:** `match_restart_web_smoke.mjs` 改為與主 `web_smoke.mjs` 已證實穩定的策略一致：每個 `J` 都以跨 Godot frame 的 held input 明確送達，連續送出三次讓 runtime 自己的 input buffer 接住第 2、3 擊，再一次驗證 `lastHitStep === 3`、精確 HP 與 `dummyRecoveryState === DOWN`。同時在重新定位前等待 knockback settle。
- **Prevention Rule:** 驗證 buffered combo 時，不以 runner 是否剛好觀察到中間 READY frame 作為發送下一擊的前置條件。應送出真實可取樣的獨立輸入，最後以 combo step、傷害結果、hit flag 與 recovery state 證明完整序列成立。
- **Validation:** PR #117 latest-head CI Run #232 的 Chromium `smoke:all` 與 GitHub-hosted Windows Edge `smoke:all` 均通過，包含更新後的 `match_restart` regression。
- **Status:** Verified on PR latest-head Run #232

## L-015 — Correlated transient runtime state and flags must be observed atomically

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright runtime observation
- **Symptom:** PR #117 Run #231 的 Windows Edge 在既有 `tests/web_smoke.mjs` 回報 `Standing recovery protection must be invulnerable`。同一份 runtime log 明確依序出現 `RECOVERING → INVULNERABLE → READY`；舊測試先等待 `dummyRecoveryState === 'INVULNERABLE'`，promise 返回後才另外讀取 `dummyInvulnerable`，因此第二次 JS 讀值時 runtime 可能已合法進入 READY。
- **Root Cause:** `recoveryState` 與 `dummyInvulnerable` 描述同一個短暫 runtime phase，卻被拆成兩次非原子 browser observation。Hosted Edge runner 的 event-loop / scheduling latency 足以讓狀態在兩次讀取間前進，造成 observation race，並不代表 gameplay 沒有進入無敵期。
- **Fix:** 將兩個 assertion 合併為單一 `page.waitForFunction()` predicate，同時要求 `dummyRecoveryState === 'INVULNERABLE' && dummyInvulnerable === 'true'`；不延長 gameplay 無敵時間、不修改 recovery state machine。
- **Prevention Rule:** 若多個 dataset/diagnostic 欄位共同描述同一個短暫 phase，必須在同一次 browser evaluation 中觀察其一致性；不要先 wait 一個 transient state，再於 promise 返回後用第二次 round-trip 驗證 correlated flag。
- **Validation:** PR #117 latest-head CI Run #232：Windows Native Release PASS、Chromium `smoke:all` PASS、GitHub-hosted Windows Microsoft Edge `smoke:all` PASS。
- **Status:** Verified on PR latest-head Run #232

## L-016 — Hosted-browser coordinate helpers must wait for runtime-observed movement before issuing the next nudge

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright deterministic positioning
- **Symptom:** main CI Run #236 passed Windows Native and Chromium but hosted Windows Edge failed in `tests/web_smoke.mjs` before Skill 2. `approachDummy(170, 220)` threw `Failed to stabilize attack range: playerX=834.62 dummyX=897.12 gap=62.5`.
- **Root Cause:** The helper issued fixed-duration A/D nudges and immediately re-read `playerX`. Hosted Edge can publish telemetry after keyboard events, so stale coordinate samples can queue multiple nudges; for a 170–220 launch corridor the accumulated movement overshot all the way to 62.5. The coordinate itself did not indicate a gameplay regression.
- **Fix:** Reuse the proven `movementNudge()` invariant from the melee smoke: after each movement input, wait for runtime-observed `playerX` motion before another command; shorten hold duration near the target; if an accepted input still overshoots, re-stage left and retry. Successful positioning always finishes with `D` to preserve deterministic right-facing。
- **Prevention Rule:** Browser positioning loops must use runtime-observed coordinate progress as their command pacing, not fixed sleeps plus potentially stale reads. For narrow or remote corridors, use distance-adaptive movement and an explicit overshoot recovery strategy; do not treat one fixed-duration nudge as bounded displacement across hosted runners.
- **Validation:** PR #119 first-head CI Run #237 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` without retry.
- **Status:** Fix verified on PR first-head Run #237; merge gate requires latest-head CI.

## L-017 — Heavy Strike smoke corridors must follow authored hitbox geometry

- **Date:** 2026-09-15; recurrence observed on main Run #271; recurrence 2026-09-21 during V2-3 WU13 PR validation
- **Area:** GitHub Actions / Windows Edge / Playwright / Heavy Strike regression smoke
- **Symptom:** PR #120 Run #242 attempt 2 reproduced the deferred L-008 positioning failure in `tests/melee_web_smoke.mjs`: the final right-facing `D` approach landed at `playerX=828.99`, `dummyX=860`, `gap=31.01`, and the helper rejected it because its hard-coded lower corridor was 40 px. Main Run #271 later had one isolated hosted Edge attempt land at `playerX=847.04`, `dummyX=860`, `gap=12.96`, below the corrected geometry-derived 18 px corridor; the same SHA had already passed PR #125 Run #270 Edge and Run #271 Chromium. During WU13 PR #177 latest-head CI #475, Chromium again passed while hosted Edge overshot much farther to `playerX=877.6`, `dummyX=860`, `gap=-17.6`; this reproduced the exact deferred overshoot class and therefore triggered the previously documented helper-hardening action rather than another blind retry.
- **Root Cause:** The original 40 px lower bound was a test-authored spacing preference, not a gameplay invariant. Heavy Strike is authored with `range=72` and `hitbox_half_width=54`, so its hitbox extends from 18 px to 126 px in front of the cast origin before even accounting for the dummy's own 30 px half-width. The Run #271 12.96 px event did not reproduce on the same SHA and is consistent with an isolated hosted-runner positioning excursion rather than evidence that the 18 px authored geometry invariant or gameplay runtime is wrong.
- **Fix / Operational Mitigation:** Keep the smoke helper's lower corridor at the geometry-derived 18 px and preserve stage-left / final-`D` facing. For Run #271, the isolated failure was cleared by targeted retry. On the WU13 recurrence, implement the deferred explicit overshoot recovery: after each approach attempt, let telemetry settle, accept only the unchanged 18–105 px corridor, and otherwise re-stage safely to the dummy's left and approach again with D for up to four bounded attempts. No gameplay runtime, Heavy Strike geometry, damage, MP, cooldown or hit rules change.
- **Prevention Rule:** Coordinate preconditions in browser combat tests must remain derived from authored hitbox/hurtbox geometry, not arbitrary visual spacing. If a future latest-head or targeted retry reproduces `gap < 18` on this helper, harden `melee_web_smoke.mjs` with explicit overshoot re-stage/retry rather than lowering the 18 px invariant or changing gameplay. Continue verifying the actual gameplay outcome separately.
- **Validation:** PR #120 CI Run #246 passed with the geometry-derived 18 px lower corridor. PR #125 Run #270 passed hosted Edge on the same runtime; main Run #271 Chromium passed, the initial hosted Edge attempt alone hit `gap=12.96`, its targeted Edge retry passed without code changes, and the final GitHub Pages Microsoft Edge production `smoke:all` passed Heavy Strike with `WEB_MELEE_SKILL_SMOKE_PASSED ... hitGap=88.89 ...` plus the rest of the production suite. WU13 PR #177 CI #475 reproduced the overshoot at `gap=-17.6`. The bounded re-stage/retry helper was then validated by latest-head CI #478 (`35554693089`): Chromium and hosted Edge both passed, and Edge emitted `WEB_MELEE_SKILL_SMOKE_PASSED ... hitGap=87.99 ... finalHp=76 hitCount=1` while the unchanged 18–105 px authored corridor, 24 damage, 18 MP spend, cooldown and single-hit assertions remained intact.
- **Status:** Verified on WU13 PR #177 latest-head CI #478; explicit bounded re-stage/retry hardening passed Chromium and hosted Edge without gameplay changes

## L-018 — Directional buff damage smoke must preserve facing while stabilizing melee range

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright / buff regression smoke
- **Symptom:** PR #120 CI Run #245 passed Windows Native and Chromium, and progressed beyond the corrected Heavy Strike smoke, but hosted Windows Edge failed at `tests/buff_web_smoke.mjs:263` while waiting for the second Battle Focus activation's buffed basic attack to reduce dummy HP from 100 to 82. The runtime log showed MP had dropped to 50 and `combo=1 / state=ATTACK_1`, proving both the buff recast and `J` input were accepted, while dummy HP remained 100.
- **Root Cause:** `buff_web_smoke.mjs` used a bidirectional `approachDummy()` that could finish its final range correction with `A`. The player could therefore be numerically inside melee range but face left while the dummy remained on the right. The attack animation then executed successfully with its directional hitbox projected away from the target. The same helper also paced movement with fixed sleeps, retaining the stale-coordinate/overshoot risk documented in L-016.
- **Fix:** Replace the buff smoke positioning helper with the proven runtime-observed movement invariant: wait for `playerX` to change after each movement command, stage the player safely to the dummy's left, approach only with `D`, use distance-adaptive held durations, and re-stage/retry after overshoot. All substantive Battle Focus assertions remain unchanged: 1.45x movement, 1.5x attack, 25 MP per accepted cast, cooldown/recast rejection, exact 18 buffed damage, expiration restoration, and exact 12 baseline damage afterward. No gameplay runtime or skill parameters changed.
- **Prevention Rule:** Every browser smoke that validates a directional melee outcome must treat facing as part of its positioning contract. Shared helpers should combine runtime-observed movement pacing, stage-left placement, one-way final approach toward the target, and explicit overshoot recovery rather than independent bidirectional fixed-sleep loops.
- **Validation:** Commit `a971e6b78ef50a8f9b6e5a26de9d29a7818a5b3f` on PR #120; CI Run #246 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` without retry.
- **Status:** Verified on PR Run #246; final latest-head merge gate pending documentation sync.

## L-019 — Coordinator-gated browser tests must distinguish pre-claim blocking from rejected claims

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Playwright / skill coordinator runtime contract
- **Symptom:** PR #120 Run #248 failed `tests/skill_coordination_web_smoke.mjs` at the second `waitForFunction()` after pressing `O`. The smoke expected `skill_3` to increment coordinator rejection telemetry while `skill_1` owned the coordinator, but that counter never changed.
- **Root Cause:** `coordinated_area_skill_controller.gd::_can_start_cast()` checks `can_claim(skill_3)` before `_try_cast()` reaches `try_claim(skill_3)`. When another skill owns the coordinator, Area is therefore blocked at the pre-claim gate；no rejected claim occurs and no rejection counter should increment. The test encoded the wrong layer of the runtime contract.
- **Fix:** Keep `try_claim()` rejection semantics covered by the coordinator domain tests, and change the browser smoke to validate the actual integration contract: expose durable `areaSkillInputLatched` telemetry, prove the `O` input was sampled while `skill_1` still owned the coordinator, and assert Area did not enter a cast, MP was not spent, and claim count did not change. No gameplay behavior, damage, cooldown, MP cost, or control mapping changed.
- **Prevention Rule:** Browser integration tests must assert the behavior of the public runtime path they actually drive. Do not expect downstream telemetry from code that an earlier guard intentionally prevents from executing. Use domain tests for lower-level rejection semantics and durable input/phase/resource telemetry for integration gating.
- **Validation:** PR #120 latest-head CI Run #250 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` on head `610037d8207fe8b11bf924c5b5cfb641b212d4c1` before this documentation-only lesson commit.
- **Status:** Fix verified on Run #250; final latest-head merge gate pending this documentation commit.

## L-020 — Provider name alone does not prove a zero-cost AI path

- **Date:** 2026-09-15
- **Area:** Production AI / Gemini / cost policy
- **Symptom:** P3 supported OpenAI image generation and `gemini-3.1-flash-image`; selecting Gemini could still make paid image-generation API calls even though the desired production policy is no paid AI.
- **Root Cause:** The provider boundary treated vendor/model selection as a functionality concern but did not encode model-level billing eligibility. A Gemini-branded image model was assumed to satisfy a free-Gemini requirement without checking Google's current model pricing.
- **Fix:** Remove the OpenAI production adapter, allow only `gemini`, allow-list free-tier text/multimodal Gemini models, use free-tier Gemini for prompt/reference understanding plus strict structured JSON, and render final PNG VFX deterministically with Sharp. Health/readiness reports `billing_mode=free-tier-only`, requires `GEMINI_FREE_TIER_ONLY=true`, and fails closed for unsupported models/providers. The production key must come from an AI Studio Free Tier project with paid billing disabled.
- **Prevention Rule:** Before adding or changing any production AI model, verify the exact model's current official pricing and API availability. A vendor name is not a cost guarantee. Paid fallback is prohibited unless the user explicitly reverses the cost policy. A free-eligible model alone is insufficient: production configuration must also assert and operationally verify a Free Tier project/key.
- **Validation:** PR #121 latest-head CI Run #256 passed all required PR gates and merged as `9fe7f3d3f72e779fa050d1b2cff734dc999f1510`; later real-provider acceptance exposed a separate model-lifecycle availability issue recorded in L-024.
- **Status:** Verified cost/provider boundary; model lifecycle is separately guarded by L-024

## L-021 — Retry read failures, but verify state before retrying mutations

- **Date:** 2026-09-15
- **Area:** Render connector / deployment operations
- **Symptom:** While switching Render to Gemini, the same environment-variable update was sent repeatedly and each successful write triggered another deploy; earlier deploys were then canceled by newer identical deploys.
- **Root Cause:** The generic "retry transient connector failures" rule was applied to a mutating operation without first checking whether the previous mutation had already succeeded.
- **Fix:** Stop repeated writes, inspect Render deploy state, retain the latest valid deploy, and add a separate mutation-retry rule: uncertain writes require a read/status check before any retry.
- **Prevention Rule:** Retry read-only failures freely within reason；for writes/deploy triggers, verify remote state first and never use the mutation itself as the confirmation mechanism.
- **Validation:** Render deploy history showed the superseded identical deploys canceled automatically and the latest valid deploy reached `live`; project rules now distinguish read retries from mutation retries.
- **Status:** Verified

## L-022 — A free-tier policy flag is not proof of project billing state

- **Date:** 2026-09-15
- **Area:** Production AI / Gemini billing guard / readiness contract
- **Symptom:** PR #121 的 `/healthz` 將 `free_tier_confirmed=true` 直接等同於 `GEMINI_FREE_TIER_ONLY=true`。這只能證明應用程式政策旗標被打開，不能證明 Google AI Studio / Cloud project 真的沒有啟用 paid billing。
- **Root Cause:** Application policy assertion 與 external account/project billing verification 被合併成同一欄位，命名又暗示已完成外部確認。
- **Fix:** Follow-up PR #122 新增獨立 `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` gate；`configured=true` 必須同時具備 API key、allow-listed free-tier model、`GEMINI_FREE_TIER_ONLY=true` 與 project verification。Readiness 改為 `free_tier_policy_asserted`、`free_tier_project_verified`、`verification_mode=operator-asserted`，不再把 policy 稱為 confirmation。
- **Prevention Rule:** 對 billing、permissions、external account state 等無法由應用本身證明的條件，必須將「政策」與「外部驗證/attestation」分開建模；名稱不得暗示比實際證據更強的保證。
- **Validation:** PR #122 latest-head CI Run #259 passed Windows Native, Godot/backend/Web/Chromium and hosted Microsoft Edge, then merged as `e1ae9933fa4943af80ff7b7ab4a0ff4ae97d78cb`. Render auto-deployed that exact revision；main Run #260 readiness passed in `PRODUCTION_AI_BACKEND_SAFE_DISABLED` mode with `project_verified=false`.
- **Status:** Verified safety/readiness boundary; external project verification was later supplied before production activation

## L-023 — Repository execution policy must be read before choosing a local/remote tool path

- **Date:** 2026-09-15
- **Area:** Agent execution workflow / GitHub-only policy
- **Symptom:** 在 follow-up 開始時，尚未完整核對 `Agent.md` 的 GitHub-only hard rule，就使用 Remote Desktop Commander 做了 branch/local-file inspection 與未提交修改；這與 custom-fighter 明確禁止本機/遠端桌面作為專案 Git/修改/驗證路徑的規則衝突。
- **Root Cause:** 先依聊天中的舊工作習慣選工具，後讀完整 repository policy，順序錯誤。
- **Fix:** 一發現規則衝突就停止 Remote Desktop Commander 專案操作，以一次 reset 清除該工具造成的所有未提交變更；後續 branch、blob、commit、PR 與 validation 全部改用 GitHub connector / GitHub Actions。沒有把任何 Remote Desktop 產生的 code commit 到 GitHub。
- **Prevention Rule:** 對任何 repo，第一個 mutation 前必須先從 repository source of truth 讀完整 Agent/AGENTS policy，再決定允許的工具與 validation path；聊天記憶不能覆蓋 repository hard rule。
- **Validation:** GitHub branch `fix/p3-free-tier-project-verification` 從 merge SHA `9fe7f3d3f72e779fa050d1b2cff734dc999f1510` 重新建立；正式 follow-up commits 均透過 GitHub Git data APIs 建立，PR #122 latest-head CI Run #259 passed and the PR merged as `e1ae9933fa4943af80ff7b7ab4a0ff4ae97d78cb`.
- **Status:** Verified process correction

## L-024 — Free-tier pricing eligibility and model API availability are separate production gates

- **Date:** 2026-09-16
- **Area:** Production AI / Gemini model lifecycle / real-provider acceptance
- **Symptom:** Render readiness became fully READY with a valid server-side key, `provider=gemini`, Free Tier-only policy, operator-verified billing state, and exact revision alignment. However, manual Production Free Gemini E2E Runs #1 and #2 failed immediately on the first real text-generation call: Google returned HTTP 500 stating `models/gemini-2.5-flash` is no longer available to new users and directed new integrations to `models/gemini-3.6-flash`.
- **Root Cause:** The previous allow-list correctly encoded Free Tier pricing eligibility but treated that eligibility as if it also guaranteed continuing API availability. External model lifecycle/availability can change independently of pricing and application readiness metadata.
- **Fix:** Recheck current Google official model and pricing documentation, migrate the production default and allow-list to the currently available Free Tier `gemini-3.6-flash`, explicitly reject retired `gemini-2.5-flash`, and align provider factory tests, remote readiness browser fixtures, Agent policy, status, and production acceptance documentation. Keep deterministic Sharp rendering and all no-paid-provider guards unchanged.
- **Prevention Rule:** Before production activation, model migration, or final real-provider acceptance, verify **both** (1) current official Free Tier pricing eligibility and (2) current API/model availability for the intended account/user class. Readiness/configured status is necessary but cannot replace an actual provider call. Preserve the manual real-provider E2E as the authoritative lifecycle gate.
- **Validation:** Source/test/docs migration is committed on `fix/gemini-3-6-flash`; GitHub PR CI, merge, Render `GEMINI_MODEL=gemini-3.6-flash`, exact-revision readiness, and successful real text + reference-image E2E are still required before this lesson becomes Verified.
- **Status:** Fix committed; production verification pending

## L-025 — DOM dataset telemetry must carry structured values as JSON text, not JavaScript objects

- **Date:** 2026-09-17
- **Area:** Godot Web / JavaScript bridge / DOM dataset / Playwright regression
- **Symptom:** PR #143 passed Godot import/boot/domain/backend and reached the Creator → Training browser flow, but Chromium failed at the spatial-payload assertion. The diagnostic snapshot showed the authored timeline was running correctly with animation/VFX/audio/hitbox/hurtbox transitions active, while `creatorPreviewTimelineHitboxes` and `creatorPreviewTimelineHurtboxes` were both `"[object Object]"`; `JSON.parse()` therefore failed.
- **Root Cause:** `_set_web_state()` generated a JavaScript array/object expression from the GDScript structured payload and assigned that expression directly to `document.documentElement.dataset.*`. DOM `dataset` values are strings, so assigning an array/object triggers JavaScript string coercion instead of preserving JSON, producing `[object Object]` for the single-element payload.
- **Fix:** Serialize each active spatial payload to JSON text in GDScript first, then JSON-quote that text when generating the JavaScript assignment. The DOM dataset therefore receives a real JSON string which the browser regression can safely `JSON.parse()`.
- **Prevention Rule:** Any structured value crossing into a DOM `dataset` field must cross the boundary as JSON **text**. Never assign a JavaScript object/array directly to `dataset`; serialize the structure, then quote/escape the resulting string for the generated JavaScript source. Keep scalar dataset fields scalar.
- **Validation:** Commit `eae4c7847e5c250dd1f6e57dfdcbe47e7b517ddc` passed the targeted Creator Preview Diagnostic Run #4 (`35138056651`), including authored five-event timeline setup, Training cast, animation/VFX/audio telemetry, hitbox/hurtbox spatial payload parsing, legacy projectile hit, timeline completion, and return-to-Creator preservation.
- **Status:** Verified by targeted directly affected flow; final PR regression remains the work-unit merge gate

## L-026 — Typed collection conditional branches must preserve the declared GDScript type

- **Date:** 2026-09-17
- **Area:** GDScript / typed arrays / Web telemetry / Creator Preview boundary
- **Symptom:** After the L-025 serialization fix, the directly affected Creator → Training → Creator diagnostic passed, but full Chromium regression repeatedly failed in unchanged `tests/character_animation_web_smoke.mjs` while waiting for `playerAnimationMapLoaded === 'true'`. A targeted character-animation run reproduced the failure. The captured dataset showed `godotReady=true` and the selected character was present, while all animation-map telemetry fields were empty.
- **Root Cause:** `_set_web_state()` declared three `Array[Dictionary]` variables with a ternary of `fireball_cast_state.active_timeline_events(...) if preview_active else []`. The Creator Preview path used the typed runtime result and succeeded；ordinary Training took the false branch, where the bare `[]` was an untyped Array. That value failed the typed collection assignment before `JavaScriptBridge.eval()` executed, so the parent Web state existed but the animation/timeline telemetry block was never written.
- **Fix:** Initialize `timeline_vfx_events`, `timeline_hitboxes`, and `timeline_hurtboxes` as typed empty `Array[Dictionary]` values first, then assign the runtime results only inside `if preview_active`. No gameplay state, animation map, damage, controls, or authored timeline semantics changed.
- **Prevention Rule:** When a GDScript variable is declared as `Array[T]` or another typed collection, every conditional initialization path must remain type-compatible. Avoid `Array[T] = typed_value if condition else []` at runtime/dynamic boundaries；prefer a typed empty collection followed by explicit conditional assignment.
- **Validation:** Fix commit `2d27374103327ed44c6d54df1b2f531c8084c1bf` passed targeted PR Chromium Smoke Diagnostic Run #5 (`35164358167`) for `smoke:character-animation`. Full PR CI #331 (`35164358190`) then passed Windows Native Release, Godot import/boot/domain tests, backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`. Temporary diagnostic workflow and animation-smoke instrumentation were removed in cleanup commit `277d3537bb413f260a85d0e3b41dc6c417d366e1`.
- **Status:** Verified on targeted and full PR regression; final documentation-only latest-head merge gate pending

## L-027 — Inherited Creator constants can collide after a base-class refactor

- **Date:** 2026-09-17
- **Area:** Godot / GDScript inheritance / Creator hierarchy
- **Symptom:** PR #145 CI #337 failed during `Import project headlessly` with `The member "SkillDefinition" already exists in parent class res://game/creator/creator_studio.gd`, and Windows export failed on the same parse defect.
- **Root Cause:** V2-2 initially added a `SkillDefinition` preload constant to the base `creator_studio.gd`, while the derived `timeline_creator_studio.gd` already declared the same member name. GDScript inherits parent members and forbids redeclaring that name in the child. This is the same underlying class of failure as L-010, exposed in a different Creator inheritance chain.
- **Fix:** Remove the new redundant base preload and use the existing globally registered `SkillDefinition` class name, leaving the child declaration and all skill-family behavior unchanged.
- **Prevention Rule:** Before adding a constant/member to any GDScript base class, inspect known descendants for the same name. Treat base-class member additions as inheritance-surface changes, and rely on the full Godot import gate to catch collisions before merge.
- **Validation:** Fix commit `31973ef2f1d51ad66a2f5f4b7a7dee748dad4a7f`; PR #145 latest-head CI #339 (`35186404303`) passed Godot import/boot/domain/backend, Web export/size budget, Chromium, Windows Native Release, and hosted Microsoft Edge.
- **Status:** Verified on PR #145 CI #339

## L-028 — Short-lived cooldown evidence must be captured in the same browser evaluation that proves it

- **Date:** 2026-09-17
- **Area:** GitHub Actions / Windows Edge / Playwright / melee regression observation
- **Symptom:** After the V2-2 parse fix, a hosted Edge run exposed a Heavy Strike smoke failure where the test first waited for `meleeSkillCooldown > 0` and then performed a separate dataset read; runner scheduling could allow the short-lived observed value to advance before the second round-trip, producing a false negative even though the cast/cooldown runtime was correct.
- **Root Cause:** The smoke split proof and value capture for one transient runtime condition across two browser evaluations. This is a recurrence of the observation race described in L-015.
- **Fix:** `waitForPositiveCooldown()` and the READY+cooldown gate now return the positive cooldown value directly from the successful `waitForFunction()` handle, so the assertion and captured evidence are atomic. The cooldown rejection check also explicitly observes the post-recovery READY window while cooldown remains positive.
- **Prevention Rule:** When a test depends on a transient numeric/state value, return/capture that value from the same predicate evaluation that proves the condition. Do not prove a short-lived condition and then make a second browser round-trip to re-read it.
- **Validation:** Fix commit `f90d38701ff1f7c58a9bf2b4fd6dd2483a92d797`; PR #145 latest-head CI #339 (`35186404303`) passed the full Chromium suite and GitHub-hosted Microsoft Edge `smoke:all`, in addition to all non-browser gates.
- **Status:** Verified on PR #145 CI #339

## L-029 — Family-specific skill fields must stay synchronized across Creator, package schema, normalization and canonical comparisons

- **Date:** 2026-09-18
- **Area:** V2 skill families / Creator package schema / deterministic serialization
- **Symptom:** PR #148 reached browser validation with the eight-family Creator Preview flow passing, but both Creator package and Creator package VFX smoke timed out. The first failure occurred before export telemetry advanced; after adding `trap_duration` to the package schema, export advanced but package re-import still failed.
- **Root Cause:** Trap added a new family-specific `SkillDraft` / `SkillDefinition` field, but the strict Character Package allowlist and normalizer were not updated as one contract. The first correction accepted and serialized `trap_duration` for every skill, which then changed the canonical shape of existing non-Trap skills and caused exact production-definition comparisons during import to fail.
- **Fix:** Allow `trap_duration` at the validated package boundary, preserve it only when the serialized skill type is `trap`, and keep every non-Trap package skill in its historical canonical shape. Add direct domain regression proving Trap duration round-trip and absence of the field on non-Trap serialized skills.
- **Prevention Rule:** Adding any family-specific skill field requires one audit of every strict shape boundary: `SkillDefinition`, `SkillDraft`, Creator validation/serialization, package allowlists, package normalization, self-contained package wrappers, exact canonical comparisons, browser export/import smoke and domain round-trip tests. Family-specific data must be serialized conditionally unless the canonical schema explicitly defines the field for all families.
- **Validation:** Targeted PR148 Browser Diagnostic #3 (`35254414363`) passed Creator Preview family, Creator package, Creator package VFX and mobile smoke after commits `8e14face377ffa7421f54e782e22f723a5ed3ea7` and `f31a54bb735eeeb166fa9709768d120e65095066`. Final PR head `4d969054fa06571f2d3f975f89aa65edb0a6c5c5` passed PR CI #361 (`35284784577`), including the direct Trap package round-trip regression, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`. PR #148 then squash-merged as `f1631eaa3f2828765ab898e7f5ebe55637671422`; Main CI #362 (`35289237781`) attempt #3 passed the complete production chain on that exact merge revision.
- **Status:** Verified and production-validated

## L-030 — Windows npm `.cmd` wrappers should be launched through the Windows command processor

- **Date:** 2026-09-18
- **Area:** Node.js / GitHub Actions / Windows Microsoft Edge / smoke orchestration
- **Symptom:** PR #148 CI #359 passed Windows Native and the complete Linux Godot/backend/Web/Chromium chain, but the hosted Windows Edge job failed immediately at the first smoke stage with `spawnSync npm.cmd EINVAL`. No game/browser assertion had executed.
- **Root Cause:** The cross-platform smoke orchestrator directly passed `npm.cmd` to Node 24 `spawnSync()` on Windows. A `.cmd` shim is a Windows command-processor script rather than a native executable and is not a stable direct-spawn boundary across Node/Windows runner versions.
- **Fix:** On Windows, execute the static allow-listed smoke command through `process.env.ComSpec || process.env.COMSPEC || 'cmd.exe'` using `/d /s /c "npm run <script>"`; retain direct `spawnSync('npm', ...)` on non-Windows platforms. The temporary PR148 diagnostic workflow was removed once targeted diagnosis was complete.
- **Prevention Rule:** Cross-platform Node orchestration must not assume Windows `.cmd` wrappers behave like native executables. Use the Windows command processor (or another explicitly supported shell boundary) for trusted static `.cmd` commands, while keeping user-controlled text out of the command string.
- **Validation:** PR CI #360 (`35283860574`) passed Windows Native, Godot/backend/Web/Chromium and the complete GitHub-hosted Microsoft Edge `smoke:all` job on commit `8e4a2fabd08da51e413f90f5607b00c9c89354d1`; the Edge job progressed through all smoke scripts instead of failing at process launch. Final PR CI #361 (`35284784577`) repeated the hosted Edge pass on `4d969054fa06571f2d3f975f89aa65edb0a6c5c5`. After squash merge as `f1631eaa3f2828765ab898e7f5ebe55637671422`, Main CI #362 (`35289237781`) attempt #3 passed hosted Edge and the production Microsoft Edge full smoke against GitHub Pages, confirming the Windows process-launch correction in the deployed production chain.
- **Status:** Verified on PR, hosted Microsoft Edge, and production Microsoft Edge



## L-031 — Package import must refresh derived Creator editor telemetry after replacing a full draft

- **Date:** 2026-09-18
- **Area:** Creator inheritance / package import / timeline editor telemetry
- **Symptom:** PR #156 CI #383 passed Godot import/boot, WU8 composition domain/runtime/package tests, Windows export, Creator Timeline smoke, Creator Preview smoke and eleven-family Preview smoke, but Chromium `smoke:creator-package` timed out after a valid package re-import while waiting for the restored five-event timeline to appear in Creator telemetry.
- **Root Cause:** The package import path correctly restored the complete `SkillDraft`, including its validated `timeline.events`, in ancestor `package_creator_studio.gd`. However, the derived `timeline_creator_studio.gd` retained UI/Web state from the previously cleared draft because replacing the whole draft did not invoke the Timeline editor's `_refresh_timeline_editor()`. The data round-trip was correct; derived editor telemetry was stale.
- **Fix:** Override `_import_package_json(...)` at the Timeline Creator layer, delegate to `super`, and refresh the Timeline editor only after a successful import. The existing Creator Package browser smoke now serves as the regression by requiring `creatorTimelineCount=5`, valid timeline state and Preview readiness after import.
- **Prevention Rule:** Whenever an ancestor Creator operation replaces a complete draft/object rather than mutating it through the derived editor's normal controls, every derived editor that caches UI/Web telemetry for that draft must refresh after successful replacement. Treat full-draft import/restore/reset as a cross-layer state synchronization boundary.
- **Validation:** Initial refresh hook commit `80009e350cfa76f29c424b25e918a5b16a6fcb4a` addressed the stale derived state. An overlapping second hook then produced a duplicate-function parse error caught by CI #386 (`35332142038`); reconciliation commit `ad146a380de165002d33212014f25c51cb4ef446` consolidated the hook into one override. PR #156 CI #387 (`35332342095`) passed Godot import/boot/domain/backend, Windows Native, Web export/size budget, Chromium and hosted Microsoft Edge; both browsers passed Creator Package with `timelineRoundTrip=true compositionExpanded=true`.
- **Status:** Verified on PR #156 CI #387

## L-032 — Data-driven Creator family smoke must derive geometry from authored runtime values

- **Date:** 2026-09-18
- **Area:** V2-2 Grab / Creator Preview / Playwright
- **Symptom:** PR #158 CI #395 passed Windows Native, Godot import/boot/domain/backend and Web export, but Chromium timed out at `grab-capture`. The failure snapshot already showed a successful Grab: one activation/capture, 12 damage, and target/dummy destination `835.12`.
- **Root Cause:** The browser regression hard-coded the expected Grab anchor as `beforePlayerX + 56`, copied from a lower-level fixture, while the Creator-authored draft exposed the runtime Grab anchor offset through `creatorSkillDraftKnockback=60`. The runtime correctly used the authored value; the browser assertion tested a stale magic number.
- **Fix:** Derive the expected Grab destination from the Creator-authored `creatorSkillDraftKnockback` telemetry before casting, then compare runtime Grab destination and Dummy position against that authored value.
- **Prevention Rule:** End-to-end tests for data-driven skill geometry, timing, cost, damage, offsets, or ranges must either explicitly author the tested value in that flow or derive the expectation from validated authored/runtime telemetry. Do not copy a numeric constant from a domain fixture into a Creator browser assertion.
- **Validation:** Commit `344046c7221dc5de44c558c61f861b241eff90fd` first cleared the Grab expectation defect in CI #396 Chromium. After L-033 hardening, PR #158 head `c3b5da271fe70c58bcafaa82be0ede16b3d47888` passed CI #398 (`35346916303`) on both Chromium and GitHub-hosted Microsoft Edge; each browser emitted the twelve-family Creator Preview PASS and `SMOKE_SUITE_PASSED count=24`.
- **Status:** Verified cross-browser on PR #158 CI #398

## L-033 — Creator family proximity setup must use runtime-observed movement and overshoot recovery

- **Date:** 2026-09-18
- **Area:** Creator Preview family smoke / GitHub-hosted Microsoft Edge / deterministic positioning
- **Symptom:** PR #158 CI #396 passed Windows Native, Godot/domain/backend, Web export and Chromium `smoke:all`, then hosted Microsoft Edge failed at `aura-approach` with `dummyX=860.00`, `playerX=880.60`, `gap=-20.60`. The player had crossed to the Dummy's right before the old continuous-D wait observed its `gap <= 85` predicate.
- **Root Cause:** The family smoke held `D` continuously and relied on a browser observation to release it. Hosted Edge can publish coordinate telemetry after substantial runtime movement, so a logically successful wait can arrive only after the player has already overshot the target. This is the same stale-coordinate command-pacing class documented in L-016, but the newer family smoke had not adopted that invariant.
- **Fix:** Replace continuous movement with runtime-observed bounded nudges, stage safely to the Dummy's left, make the final approach only with `D`, use distance-adaptive hold durations, and re-stage/retry after an overshoot. The accepted proximity corridor remains bounded and gameplay code is unchanged.
- **Prevention Rule:** Every browser test that positions a player relative to a target must pace each movement command from runtime-observed coordinate progress and include overshoot recovery. Never use a long held direction whose release depends on delayed hosted-browser telemetry.
- **Validation:** Fix commit `d4cca251fe36cae0672ad6f8b11d35aef8d31917`; PR #158 head `c3b5da271fe70c58bcafaa82be0ede16b3d47888` passed CI #398 (`35346916303`) on Windows Native, Godot/domain/backend, Web/Chromium and GitHub-hosted Microsoft Edge. Both browsers completed all 24 smoke stages, including the hardened Aura/Counter/Grab proximity setup.
- **Status:** Verified on PR #158 CI #398


## L-034 — Round-trip tests must distinguish persisted draft data from transient editor selection

- **Date:** 2026-09-20
- **Area:** V2-3 audio bindings / Creator Preview / Playwright
- **Symptom:** PR #166 CI #422 passed Godot import/boot/domain/backend, Windows Native, Web export/size budget and the new Creator audio-authoring smoke, then Chromium `smoke:creator-preview` timed out only at the return-to-Creator assertion. The failure snapshot showed the authored runtime binding was active (`playerAudioCueSkillCast=preview_cast_custom`) and the Creator draft was valid after return, but the visible audio binding selector had reset to its default `ready → character_ready` view.
- **Root Cause:** The browser regression treated the currently selected Audio Binding row as the persistence source of truth. The complete `CharacterAudioDraft` is persisted in session data, while the selector index is transient editor view state and intentionally initializes to the first fixed binding when a new Creator scene is built.
- **Fix:** Verify round-trip persistence from the serialized `creatorAudioDraftJson` and assert its `cues.skill_cast` value instead of requiring a particular selector row to remain selected. Runtime/Creator product behavior is unchanged.
- **Prevention Rule:** For Creator round-trip/import tests, assert persisted model state from canonical serialized draft/package telemetry. Assert selector/tab/focus state only when preserving that view state is itself a product requirement.
- **Validation:** Fix commits `2443f60e39e2f0aa7cdccae6099cf01071a13d86` and `22c41b662a5753d59f47a3cd44bd20e63cfc975c`; PR #166 CI #425 (`35457465896`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- **Status:** Verified cross-browser on PR #166 CI #425


## L-035 — One runtime event must have one authoritative audio-trigger consumption path

- **Date:** 2026-09-20
- **Area:** V2-3 Creator Preview audio / GDScript inheritance / runtime event consumption
- **Symptom:** During WU10 branch reconciliation, `hit_received` temporarily had two independent playback paths at once: an `animation_main.gd::receive_player_hit(...)` override that delegated to the parent damage boundary and played after real dealt damage, plus a frame-polled consumer that observed `player_incoming_hit_count` and `last_player_damage_dealt`. A single successful incoming hit could therefore request the same WAV twice.
- **Root Cause:** Two individually reasonable integration strategies were composed without first choosing one event owner. The inherited override already sits on the authoritative synchronous damage boundary, so adding a second polling consumer duplicated event consumption rather than adding coverage.
- **Fix:** Keep only the `receive_player_hit(...)` override. It delegates to `super` first and plays `hit_received` only when the authoritative returned damage is greater than zero. Remove the observed-player-hit counter, process-loop call, reset state, and polling helper.
- **Prevention Rule:** For one semantic runtime event, choose exactly one authoritative trigger boundary. Prefer the synchronous source-of-truth method when it exposes the accepted/result value; use frame polling only when no direct event boundary exists. Before combining parallel branch work, search for all producers/consumers of the semantic to prevent duplicate side effects.
- **Validation:** PR #174 head `73e46478dbd9e4f7940c7908ac4cc1b621c6c133` passed CI #456 (`35519908707`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`; both browsers emitted `hitReceivedWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`. Latest docs-sync head `e246614d55aa68a59120a26af31e1b202d1a4474` then passed CI #457 (`35520826213`) across the same required PR gates. Production validation remains pending until the approved merge reaches exact-main CI.
- **Status:** Verified cross-browser on PR #174; production validation pending


## L-036 — Long browser regressions require unique-context edit anchors

- **Date:** 2026-09-21
- **Area:** GitHub-only source editing / Playwright regression maintenance
- **Symptom:** WU11 PR CI #460 passed Windows Native, Godot/domain/backend, Web export/size budget, Creator Studio Animation-PNG coverage and Creator Preview Animation-PNG round-trip, then timed out in `creator_package_web_smoke.mjs` before export. The package test incorrectly required the freshly imported animation PNG to already be cleared.
- **Root Cause:** A source-edit replacement targeted a short assertion sequence that appeared both before export and after successful package import. The first occurrence was replaced, so the post-import isolation assertion was inserted into the pre-export state.
- **Fix:** Restore the pre-export assertion to require the authored Animation PNG to remain valid, and insert the clear-after-successful-import assertion using the unique `creatorPackageImportStatus === 'valid'` plus import-count context.
- **Prevention Rule:** When editing a long E2E file through structured remote source replacement, never mutate a repeated short anchor when semantic placement matters. Use a unique stage/function/context block, inspect all matching occurrences first, and make occurrence-specific assertions explicit.
- **Validation:** Fix commit `512381ef6e46ff7bc54c30c41f1e37cba6a20baa`; PR #175 CI #462 (`35526663871`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`. Both browsers passed the corrected package isolation flow and `SMOKE_SUITE_PASSED count=24`.
- **Status:** Verified cross-browser on PR #175

## L-037 — Repeated hosted-Edge misses at different short observation windows require test hardening, not more blind retries

- **Date:** 2026-09-21
- **Area:** GitHub Actions / Windows Edge / Playwright / regression observation windows
- **Symptom:** V2-4 architecture PR #180 latest-head CI #494 changed only documentation relative to the previously green head, while Windows Native, Godot/domain/backend, Web export/size budget and Chromium `smoke:all` passed. Hosted Edge attempt 1 timed out in unchanged `buff_web_smoke.mjs:224` while waiting 2.5 seconds for the cast coordinator to release while the timed buff remained active. A targeted same-SHA Edge retry passed that Buff stage but later timed out in unchanged `creator_package_vfx_web_smoke.mjs:248`, where the test held `U` and allowed only 3 seconds to observe the authored MP spend.
- **Root Cause:** The two failures occurred at different unchanged short browser-observation windows on the same product tree. The Buff assertion combined transient telemetry from separate runtime producers, making hosted-runner scheduling part of the proof. The packaged-VFX regression used a much shorter frame-polled input acknowledgement window than the already-stable Creator AI-VFX regression for the same `U`/MP/runtime path. Repeating retries would mask test nondeterminism instead of correcting it.
- **Fix:** `buff_web_smoke.mjs` now observes correlated `buffSkillPhase=READY` + `buffActive=true` atomically from the Buff controller, then separately waits for the coordinator's durable released state. `creator_package_vfx_web_smoke.mjs` keeps `U` held until runtime MP acknowledgement, releases it in `finally`, and uses the established 10-second state-driven windows for MP/VFX/damage acknowledgement. Product/runtime behavior, skill timing, MP cost, damage and controls are unchanged.
- **Prevention Rule:** After one isolated hosted-browser timeout, a targeted retry may distinguish flake from regression. If the same SHA then fails at a different unchanged short observation window, stop blind retries. Harden the harness by observing correlated transient state atomically from one producer, waiting on durable runtime acknowledgements, keeping frame-polled inputs held until acknowledgement, and using bounded windows consistent with proven equivalent regressions.
- **Validation:** PR #180 latest-head CI #497 (`35580807539`) passed Windows Native Release, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` on head `f90a8928fe58e4d5bb35f45279b345d48a890f72`. The previously failing Buff cast-release observation and packaged-VFX `U`/MP acknowledgement path both completed without product/runtime changes.
- **Status:** Verified on PR #180 CI #497

## L-038 — GDScript test fixture helpers need explicit return types when callers rely on inferred locals

- **Date:** 2026-09-21
- **Area:** Godot / GDScript parser / V2-4 opponent behavior domain tests
- **Symptom:** PR #181 CI #500 passed project import/boot and Windows export, then failed only when running `opponent_behavior_test_runner.gd`. Four locals using `:= _load_balanced()` produced `Cannot infer the type ... because the value doesn't have a set type`.
- **Root Cause:** The fixture helper `_load_balanced()` had no declared return type. Under the project's warning-as-error parser rules, callers cannot use inferred local typing when the helper's return type is unresolved, even though the helper always returns `OpponentBehaviorProfile`.
- **Fix:** Declare `_load_balanced() -> OpponentBehaviorProfile` and explicitly type the affected local variables as `OpponentBehaviorProfile`. No AI policy, profile data or decision behavior changed.
- **Prevention Rule:** Domain-test fixture helpers that return a known script/class type should declare that return type. If a helper is intentionally dynamic/Variant, callers must use explicit `Variant` or concrete types instead of `:=`; do not rely on parser inference across helper boundaries.
- **Validation:** Fix commit `9ade45c95059bca3c22eeda5f3714d951603435d`; PR #181 CI #501 (`35591729594`) passed Windows Native, Godot import/boot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- **Status:** Verified on PR #181 CI #501

