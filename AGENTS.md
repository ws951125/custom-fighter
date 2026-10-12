# AGENTS.md — custom-fighter

`AGENTS.md` is the single source of truth for AI Agent / Codex / automated development instructions in this repository. Do not create or maintain `Agent.md`. Future rule additions or changes must be made incrementally here without deleting, weakening, shortening, or silently overriding existing valid rules. If a nested directory contains its own `AGENTS.md`, obey both this root policy and the applicable nested policy.

## 1. Project purpose and core principles

`custom-fighter` is a Godot-based, Web-capable, data-driven fighting game / character-skill platform.

Core principles:
- Cloud-first / CI-first and online-test-first.
- Data-driven character, skill, VFX, package, and configuration design.
- Cross-platform runtime; core combat/character/skill/package logic must not depend on desktop-only APIs.
- Player content must be safe declarative data/assets and must not execute arbitrary code.
- AI/VFX providers must remain replaceable behind provider/adapter boundaries.
- Bug fixes should add or strengthen regression coverage when practical.
- Secrets never enter Git.

Product/validation references include:
- `AGENTS.md`
- `docs/MVP.md`
- `docs/STATUS.md`
- `docs/ONLINE_TESTING.md`
- `docs/WEB_LOADING.md`

## 2. Repository/GitHub truth before work

Before any mutation, inspect the actual current GitHub/repository state. Do not rely only on chat memory, screenshots, stale checkpoints, local refs, or previous reports.

At minimum verify:
1. this `AGENTS.md` in full;
2. `docs/MVP.md`, `docs/STATUS.md`, and `docs/ONLINE_TESTING.md`;
3. code/tests/docs directly relevant to the task;
4. current feature branch and head SHA;
5. related PR open/closed/merged/mergeable state;
6. latest relevant GitHub Actions and Web deployment state;
7. any applicable nested `AGENTS.md`.

If chat/checkpoint information conflicts with GitHub, GitHub/repository state wins and the discrepancy must be reported. Re-check GitHub before every progress/result reply; branch/commit/PR information must reflect the current remote state.

## 3. Branch, commit, PR, and synchronization rules

- Write formal code/test/doc/config changes directly to the active GitHub feature branch.
- Do not use patches/diffs or user copy/paste as the primary delivery mechanism.
- Unless the user explicitly requests otherwise, do not commit directly to `main`.
- Keep one coherent work unit in one feature branch/PR where practical; avoid unnecessary micro-PR fragmentation.
- Commits should represent focused logical work units with clear messages.
- Never commit secrets, credentials, private tokens, signing keys, production dumps, or confidential model credentials.
- Every completed code/test/doc/config work unit reported to the user must already be committed/pushed to GitHub. Local-only, temporary, or chat-only work does not count as completed progress.
- Every recognizable work unit must also synchronize `docs/STATUS.md`; update `docs/MVP.md` when milestone/scope changes materially.
- If a corrected error yields a durable engineering lesson, synchronize `docs/LESSONS_LEARNED.md` before reporting completion.
- If a work unit has merged, re-check actual `main` merge SHA before reporting it.
- Distinguish “synchronized to GitHub” from “deployed/production-validated”.

### Response Gate — mandatory GitHub synchronization before reporting

Before every reply that reports project progress, completed work, fixes, test results, or a checkpoint, perform a Response Gate. This gate strengthens the synchronization rules above and applies equally to code, tests, configuration, documentation, and `AGENTS.md` changes.

1. Determine whether the current work round contains project changes that should be committed. Never commit disposable temp files, build caches, dependencies, browser profiles, test output, generated caches, or other ignored/non-source artifacts merely to satisfy this gate.
2. If there are project changes, complete the minimum necessary applicable validation first, then commit them to the active formal feature branch and push them to the repository's authoritative GitHub remote before reporting them as complete.
3. After the push, re-read the authoritative GitHub branch ref and, when a PR exists, its head SHA. The branch head must equal the commit being reported, and the PR head must equal that same latest pushed branch head.
4. Because this repository's GitHub-only hard rule prohibits access to the user's local computer, local `git status`, local `HEAD`, `HEAD...origin/<current-branch>`, PowerShell, and local working-tree checks must not be executed for this repository. Their Response Gate purpose is satisfied here by authoritative GitHub branch/commit/PR verification. If an authorized cloud workspace with an actual Git checkout is used in the future without weakening section 4, also require clean intended changes, `Local HEAD = origin/<current-branch>`, and `git rev-list --left-right --count HEAD...origin/<current-branch>` = `0 0`; on Windows PowerShell prefer explicit `origin/<current-branch>` rather than `@{upstream}`.
5. Do not report a work round as complete if the authoritative GitHub branch/PR does not contain its intended changes. First repair synchronization, or explicitly report `尚未同步 GitHub` with the blocker.
6. If the user explicitly instructs the Agent not to commit or not to push for that round, obey that instruction and explicitly report that the work is not synchronized to GitHub; do not label local-only/unpushed work complete.
7. This Response Gate does not replace or weaken testing, Playwright/browser validation, cleanup, PR, merge, deployment, authorization, security, or any other existing rule. Required final validation gates remain required.

