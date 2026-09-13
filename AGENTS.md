# AGENTS.md

## Purpose

This repository is developed as a local-validation-first Godot project. The default expectation is that an agent changes code in GitHub, validates it on the user's connected Windows machine through Remote Desktop Commander, records evidence, and uses GitHub Actions only when explicitly requested or when a cloud-only validation step is required.

## Non-negotiable rules

1. **Primary engineering validation is local through Remote Desktop Commander.**
   - Use the connected Windows machine for Godot headless import/boot, automated tests, Web export, browser smoke tests, and Windows native export/smoke when practical.
   - Remote Desktop Commander is authorized for this repository.
   - Do not ask the user to manually execute commands when the agent can run them remotely.
   - GitHub Actions is no longer the default validation path; keep it manual-only unless the user explicitly re-enables automatic CI.
   - GitHub Pages may still be used for deployment/public URL checks when a deployment is intentionally performed.

2. **Keep the runtime cross-platform.**
   - Core combat, character, skill, package, and decision logic must not depend on desktop-only APIs.
   - Input must be represented as actions/intent rather than hard-wired device assumptions.
   - Creator tooling may be PC/Web-first, but runtime data formats must remain portable.

3. **Use data-driven content.**
   - Characters and skills must be defined by validated data/resources rather than by one-off hard-coded character logic.
   - Adding a normal character or normal skill should not require edits to the combat engine.

4. **Player content must not execute arbitrary code.**
   - Character packages may contain validated structured data and approved assets.
   - Do not load or execute user-supplied GDScript, native libraries, executables, Python, shell scripts, or arbitrary code from character packages.

5. **AI/VFX providers must be replaceable.**
   - AI-assisted image/VFX generation must sit behind an adapter/provider boundary.
   - The game runtime must not depend on a specific cloud AI vendor.
   - Local generation and cloud providers must remain swappable at the architecture level.

6. **Regression protection is required.**
   - Bug fixes should add or strengthen an automated test when practical.
   - Do not merge known failing automated checks.

7. **Secrets never enter Git.**
   - No API keys, credentials, signing keys, private tokens, or confidential model credentials in source or history.
   - Use environment variables or external secret stores for future services.

8. **Always provide the online test link when the user can test a deployed build.**
   - When a playable/testable Web build is deployed, every result/progress reply must include a directly usable test URL.
   - If no online build was deployed for the current step, say so explicitly.

9. **Every development result reply must report whole-project progress, not only the current slice.**
   - Include the current overall project phase/milestone.
   - Include an estimated total project completion percentage.
   - Include completed, in-progress, and remaining work.
   - Update the estimate when milestone scope or completion materially changes.

10. **After every modification, explicitly report both feature changes and the complete current control map.**
   - Include a New / changed functionality section.
   - Include a Current controls / buttons section covering every current user-facing actionable input.

11. **Watch every started validation process through completion before final reporting.**
   - After starting any local validation process, continue checking it until terminal state before final reporting.
   - If a process fails, inspect, fix, and re-run before declaring success.
   - If blocked by an external dependency, report the blocker and last verified state.

## Required workflow for each development step

1. Inspect current state and relevant existing code.
2. State the intended change and acceptance criteria.
3. Implement the smallest coherent change.
4. Sync/checkout the target branch on the connected Windows machine.
5. Run the relevant local automated validation through Remote Desktop Commander.
6. Continue monitoring all local validation processes until terminal state.
7. Inspect failures and fix them before declaring success.
8. Record what changed, tests/checks run, failures, fixes, remaining risks, and unverified behavior.
9. Keep docs/roadmap synchronized when architecture or milestone scope changes materially.
10. After every modification, enumerate new/changed functionality and the complete current user-facing control/button map.

## Local validation hierarchy

Use the highest applicable local level:

1. Pure logic/unit tests.
2. Godot headless project parse/import checks.
3. Godot headless integration/domain tests.
4. Successful Web export.
5. Chromium/Edge browser smoke/E2E against the exported local build.
6. Windows native export and bounded executable smoke.
7. Optional GitHub Pages deployment/public reachability when intentionally publishing a build.

GitHub Actions is manual-only by default and is not required to declare a local development slice validated unless the user explicitly requests cloud CI evidence.

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

For every meaningful development result/progress reply, report succinctly and include the whole-project view:

- Project total progress.
- Completed.
- In progress.
- Remaining.
- New / changed functionality.
- Current controls / buttons.
- Validation: exact local commands/checks and result; identify any optional cloud checks separately.
- Errors/Fixes.
- Test link when an online build is available; otherwise state that no new online deployment was made.
- Next.

Do not report only the current small task while omitting overall project status. Do not claim a test passed without evidence from an executed local or explicitly requested cloud check.
