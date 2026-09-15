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
- **Operational Fix:** Treat the single failure as an isolated hosted-browser startup/readiness flake, retry only the failed gate when appropriate, and require a fresh latest-head PR CI after subsequent commits rather than modifying unrelated Character runtime code。
- **Prevention Rule:** Before changing runtime code for a hosted-browser timeout, compare changed paths, earlier steps in the same job, same-SHA cross-browser evidence and a fresh run. A targeted retry is acceptable for an isolated readiness/observation timeout, but no PR may merge until the final latest head is green on all required gates.
- **Validation:** PR #63 latest-head CI Run #126 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all`, including the unchanged Character Selection regression and the new VFX Creator smoke。
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

- **Date:** 2026-09-13; recurrence during M7 Slice 2
- **Area:** GitHub connector / branch and file mutation workflow
- **Symptom:** 建立 `feature/m6-ai-vfx-provider-boundary` 成功後，同一個 branch-create mutation 被重複送出，GitHub 回傳 HTTP 422 `Reference already exists`。M7 Slice 2 又曾在 feature branch 尚未建立前直接送出 `create_file`，GitHub 正確回傳 404 `Branch ... not found`。兩次都沒有破壞 repository，但造成不必要的寫入失敗與流程噪音。
- **Root Cause:** 非冪等 GitHub mutation 前後沒有把 branch/file existence 當成明確前置條件與 source of truth；第一次是成功後重送 create，第二次是 file mutation 早於 branch creation。
- **Fix:** 停止重送 branch creation；M7 recurrence 則先建立 `feature/m7-package-json-export-import`，確認 branch 成功後再提交檔案。後續 M7 Slice 3 也遵循 Issue → branch → file commit → PR 順序。
- **Prevention Rule:** 任何 create branch / issue / PR / file 等非冪等 mutation 都要按依賴順序執行。成功回傳即視為 source of truth；建立 feature file 前必須先確認 target branch 已存在。不得用重送 create 動作確認狀態。
- **Validation:** M7 Slice 2 branch 建立後所有 commit 均正確落在該 branch，PR #75 最終 merge 且 production Run #151 全綠；Slice 3 branch 亦在任何 feature file mutation 前成功建立。
- **Status:** Verified

## L-010 — Inherited GDScript constants must not be redeclared when a child becomes a direct dependency

- **Date:** 2026-09-13
- **Area:** Godot / GDScript inheritance / AI provider preload boundary
- **Symptom:** M6 Slice 2 PR #71 CI Run #141 在 `Import project headlessly` 失敗。新增的 Creator AI studio 首次直接 preload `MockAiVfxProvider`，Godot 回報 child script 重新宣告 parent `AiVfxProvider` 已有的 `AiVfxResult` member；同一個 mock script 另有 `radius := max(...)` 的 Variant inference warning-as-error。
- **Root Cause:** Slice 1 的 mock provider 雖存在且由 domain flow 使用，但沒有被 Creator scene 直接 preload，因此這個 child/parent member collision 沒有在先前一般 scene import 路徑曝光。GDScript 繼承 member 會包含 parent constant，child 不可再以相同名稱宣告；同時 generic `max()` 搭配除法讓 `:=` 推斷落入 Variant warning。
- **Fix:** 移除 child 的重複 `AiVfxResult` preload，直接使用 parent inherited constant；將 radius 改為明確 `int` 並使用 `maxi()`，避免 Variant inference。
- **Prevention Rule:** 新增 inheritance-based adapter/provider 時，parent 已提供的 preload/constants 不在 child 重宣告。任何首次被 scene 直接 preload 的 provider 都必須經完整 Godot import gate；數值 helper 在 warning-as-error 專案中優先使用 typed `maxi`/`maxf` 並明確宣告結果型別。
- **Validation:** PR #71 修正後 latest-head CI Run #143 通過 Godot import/boot/domain、Web export/size budget、Chromium 與 hosted Windows Edge；merge 後 main Run #144 與後續 Run #145 均通過 production gates。
- **Status:** Verified

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

## L-013 — Directional melee smoke positioning must guarantee facing, not only numeric range

