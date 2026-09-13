# Custom Fighter MVP — Release & Usage Guide

Custom Fighter is a Godot 4.7.2 action-fighting game and creator platform. The MVP is delivered as a hosted Web build and a reproducible Windows x86_64 CI artifact.

## Web entry points

- Training / game: https://ws951125.github.io/custom-fighter/
- Creator Studio: https://ws951125.github.io/custom-fighter/?mode=creator
- VFX Creator: https://ws951125.github.io/custom-fighter/?mode=vfx

The Web build is the primary zero-install way to try the MVP. Current CI validates it in Chromium and Microsoft Edge, deploys it through GitHub Pages and checks the public production URL after each accepted main-branch change.

## Windows build

The native Windows release is produced by GitHub Actions from the same repository revision as the Web release.

1. Open the repository's latest successful `CI` workflow run on `main`.
2. In the workflow artifacts, download `custom-fighter-windows-x86_64`.
3. Extract the full archive to one directory.
4. Keep `CustomFighter.exe` and `CustomFighter.pck` together.
5. Run `CustomFighter.exe`.

The CI pipeline exports with Godot 4.7.2 and performs a bounded headless native launch smoke before the artifact is accepted. Windows artifacts are CI artifacts, not a signed installer; Windows may therefore show normal warnings for unsigned software.

## Creator → package → Training flow

A basic MVP creation flow is:

1. Open **Creator Studio**.
2. Configure the character and Skill 1 values.
3. Optionally create/import Skill 1 VFX in **VFX Creator** and bind it to the character.
4. Export the character package JSON.
5. In another fresh browser context/session, open Creator Studio and import that package.
6. Confirm the imported character, skill values and optional embedded VFX are restored.
7. Start the Creator preview / Training flow.
8. Cast the authored skill and confirm the imported runtime behavior is active.

Current package exports use schema v2. A package may embed one validated Skill 1 PNG/sprite-strip VFX asset. Legacy schema-v1 packages without embedded VFX remain supported. Package import is allow-listed and fail-closed; executable scripts, native binaries, arbitrary resource paths, external URLs and archive extraction are outside the package contract.

## Controls and mobile

The current gameplay supports movement/run, jump, basic attack, dash, guard and Skill 1–6. Touch-capable Web sessions expose corresponding mobile controls. `?mobile_controls=1` can force the mobile HUD on for validation and `?mobile_controls=0` can force it off.

## Automated release acceptance

All routine release validation stays on GitHub-hosted infrastructure. Required gates include:

- Godot project import and main-scene boot,
- domain tests,
- Web export and size budget,
- Chromium `smoke:all`,
- GitHub-hosted Windows Microsoft Edge `smoke:all`,
- Windows x86_64 native export and bounded executable smoke,
- GitHub Pages deployment and public reachability,
- production Microsoft Edge real-game flow.

`smoke:all` includes the self-contained Creator package VFX regression (`creator_package_vfx_web_smoke.mjs`), which proves schema-v2 export, embedded VFX, import in a second browser session, transition to Training, runtime VFX loading and an actual cast.

## Current MVP boundaries

The MVP intentionally prioritizes a stable creation-and-testing loop over a complete commercial game. Future roadmap work can expand platforms, content, networking, distribution/signing and production AI-provider integrations without weakening the current package validation or CI release gates.