## 4. GitHub-only / online-only hard rule

All engineering validation and project Git synchronization for `custom-fighter` are online-only. Do not connect to, execute commands on, inspect, modify, build, test, debug, or synchronize this project through the user's local computer.

Prohibited paths include:
- Remote Desktop Commander;
- local/remote user terminals;
- local Godot, Node/npm, Playwright, PowerShell, Python, browsers, caches, or filesystem;
- SSH or remote desktop to the user's machine;
- asking the user to run routine local commands and paste results;
- falling back to local validation because CI is unavailable.

Allowed/required validation hierarchy, using the highest applicable cloud-hosted level:
1. pure logic/domain/unit tests in GitHub Actions;
2. Godot headless parse/import/boot in GitHub Actions;
3. Godot headless integration/domain tests;
4. Web export;
5. Web artifact/size-budget checks;
6. Chromium browser smoke/E2E on GitHub-hosted runners;
7. Windows native export where applicable;
8. Microsoft Edge smoke/E2E on GitHub-hosted Windows runners;
9. GitHub Pages deployment/public reachability;
10. user manual gameplay/visual/UX acceptance through the GitHub Pages URL when subjective acceptance is required.

If a required check cannot be completed online, mark it `Blocked` / `Residual Risk`; never substitute local validation or claim PASS.

## 5. GitHub Actions and continuous monitoring

- Never report a test as PASS without actual executed online evidence.
- Never treat queued/in-progress as PASS.
- Watch every required run/job through a terminal state: success, failure, cancellation, or confirmed external blocker.
- If the user asks to keep monitoring until completion, do not stop with an intermediate result while required jobs/deployment gates are merely in progress.
- If a check fails, inspect online logs, distinguish code failure from GitHub/runner/provider failure, fix code/test/workflow issues in the feature branch, and observe the replacement run.
- Do not waste Actions quota by blindly rerunning unrelated successful jobs.
- A long-running `in_progress` job is not itself a blocker.
- Platform quota/runner/stuck/log-access failures must not be misreported as product bugs.
- Required failing checks block merge.

## 6. Continuous phase execution / no stop-and-wait

Once a roadmap phase starts, continue through every safe and inferable task in that phase: implementation, adjacent slices, regression coverage, cloud validation, failure diagnosis/fixes, documentation/status sync, PR/merge work already authorized, deployment work already authorized, and acceptance evidence.

Do not stop merely because one slice, commit, PR, test group, or sub-milestone finished, and do not require repeated “continue” messages. Stop only when explicit user action/approval is genuinely required, such as a missing secret/API credential, payment, new external-account permission, destructive operation, or materially ambiguous product decision. One blocked dependency does not block unrelated safe work; finish non-blocked work first.

## 7. Architecture and data-driven boundaries

- Keep core combat/character/skill rules separated from UI/rendering where practical.
- `CharacterDefinition` / `SkillRegistry` / skill data are runtime sources of truth; do not replace them with hidden controller hard-coded sample paths.
- Adding a normal character or skill should not require editing the combat engine.
- Registry/loader paths must fail closed for unknown IDs, unsafe paths, invalid types, arbitrary fields, and controller/type mismatches.
- Input must be represented as actions/intents rather than hard-wired device assumptions.
- Creator tooling may be PC/Web-first, but output runtime data formats must remain portable.

Preferred top-level structure remains:

```text
game/
  core/
    combat/
    character/
    skill/
    hitbox/
    status/
  runtime/
    battle/
    ai/
    stage/
  creator/
    character_editor/
    skill_editor/
    animation_editor/
    vfx_editor/
  ai/
    provider/
    local/
    cloud/
content/
  characters/
  skills/
  vfx/
  stages/
tests/
docs/
```

## 8. Player content and security

Player-created/imported content may use validated structured data and approved assets. Do not load or execute user-supplied GDScript, native libraries, executables, Python, shell/PowerShell scripts, or arbitrary executable code. External paths, resource types, skill IDs, character IDs, and package metadata must pass allow-list/schema/registry validation.