- **Date:** 2026-09-14
- **Area:** GitHub Actions / Windows Edge / Playwright / production regression smoke
- **Symptom:** PR #116 merge 後 main CI Run #228 的 Windows Native、Chromium、hosted Windows Edge、GitHub Pages deploy/public reachability 與 Render backend readiness 均成功，但最後的 `Windows Edge Production Full Smoke` 在 `tests/match_restart_web_smoke.mjs` 第一個 `J` 命中等待逾時。原 `approach()` 會依 gap 雙向使用 `D`/`A` 校正位置，因此雖然最後數值距離落在 melee range，最後一次輸入仍可能是 `A`。
- **Root Cause:** melee hitbox 依 player facing 決定方向；「在數值距離內」本身不足以證明角色正朝向目標。Hosted production Edge 的 frame cadence 會讓最後一次位置修正落在 `A`，使角色面向左側而假人在右側，結果是攻擊動作成立但 hitbox 往錯方向發出。
- **Fix:** `match_restart_web_smoke.mjs` 改為先把角色穩定放到假人左側，再讓最後逼近只使用 `D`，並在攻擊前驗證最終 gap 落在接受區間。此修正只調整測試定位策略，沒有修改 gameplay runtime。
- **Prevention Rule:** 任何驗證 directional attack 的 browser positioning helper，都必須同時保證「幾何距離」與「面向方向」；最後的 movement input 應明確建立 facing，不可只靠雙向座標校正。已有穩定 helper 時優先共用其 stage-left / one-way-approach 模式。
- **Validation:** PR #117 CI Run #229 的 Windows Native Release、Chromium `smoke:all` 與 GitHub-hosted Windows Microsoft Edge `smoke:all` 全部通過。
- **Status:** PR gate verified; main production acceptance pending merge

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
- **Fix:** Reuse the proven `movementNudge()` invariant from the melee smoke: after each movement input, wait for runtime-observed `playerX` motion before another command; shorten hold duration near the target; if an accepted input still overshoots, re-stage left and retry. Successful positioning always finishes with `D` to preserve deterministic right-facing.
- **Prevention Rule:** Browser positioning loops must use runtime-observed coordinate progress as their command pacing, not fixed sleeps plus potentially stale reads. For narrow or remote corridors, use distance-adaptive movement and an explicit overshoot recovery strategy; do not treat one fixed-duration nudge as bounded displacement across hosted runners.
- **Validation:** PR #119 first-head CI Run #237 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` without retry.
- **Status:** Fix verified on PR first-head Run #237; merge gate requires latest-head CI.

## L-017 — Heavy Strike smoke corridors must follow authored hitbox geometry

- **Date:** 2026-09-15
- **Area:** GitHub Actions / Windows Edge / Playwright / Heavy Strike regression smoke
- **Symptom:** PR #120 Run #242 attempt 2 reproduced the deferred L-008 positioning failure in `tests/melee_web_smoke.mjs`: the final right-facing `D` approach landed at `playerX=828.99`, `dummyX=860`, `gap=31.01`, and the helper rejected it because its hard-coded lower corridor was 40 px. The same PR changes were otherwise documentation-only at that point, while Native and Chromium were green.
- **Root Cause:** The 40 px lower bound was a test-authored spacing preference, not a gameplay invariant. Heavy Strike is authored with `range=72` and `hitbox_half_width=54`, so its hitbox extends from 18 px to 126 px in front of the cast origin before even accounting for the dummy's own 30 px half-width. A 31 px forward gap is therefore a valid right-facing hit position, and rejecting it conflated one-frame positioning overshoot with a combat failure.
- **Fix:** Set the smoke helper's lower corridor to the geometry-derived 18 px while preserving stage-left / final-`D` facing. Keep the substantive assertions unchanged: real cast acceptance, exact 24 damage, 18 MP spend, positive cooldown, exactly one hit, hit flag, and hitbox center in front of the player. No gameplay runtime or skill parameter changes.
- **Prevention Rule:** Coordinate preconditions in browser combat tests must be derived from the authored hitbox/hurtbox contract or another explicit gameplay invariant, not from an arbitrary visual spacing preference. Continue to verify the actual gameplay outcome separately so broader-but-valid geometry cannot hide a missed attack.
- **Validation:** PR #120 CI Run #246 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` with the geometry-derived 18 px lower corridor.
- **Status:** Verified on PR Run #246; final latest-head merge gate pending documentation sync.

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
- **Root Cause:** `coordinated_area_skill_controller.gd::_can_start_cast()` checks `can_claim(skill_3)` before `_try_cast()` reaches `try_claim(skill_3)`. When another skill owns the coordinator, Area is therefore blocked at the pre-claim gate; no rejected claim occurs and no rejection counter should increment. The test encoded the wrong layer of the runtime contract.
- **Fix:** Keep `try_claim()` rejection semantics covered by the coordinator domain tests, and change the browser smoke to validate the actual integration contract: expose durable `areaSkillInputLatched` telemetry, prove the `O` input was sampled while `skill_1` still owned the coordinator, and assert Area did not enter a cast, MP was not spent, and claim count did not change. No gameplay behavior, damage, cooldown, MP cost, or control mapping changed.
- **Prevention Rule:** Browser integration tests must assert the behavior of the public runtime path they actually drive. Do not expect downstream telemetry from code that an earlier guard intentionally prevents from executing. Use domain tests for lower-level rejection semantics and durable input/phase/resource telemetry for integration gating.
- **Validation:** PR #120 latest-head CI Run #250 passed Windows Native Release, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` on head `610037d8207fe8b11bf924c5b5cfb641b212d4c1` before this documentation-only lesson commit.
- **Status:** Fix verified on Run #250; final latest-head merge gate pending this documentation commit.
