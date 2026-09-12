# AGENTS.md

## Purpose

This repository is developed as a GitHub-only, CI-first Godot project. The default expectation is that an agent changes code, validates it through GitHub Actions and GitHub Pages, records evidence, and never connects to or uses the user's local computer as a project validation path.

## Non-negotiable rules

1. **All engineering validation must remain on GitHub.**
   - Use GitHub Actions, Godot headless execution, automated tests, Web export, GitHub-hosted browser smoke tests, and GitHub Pages.
   - GitHub-hosted Windows runners may be used for Microsoft Edge validation.
   - If human judgment is needed for feel/UX, provide a deployed GitHub Pages URL whenever possible.
   - Do not ask for local project testing, local command execution, local Git operations, or local build evidence.
   - Do not use Remote Desktop Commander, remote desktop, SSH to the user's computer, or any other local-machine proxy for this repository.
   - If GitHub validation is unavailable, report the item as blocked rather than bypassing the gate locally.

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
   - Local generation (for example, a future ComfyUI adapter) and cloud providers must be swappable at the architecture level; this does not authorize local validation of this repository.

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

10. **After every modification, explicitly report both feature changes and the complete current control map.**
   - Every development result/progress reply after a code/content/configuration change must include a **New / changed functionality** section that lists the capabilities added, changed, removed, or intentionally preserved in that step.
   - Every such reply must also include a **Current controls / buttons** section covering every currently available user-facing button, keyboard key, mouse/touch control, or other actionable input in the playable/testable build, not only inputs changed in that step.
   - For each control, state what action it triggers and what the action does in gameplay or tooling.
   - If a control is contextual, disabled, reserved, or currently diagnostic-only, say so explicitly.
   - Keep this control map synchronized as controls are added, removed, remapped, or change semantics.
   - If the current build has no actionable UI buttons beyond keyboard/game inputs, say that explicitly rather than omitting the section.

## Required workflow for each development step

1. Inspect current state and relevant existing code.
2. State the intended change and acceptance criteria.
3. Implement the smallest coherent change.
4. Run/trigger the relevant GitHub-hosted automated validation.
5. Inspect failures and fix them before declaring success.
6. Record:
   - what changed,
   - tests/checks run,
   - failures encountered,
   - fixes applied,
   - remaining risks or unverified behavior.
7. Keep docs/roadmap synchronized when architecture or milestone scope changes materially.
8. After every modification, enumerate the newly added/changed functionality and the complete current user-facing control/button map.

## Online validation hierarchy

Use the highest applicable GitHub-hosted level:

1. Pure logic/unit tests in GitHub Actions.
2. Godot headless project parse/import checks in GitHub Actions.
3. Godot headless integration tests in GitHub Actions.
4. Successful Web export in GitHub Actions.
5. Chromium browser smoke/E2E against the exported build on a GitHub-hosted runner.
6. Microsoft Edge browser smoke on a GitHub-hosted Windows runner when applicable.
7. Deployed GitHub Pages build for public reachability and human feel/UX validation.

There is no local/manual repository-testing fallback. If levels 1-7 cannot cover an issue, record it as blocked or residual risk until a GitHub-hosted validation path exists.

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
- **New / changed functionality:** capabilities added, modified, removed, or intentionally preserved by the latest modification.
- **Current controls / buttons:** every current user-facing actionable input and the action/purpose it triggers, including contextual or diagnostic-only controls.
- **Validation:** exact GitHub Actions / GitHub Pages checks and result.
- **Errors/Fixes:** any failure and how it was corrected.
- **Test link:** the directly usable deployed Web URL whenever a testable build exists; otherwise explicitly state that no online test link is available yet.
- **Next:** next highest-priority task.

Do not report only the current small task while omitting overall project status. Do not claim a test passed without evidence from an executed GitHub-hosted check or workflow.
