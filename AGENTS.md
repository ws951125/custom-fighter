# AGENTS.md

## Purpose

This repository is developed with **online-only validation**. All engineering validation must run in GitHub-hosted CI or other explicitly approved cloud environments. Do not connect to, execute commands on, inspect, or use the user's local machine for testing or validation.

## Non-negotiable rules

1. **All validation is online-only.**
   - GitHub Actions is the primary and required validation path for code changes.
   - Do not use Remote Desktop Commander, local terminals, local Godot, local browsers, local npm, or any user-device filesystem for this repository.
   - Do not ask the user to run local commands for routine validation.
   - If cloud validation is blocked by an external service, report the blocker and the last verified online state rather than falling back to local testing.
   - GitHub Pages may be used for deployed/public Web validation.

2. **Keep the runtime cross-platform.**
   - Core combat, character, skill, package, and decision logic must not depend on desktop-only APIs.
   - Input must be represented as actions/intent rather than hard-wired device assumptions.
   - Creator tooling may be PC/Web-first, but runtime data formats must remain portable.

3. **Use data-driven content.**
   - Characters and skills must be defined by validated data/resources rather than one-off hard-coded character logic.
   - Adding a normal character or normal skill should not require edits to the combat engine.

4. **Player content must not execute arbitrary code.**
   - Character packages may contain validated structured data and approved assets.
   - Do not load or execute user-supplied GDScript, native libraries, executables, Python, shell scripts, or arbitrary code from character packages.

5. **AI/VFX providers must be replaceable.**
   - AI-assisted image/VFX generation must sit behind an adapter/provider boundary.
   - The game runtime must not depend on a specific cloud AI vendor.
   - Provider implementations must remain swappable at the architecture level.

6. **Regression protection is required.**
   - Bug fixes should add or strengthen an automated test when practical.
   - Do not merge known failing required online checks.

7. **Secrets never enter Git.**
   - No API keys, credentials, signing keys, private tokens, or confidential model credentials in source or history.
   - Use GitHub/hosting-provider secret stores or environment variables.

8. **Always provide the online test link when the user can test a deployed build.**
   - When a playable/testable Web build is deployed, every result/progress reply must include a directly usable test URL.
   - If no online build was deployed for the current step, say so explicitly.

9. **Every development result reply must report whole-project progress.**
   - Include current overall project phase/milestone, estimated total completion percentage, completed work, in-progress work, and remaining work.

10. **After every modification, report feature changes and the complete current control map.**
   - Include New / changed functionality.
   - Include Current controls / buttons covering every user-facing actionable input.

11. **Watch every required online validation run through terminal state before final reporting.**
   - After triggering or observing a GitHub Actions run, continue checking it until success, failure, cancellation, or a confirmed external blocker.
   - If a check fails, inspect logs, fix the issue, push the fix, and re-run/observe CI before declaring success.

12. **Prefer continuous multi-slice execution over stop-and-wait development.**
   - When several adjacent roadmap items can be completed safely in one coherent batch, continue through them without stopping after each small slice to ask the user to say “continue”.
   - A normal batch should include implementation, regression coverage, cloud validation, fixes, merge, documentation/status synchronization, and then the next adjacent slice when no real blocker exists.
   - Stop only for a genuine external dependency or decision that cannot be inferred safely, such as a missing secret/API credential, unavailable third-party service, destructive operation requiring explicit approval, or a materially ambiguous product decision.
   - Keep the user informed during long batches, but do not treat routine progress updates as approval gates.

## Required workflow for each development batch

1. Inspect current repository state and relevant code through GitHub.
2. State the intended batch scope and acceptance criteria.
3. Group adjacent coherent changes on a branch; do not fragment work into unnecessary micro-PRs.
4. Implement the batch with regression coverage.
5. Open/update a pull request.
6. Let GitHub Actions run the applicable automated validation.
7. Monitor every required workflow/job through terminal state.
8. Inspect online logs and fix failures before declaring success.
9. Merge only after required online checks pass, unless an external GitHub/service outage is explicitly documented as the blocker.
10. Continue into the next adjacent roadmap slice when it can be completed safely without new user input.
11. Record what changed, online checks run, failures, fixes, remaining risks, and unverified behavior.
12. Keep docs/roadmap synchronized when architecture or milestone scope changes materially.

## Online validation hierarchy

Use the highest applicable cloud-hosted level:

1. Pure logic/unit tests in GitHub Actions.
2. Godot headless project parse/import checks in GitHub Actions.
3. Godot headless integration/domain tests in GitHub Actions.
4. Web export in GitHub Actions.
5. Chromium browser smoke/E2E against the exported artifact in GitHub Actions.
6. Windows native export in GitHub Actions.
7. Microsoft Edge smoke/E2E on a GitHub-hosted Windows runner.
8. GitHub Pages/public deployment reachability when intentionally publishing a build.

Local validation is prohibited for this repository unless the user explicitly reverses this policy in a later instruction.

## Architecture boundaries

Preferred top-level structure:

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

Keep core rules independent from UI and rendering wherever practical.

## MVP priorities

1. Foundation and validation.
2. Combat feel prototype.
3. Data-driven skill engine.
4. Data-driven character system.
5. Creator Studio basics.
6. User VFX import and processing.
7. AI-assisted VFX provider layer.
8. Character package import/export.
9. Web MVP release.

## Reporting format

For every meaningful development result/progress reply, report succinctly and include:

- Project total progress.
- Completed.
- In progress.
- Remaining.
- New / changed functionality.
- Current controls / buttons.
- Validation: exact GitHub Actions workflow/jobs and terminal result.
- Errors/Fixes.
- Test link when an online build is available; otherwise state that no new online deployment was made.
- Next.

Do not report a test as passed without evidence from an executed online check. Do not use the user's local machine as a fallback validation environment.
