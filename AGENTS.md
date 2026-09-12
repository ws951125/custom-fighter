# AGENTS.md

## Purpose

This repository is developed as a cloud-first, CI-first Godot project. The default expectation is that an agent changes code, validates it online, records evidence, and only asks the user for manual testing when the behavior cannot reasonably be verified in CI or in the deployed Web build.

## Non-negotiable rules

1. **Do not require routine local testing from the user.**
   - Prefer GitHub Actions, Godot headless execution, automated tests, Web export, and browser smoke tests.
   - If human judgment is needed for feel/UX, provide a deployed Web URL whenever possible.
   - Ask for local testing only for a hardware/OS/platform-specific issue that cannot be reproduced online.

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
   - Local generation (for example, a future ComfyUI adapter) and cloud providers must be swappable.

6. **Regression protection is required.**
   - Bug fixes should add or strengthen an automated test when practical.
   - Do not merge known failing automated checks.

7. **Secrets never enter Git.**
   - No API keys, credentials, signing keys, private tokens, or confidential model credentials in source or history.
   - Use GitHub secrets/environments for future services.

8. **Always provide the online test link when the user can test a deployed build.**
   - When a playable/testable Web build is available, every result/progress reply must include a directly usable test URL.
   - Prefer the production GitHub Pages URL after `main` deployment has passed validation.
   - If a branch/preview URL is used, label it clearly as a preview and distinguish it from production.
   - If no testable online build exists yet, explicitly state that the test link is not available yet rather than silently omitting it.

9. **Every development result reply must report whole-project progress, not only the current slice.**
   - Include the current overall project phase/milestone.
   - Include an estimated total project completion percentage.
   - Include completed work at the project level.
   - Include in-progress work when applicable.
   - Include remaining / not-yet-completed work at the project level.
   - The percentage must be grounded in the M0-M8 roadmap and the actual completion of milestone scope; it is an engineering progress estimate, not a claim of exact elapsed effort.
   - Update the estimate when milestone scope or completion materially changes.

## Required workflow for each development step

1. Inspect current state and relevant existing code.
2. State the intended change and acceptance criteria.
3. Implement the smallest coherent change.
4. Run/trigger the relevant automated validation.
5. Inspect failures and fix them before declaring success.
6. Record:
   - what changed,
   - tests/checks run,
   - failures encountered,
   - fixes applied,
   - remaining risks or unverified behavior.
7. Keep docs/roadmap synchronized when architecture or milestone scope changes materially.

## Online validation hierarchy

Use the highest applicable level:

1. Pure logic/unit tests.
2. Godot headless project parse/import checks.
3. Godot headless integration tests.
4. Successful Web export.
5. Browser smoke/E2E checks against the exported build.
6. Deployed GitHub Pages build for human feel/UX validation.
7. Local/manual testing only if 1-6 cannot cover the issue.

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

1. Foundation and cloud validation.
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

- **Project total progress:** current roadmap milestone/phase and an estimated overall completion percentage.
- **Completed:** project-level milestones/slices already completed, including the work completed in the current step.
- **In progress:** the active milestone/slice, if any.
- **Remaining:** project-level milestones/slices that are not yet complete.
- **Validation:** exact automated checks and result.
- **Errors/Fixes:** any failure and how it was corrected.
- **Test link:** the directly usable deployed Web URL whenever a testable build exists; otherwise explicitly state that no online test link is available yet.
- **Next:** next highest-priority task.

Do not report only the current small task while omitting overall project status. Do not claim a test passed without evidence from an executed check or workflow.