High-risk work involving arbitrary code execution, untrusted packages, executable downloads, secrets/credentials, major architecture replacement, or breaking data migrations must stop for user confirmation when existing policy does not already resolve the decision. Reversible low-risk engineering details should be handled autonomously and validated.

## 9. Regression and Web validation

- Bug fixes should add repeatable regression tests when practical.
- Domain/loader/registry changes require deterministic fixtures or explicit assertions.
- Gameplay input/skill-binding changes require applicable browser smoke or equivalent runtime coverage.
- Web export changes require production export/boot validation and existing reasonable size-budget validation.
- UI/browser changes requiring Playwright must use headless automation by default in GitHub-hosted CI, with the minimum necessary browsers/workers.
- Browser validation must monitor relevant console errors, page errors, request/network failures, and unexpected 4xx/5xx responses across the tested flow.
- Browser/process resources created by CI tests must be closed/cleaned at completion; disposable test artifacts/profiles must not be intentionally retained without a documented reason.

## 10. Permanent error lessons

`docs/LESSONS_LEARNED.md` is permanent engineering memory. When an Agent/Codex code change, test, deployment, CI flow, or tool operation fails, and the root cause and fix become known, record or update the lesson rather than discarding the history.

Each lesson should include at least:
- Symptom
- Root Cause
- Fix
- Prevention Rule
- Validation
- Status (`Verified`, `Pending`, etc.)

Update recurring lessons instead of deleting valid history.

## 11. Documentation/status synchronization

Every recognizable work unit must update `docs/STATUS.md`. Status should answer:
- date/work unit or milestone;
- completed content;
- validation method/result;
- primary files;
- remaining work;
- next step.

Do not allow code to be “complete” while repository progress records remain stale.

## 12. Definition of Done

A feature is Done only after all applicable items are satisfied:
1. implementation complete;
2. basic error handling and fail-closed behavior complete;
3. repeatable GitHub-online validation exists;
4. relevant unit/domain/integration/regression tests pass in GitHub Actions;
5. Godot import/boot/parse gates pass;
6. if Web runtime is affected, Web export and applicable browser smoke pass;
7. documentation is synchronized;
8. `docs/STATUS.md` is synchronized;
9. corrected durable errors are recorded in `docs/LESSONS_LEARNED.md`;
10. PR/branch/merge state is re-verified;
11. unverified online items are explicitly `Residual Risk` / `Manual Acceptance`;
12. subjective gameplay/visual acceptance, when required, has a GitHub Pages URL and is not treated as accepted before the required user acceptance.

## 13. PR / merge rules

- Merge only after required online validation passes.
- If a work unit requires user GitHub Pages gameplay/UX acceptance, do not merge before the user explicitly reports PASS.
- If user acceptance fails, fix the same feature branch/PR and revalidate online.
- Every report must state the previous relevant PR merge state, current PR number/title/branch, whether it merged to `main`, and actual merge SHA when merged.
- Re-check GitHub before reporting; do not report from memory.

## 14. Online test URL

Whenever a playable/testable Web build is deployed, every relevant progress/result reply must include a directly usable online URL.

Production default:
`https://ws951125.github.io/custom-fighter/`

If production does not yet contain the current PR, explicitly say so. Label a branch/preview URL as Preview. If no preview exists, do not imply that production can validate the new change. Never substitute localhost or a user-machine build.

## 15. Whole-project progress and mandatory report format

Every meaningful development/result/progress/error/blocker reply must include, succinctly:
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
- `➡️ 下一步要進行的是什麼`

Progress percentage must be derived from repository-defined milestones rather than intuition. For the V1/MVP M0–M8 structure, only formally Done milestones count toward the completed numerator unless repository roadmap documents formally change the denominator. V2 progress is tracked independently according to `docs/V2_ROADMAP.md`; partial work inside an active V2 phase does not count as a completed V2 phase.

Every code/content/config modification report must also list the complete current user-facing control map for the playable/testable build, not only controls changed in that batch. Include keyboard combinations, mouse/touch UI where applicable, action name, purpose, and contextual/disabled/diagnostic-only status. If no clickable gameplay/touch UI exists, state that explicitly.

The `➡️ 下一步要進行的是什麼` field is mandatory even when a work unit is complete. It must name a concrete engineering action, not vague wording such as “continue”. If blocked, state the blocker and the first concrete action after it clears; complete safe non-blocked work before stopping.

## 16. Checkpoint / handoff and conversation-length rule

Maintain repository-synchronized checkpoints/handoffs sufficient to continue work without relying on chat memory. A handoff must capture the actual project/repo, active branch, HEAD SHA, remote/PR state, completed work, remaining work, latest tests, blockers/residual risks, and concrete next action.

