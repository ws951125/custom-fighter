# Project Status

## Current phase

Milestone 0 — Foundation

## Completed

- Public GitHub repository initialized.
- Godot 4.7.2 project foundation.
- Minimal Web-ready runtime prototype.
- Data-driven sample skill definition.
- First combat-domain logic.
- Headless domain/data test runner.
- Web export preset.
- Playwright Chromium Web smoke test.
- GitHub Actions CI on pull requests and `main`.
- Web build artifact upload.
- GitHub Pages deployment workflow prepared.
- Cloud-first development and validation rules documented in `AGENTS.md`.

## Verified online

The automated pipeline has already verified the following successfully in GitHub-hosted runners:

- Godot installation/version check.
- Headless project import.
- Headless main-scene boot.
- Combat/data tests (`ALL_TESTS_PASSED`).
- Godot Web export.
- Real Chromium startup of the exported Web game (`WEB_SMOKE_PASSED`).
- Web artifact upload.

## Current infrastructure blocker

GitHub Pages has not yet been initialized for this repository. The workflow attempted to initialize it automatically, but GitHub rejected creation through the Actions integration with `Resource not accessible by integration`.

One repository-admin setting is therefore required once:

`Settings → Pages → Build and deployment → Source → GitHub Actions`

This is a repository configuration step, not a local game test. After the Pages site exists, the existing workflow is already structured to publish the validated `build/web` output from `main`.

## Next milestone

Milestone 1 — Combat Prototype:

- 2.5D arena movement.
- run / jump / dash.
- basic attack chain.
- guard.
- HP / MP.
- hitbox / hurtbox.
- hitstun / knockback / knockdown.
- training dummy.
- browser-playable acceptance build.
