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

- **Date:** 2026-09-12
- **Area:** GitHub connector / repository operations
- **Symptom:** 開始 M3 Slice 5 時，原本要建立 feature branch，卻誤觸 issue creation action，產生兩個不需要的 tracking issues (#47、#48)。
- **Root Cause:** 在多個 GitHub mutation actions 可用時，未先鎖定「branch」操作 schema 就執行寫入，造成 action selection 錯誤。
- **Fix:** 立即將 #47 以 `not_planned` 關閉、#48 以 `duplicate` 關閉；重新載入 branch-specific action schema 後才建立 `feature/m3-character-registry-selection`。
- **Prevention Rule:** GitHub 寫入前先確認 mutation 類型與目標物件完全一致（issue / branch / file / PR）；若當前工具清單不明確，先做精確 resource discovery，再執行 mutation。不要用測試性寫入確認工具能力。
- **Validation:** #47、#48 均已關閉；正式 M3 Slice 5 工作只追蹤於 Issue #46 與其 feature branch。
- **Status:** Verified

## L-004 — Transient browser diagnostics must be distinguished from runtime state evidence

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright runtime observation
- **Symptom:** PR #55 merge 後 main CI Run #102 的第一個 GitHub-hosted Windows Edge attempt，在 `tests/web_smoke.mjs` 等待 `playerRunning === 'true'` 時 timeout；同一份 log 卻持續印出 `CUSTOM_FIGHTER_STATE ... state=RUN`。PR 上相同程式與 artifact 的 Edge gate 先前已通過，Ubuntu/Chromium gate 亦成功。
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

## L-007 — An isolated hosted Edge readiness timeout must not trigger unrelated runtime changes without reproducible evidence

- **Date:** 2026-09-12
- **Area:** GitHub Actions / Windows Edge / Playwright startup readiness
- **Symptom:** PR #63 CI Run #119 passed Godot import/boot/domain tests, Web export/size budget and Chromium, but the hosted Windows Edge job timed out in unchanged `character_selection_web_smoke.mjs` while waiting for Web/Godot readiness.
- **Evidence / Diagnosis:** The failing path was outside the M5 VFX changes；the same Character Selection flow was green on production main Run #118 and all prior smoke tests in the failing Edge job had already progressed normally. The failure therefore did not provide reproducible evidence of a Character runtime regression.
- **Operational Fix:** Treat the single failure as an isolated hosted-browser startup/readiness flake, retry only the failed gate when appropriate, and require a fresh latest-head PR CI after subsequent commits rather than modifying unrelated Character runtime code.
- **Prevention Rule:** Before changing runtime code for a hosted-browser timeout, compare changed paths, earlier steps in the same job, same-SHA cross-browser evidence and a fresh run. A targeted retry is acceptable for an isolated readiness/observation timeout, but no PR may merge until the final latest head is green on all required gates.
- **Validation:** PR #63 latest-head CI Run #126 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all`, including the unchanged Character Selection regression and the new VFX Creator smoke.
- **Status:** Verified

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

- **Date:** 2026-09-13
- **Area:** GitHub connector / branch mutation workflow
- **Symptom:** 建立 `feature/m6-ai-vfx-provider-boundary` 成功後，同一個 branch-create mutation 被重複送出，GitHub 連續回傳 HTTP 422 `Reference already exists`。Repository 狀態本身沒有損壞，但產生了不必要的寫入失敗與噪音。
- **Root Cause:** 成功 mutation 後沒有先讀回 branch state，再執行下一個不同操作；重複使用上一個 branch-create action，造成 idempotency 不成立的 create-ref 被再次提交。
- **Fix:** 停止重送 branch creation，重新做 operation-specific tool discovery，確認 Issue mutation schema 後建立 Issue #68，並沿用已存在的 feature branch。
- **Prevention Rule:** 任何 create branch / issue / PR / file 等非冪等 GitHub mutation 成功後，先把回傳物件視為 source of truth；若下一步工具選擇或狀態有疑義，先 read/search/verify，再執行下一次 mutation。不得用重送相同 create 動作確認狀態。
- **Validation:** `feature/m6-ai-vfx-provider-boundary` 保持單一有效 branch；Issue #68 已正確建立並指向該 work unit，後續程式與文件 commit 都持續寫入該 branch。
- **Status:** Verified

## L-010 — Inherited GDScript constants must not be redeclared when a child becomes a direct dependency

- **Date:** 2026-09-13
- **Area:** Godot / GDScript inheritance / AI provider preload boundary
- **Symptom:** M6 Slice 2 PR #71 CI Run #141 在 `Import project headlessly` 失敗。新增的 Creator AI studio 首次直接 preload `MockAiVfxProvider`，Godot 回報 child script 重新宣告 parent `AiVfxProvider` 已有的 `AiVfxResult` member；同一個 mock script 另有 `radius := max(...)` 的 Variant inference warning-as-error。
- **Root Cause:** Slice 1 的 mock provider 雖存在且由 domain flow 使用，但沒有被 Creator scene 直接 preload，因此這個 child/parent member collision 沒有在先前一般 scene import 路徑曝光。GDScript 繼承 member 會包含 parent constant，child 不可再以相同名稱宣告；同時 generic `max()` 搭配除法讓 `:=` 推斷落入 Variant warning。
- **Fix:** 移除 child 的重複 `AiVfxResult` preload，直接使用 parent inherited constant；將 radius 改為明確 `int` 並使用 `maxi()`，避免 Variant inference。
- **Prevention Rule:** 新增 inheritance-based adapter/provider 時，parent 已提供的 preload/constants 不在 child 重宣告。任何首次被 scene 直接 preload 的 provider 都必須經完整 Godot import gate；數值 helper 在 warning-as-error 專案中優先使用 typed `maxi`/`maxf` 並明確宣告結果型別。
- **Validation:** 修正已提交至 PR #71 最新 head；等待新的 GitHub-hosted CI 驗證 Godot import、browser workflow 與 Edge gate。
- **Status:** Fix committed; fresh CI pending