When the conversation reaches roughly 70% of its usable length:
1. remind Vincent to start a new conversation;
2. first synchronize the latest project progress and checkpoint/handoff to the repository according to this file;
3. in the same reply, provide a directly copyable continuation Prompt;
4. that Prompt must contain the actual project/repo, branch, HEAD commit, authoritative Git/remote state, completed/todo items, latest test results, blockers, and next action;
5. the new conversation Prompt must require the next Agent to read the complete current `AGENTS.md` first and verify the checkpoint against actual GitHub/Git/remote state before doing any mutation;
6. the new Agent must not assume that local `main`, an old feature branch, or a previously reported commit is still latest.

## 17. Production AI cost policy — free Gemini only

- Production AI must use Google Gemini API free tier only; do not connect OpenAI or another paid AI provider unless the user explicitly reverses this policy.
- Default production model is `gemini-3.6-flash`; only models verified from current official Google documentation to have a Gemini Developer API free tier and current API availability may enter the allow-list.
- Production also requires `GEMINI_FREE_TIER_ONLY=true`; the configured `GEMINI_API_KEY` must belong to an AI Studio project without paid billing. The flag is a guard/assertion, not proof of Google account billing state.
- Gemini native image-generation models are not valid fallbacks when their API pricing has no free tier.
- Use free Gemini for prompt/reference understanding and structured design output, then project-owned deterministic rendering/processing for final VFX assets.
- `AI_IMAGE_PROVIDER` must fail closed outside `gemini`; paid-provider fallback is prohibited.
- Provider credentials remain server-side and never enter Git, browser storage, query parameters, fixtures, or Creator data.
- Before changing the allow-list, verify current Google pricing/model availability from official documentation.

## 18. Connector/deployment retry safety

- One transient connector/auth/device-routing/network/provider error is not enough to declare authorized tooling unavailable.
- Read-only failures may be retried several times with corrected explicit identifiers/parameters while preserving safety gates.
- Distinguish transient transport/auth/session failures from hard permission/configuration/destructive-operation blockers.
- Do not bypass connector safety gates merely to make retries succeed.
- Mutating connector calls must not be blindly replayed after uncertain results. Inspect current remote state first; if the mutation already succeeded, use read/status operations instead of repeating it.
- If repeated mutations accidentally occur, stop writes, inspect resulting queues/state, retain only the latest valid operation in flight where safely possible, and record the incident in `docs/LESSONS_LEARNED.md`.

## 19. Required workflow for each development batch

1. Inspect current GitHub/repository state and relevant code/policy.
2. Define batch/phase scope and acceptance criteria.
3. Group coherent changes on a feature branch.
4. Implement with regression coverage.
5. Open/update the PR.
6. Run applicable GitHub-hosted validation.
7. Monitor every required workflow/job through terminal state.
8. Inspect logs and fix failures before declaring success.
9. Merge only after required gates and any required user acceptance pass.
10. Continue through the rest of the active phase/next safe adjacent task without stop-and-wait.
11. Before stopping for an approval blocker, finish safe non-blocked work.
12. Record changes, tests, failures/fixes, risks, and unverified behavior.
13. Synchronize STATUS/roadmap/lessons as required.
14. Re-check branch/head/PR/main/deployment truth before final reporting.

## 20. Legacy filename migration rule

`AGENTS.md` is the only active root Agent instruction file. `Agent.md` must not be recreated or maintained. Active documentation, scripts, workflow comments, and configuration must reference `AGENTS.md` instead. Historical text inside immutable/preserved engineering incident narratives may mention the old filename only when necessary to accurately describe what happened at that time; such a historical mention is not an active instruction source.

## 21. Test efficiency and targeted revalidation

These rules supplement, and do not replace, the existing Playwright, regression, GitHub-online validation, Definition of Done, and PR/merge requirements above.

