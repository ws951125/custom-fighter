# Lessons Learned — custom-fighter

本文件是 `custom-fighter` 的永久工程記憶。任何已定位並修正的程式、測試、CI、部署或工具流程問題都應留下可重用的經驗。

## L-001 — Godot dynamic call return type cannot always be inferred with `:=`

- **Date:** 2026-09-12
- **Area:** Godot / GDScript / Character loadout skill resolver
- **Symptom:** PR #45 第一輪 CI 在 Godot parser 階段失敗；四個 child controller 經由動態 `host` 呼叫 resolver 時，使用 `:=` 接回傳值，Godot 無法推斷 `errors` 的型別。
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

- **Date:** 2026-09-12
- **Area:** Godot / GDScript parser / Creator preview runtime
- **Symptom:** PR #57 CI Run #103 在 `Import project headlessly` 失敗。Godot 無法解析 `preview_selectable_main.gd` 作為 `animation_main.gd` 的 parent，並明確回報 `animation_main.gd` 的 `preview_active := session != null and session.has_active_preview()` 無法推斷型別。
- **Root Cause:** `CreatorPreviewSession` 是由 SceneTree/autoload runtime lookup 取得的動態物件。對這類 Variant/dynamic receiver 直接呼叫自訂 method，再用 `:=` 推斷 boolean / collection，會讓 GDScript parser 在 inheritance chain 上失去可解析型別；parent script 一旦解析失敗，child script 只會進一步呈現 `Could not resolve class`。
- **Fix:** Preview runtime 邊界改成明確 `Variant` / `bool` / `Dictionary` / `PackedStringArray` 型別，並以 `has_method()` + `call()` 封裝 autoload 的動態方法呼叫；Animation diagnostics 同樣不再以 `:=` 推斷 dynamic method expression。
- **Prevention Rule:** 對 `get_node_or_null()`、autoload lookup、dynamic host/plugin/interface 等 runtime-resolved object，不用 `:=` 推斷含自訂 method call 的結果。跨 script inheritance boundary 時，應把 dynamic receiver 隔離在 typed helper 內，對外回傳確定的 GDScript 型別。
- **Validation:** 修正後 PR #57 CI Run #105 通過 Godot import、main boot、全部 domain tests、Web export、size budget、Chromium `smoke:all` 與 GitHub-hosted Windows Microsoft Edge `smoke:all`。
- **Status:** Verified

## L-006 — Cooldown remaining is transient telemetry, not durable cast evidence

- **Date:** 2026-09-12
- **Area:** Playwright / production Edge / SkillCoordinator regression
- **Symptom:** PR #57 merge 後 main CI Run #109 的第一個 `Windows Edge Production Game` attempt，在 `skill_coordination_web_smoke.mjs` 已經確認 MP `100 -> 75`、`lastClaimed=skill_1`、claim count 只增加 1、Area Skill 仍為 READY 之後，仍因 `skillCooldown === 0` 而失敗。
- **Root Cause:** `skillCooldown` 是會隨遊戲時間遞減的瞬時 telemetry。production Edge 的網路啟動、frame cadence 與 assertion scheduling 較慢時，測試讀取該欄位前 cooldown 可以合法地回到 0；這不會否定前面已留下的持久證據：MP 已扣除、coordinator last claim 正確、claim count 只增加一次、O 沒有施放。
- **Fix:** `skill_coordination_web_smoke.mjs` 不再要求觀察當下的 cooldown 必須大於 0；只要求 cooldown diagnostic 是有限且非負數值，並以 MP delta + persistent lastClaimed + claimCount + rejected O state 作為 exclusivity/cast 的 durable evidence。首次失敗的 production job targeted retry 在未改程式前也已 PASS，進一步證明原問題是 observation flake 而非 gameplay regression。
- **Prevention Rule:** 對 cooldown remaining、短暫 animation/state boolean、frame-local phase 等會自然消逝的 telemetry，不要在經過非同步等待後把「仍為 active / > 0」當成唯一成功證據。優先使用持久 counter、resource delta、last-event identity、hit count 或明確 runtime acknowledgement。
- **Validation:** Run #109 targeted production Edge retry PASS，包含 `WEB_SKILL_COORDINATION_SMOKE_PASSED` 與 `WEB_CREATOR_PREVIEW_SMOKE_PASSED`。Assertion hardening 本身仍需 Issue #58 PR 的 Chromium + hosted Windows Edge 驗證。
- **Status:** Fix implemented; PR validation pending
