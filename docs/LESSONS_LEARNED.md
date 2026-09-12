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