- Follow a fast-to-slow validation order. Prefer the cheapest applicable checks first: lint/static checks where available, type/parse checks where available, affected unit/domain tests, then affected integration tests.
- Run targeted Playwright/browser automation only when the change affects Web UI, browser interaction, or an actual user-operation flow that requires browser-level evidence. Do not use Playwright as a substitute for validation that can be completed adequately by lighter deterministic tests.
- When Playwright or another test fails, analyze the failure and correct the proven cause before rerunning. After a fix, first rerun only the failed test, affected test group, or directly affected user flow needed to verify that correction.
- Do not rerun the complete E2E/full regression suite after every individual fix merely because one test failed. Do not blindly rerun unrelated tests that already passed.
- After targeted tests pass, a full Playwright/E2E/regression run is not automatically required after every small correction. Run the broader applicable regression at the appropriate existing gate, such as completion of the coherent work unit, an important milestone, a substantial cross-module change, release-candidate validation, or before PR merge when required by the repository's existing merge/Definition-of-Done policy.
- Preserve autonomous AI validation behavior: the Agent should still discover failures, diagnose them, fix them, and revalidate without unnecessary stop-and-wait. The efficiency rule changes test scope/order, not the requirement to obtain actual online evidence for required checks.
- Minimize unnecessary browser launches, repeated full E2E runs, duplicate checks, and resource consumption while retaining all existing required final validation gates. If an existing rule explicitly requires a broader test at a particular milestone or merge gate, that requirement remains authoritative and is not weakened by this section.

## 跨專案共用測試下載快取（2026-10-12）

使用者明確批准的本機永久規則：**下載快取可跨專案共用；執行依賴、測試工作區和每輪測試資料必須彼此隔離**。這只適用於本機測試／開發驗證，不變更原專案工作樹、正式資料庫、網站部署、Production 環境或既有備份政策。

- 固定測試根目錄：`E:\test`，不得改用 E 槽根目錄、C 槽或 D 槽；若不可用，應暫停並向使用者確認替代方案，不可默默 fallback。
- 各專案共用的**套件下載快取**：`E:\test\shared\cache\npm`、`E:\test\shared\cache\pip`、`E:\test\shared\cache\pnpm-store`；相容 Playwright browser binaries 共用 `E:\test\shared\cache\playwright-browsers`，由 Playwright 按實際 revision 決定可否重用。第一次可能需要下載，之後有快取時不應每輪重新下載。
- 本專案自己使用 `E:\test\custom_fighter\workspaces` 作為長期可重用的安全隔離 checkout、`E:\test\custom_fighter\shared\venvs` 保留依 Python 版本與 dependencies 分隔的 venv、`E:\test\custom_fighter\runs` 按輪次建立獨立 `tmp`／`artifacts`／測試輸出；`node_modules` 留在**本專案**版本相容的工作區，**不得跨不同專案強行共享**。
- 共用入口：`E:\test\shared\scripts\use_cross_project_test_cache.ps1`。`-Project custom_fighter -Mode Inspect` 只讀；`-Mode Enter` 只為目前 PowerShell process/child process 設定 npm/pip/Playwright 快取，不修改全域 Windows 或使用者 npm/pip 設定；`-Mode NewRun` 另建立唯一 run/`tmp`/`artifacts` 並指定暫存。PowerShell 腳本版本來源存放在 `ws951125/sunzi-advisor/scripts/use_cross_project_test_cache.ps1`。
- `pnpm` 使用 `--store-dir "E:\test\shared\cache\pnpm-store"`（或同等**僅限當次程序**的設定）以重用 store；不得執行影響其他專案的全域 `pnpm config set`、`npm config set` 或 `setx`。
- 開始前先檢查該專案 `package-lock.json` / `pnpm-lock.yaml` / `pyproject.toml` / requirements、Node/Python/套件版本及既有 checkout 的 `git status`。符合版本時直接重用已安裝的 `node_modules`／venv；不因只改程式碼、測試碼或切換工作項就重新 clone、`npm ci`、新建 venv、下載 Playwright。尤其 **`npm ci` 會刪除並重建 node_modules**，絕對不可對既有可用環境例行執行。
- 版本不相容、lockfile 有異動或有必要執行真正的 clean-install gate 時，先規劃**新的版本隔離環境**，優先使用相同的跨專案下載快取，不得覆寫現存可用依賴；涉及刪除、覆寫、搬移既有目錄或套件，需列出精確範圍、原因、復原方案並取得使用者本次明確批准。
- 允許不同專案同時執行：分開各自的 Python venv、`node_modules`、source checkout、port、test DB、browser profile、`runs`，共享的只是不含機密的套件下載快取／相容瀏覽器 binaries；不可共享 session、正式業務資料、cookie、.env 或資料庫寫入操作。
- **禁止未經逐次批准的任何刪除、清理、搬移、覆寫測試／暫存檔**，包含以前本系統建立、目前跑完或過期的目錄。測試腳本若含 `Remove-Item`、stale cleanup 或 `finally` 自動刪除，需先檢查並避免執行破壞性段落；新架構的初始化只新增缺少目錄、不搬移舊快取、不刪舊測試。每次回報需分開說明「共用目錄已建立」、「套件實際已可重用」及「品質測試已通過」，不得混稱。
