# Custom Fighter

A cross-platform 2D action-fighting game and creator platform built with Godot 4.7.2. The production-validated MVP supports player-created characters, data-driven skills, custom VFX, character package export/import, Creator-to-Training preview and AI-assisted VFX through a replaceable provider boundary.

## Try the MVP

- **Training / game:** https://ws951125.github.io/custom-fighter/
- **Creator Studio:** https://ws951125.github.io/custom-fighter/?mode=creator
- **VFX Creator:** https://ws951125.github.io/custom-fighter/?mode=vfx
- **Release & usage guide:** [`docs/RELEASE.md`](docs/RELEASE.md)

The primary MVP targets are Web and Windows x86_64. The Windows native bundle is produced by the repository's successful `main` CI run as the `custom-fighter-windows-x86_64` artifact.

## Project direction

- **Engine:** Godot 4.7.2 stable
- **Language:** GDScript
- **Primary MVP targets:** Web + Windows
- **Future targets:** Android + iOS
- **Development model:** public, CI-first, GitHub-hosted validation
- **Creator direction:** PC/Web-first creator tools; runtime designed for cross-platform play

## What the MVP can do

- 2.5D movement and combat with run, jump, dash, guard, basic attack and six skill slots.
- Data-driven melee, projectile, area, dash, formation and buff skill templates.
- Creator Studio for character and skill authoring without editing source code.
- VFX Creator for PNG/sprite-strip import, crop/frame/FPS/scale/offset authoring and runtime binding.
- Provider-neutral AI-assisted VFX generation workflow.
- Versioned character package JSON export/import with optional self-contained Skill 1 VFX.
- Creator → package → fresh-session import → Training preview flow.
- Mobile Web touch controls.
- Automated Web, Chromium, Microsoft Edge and Windows native release validation.

## Roadmap status

**M0–M8 MVP roadmap complete — 100% (9/9 milestones).**

Milestone 8 — MVP Release is production-validated. The Web release, Windows x86_64 build, release documentation and stable Creator → package → fresh-session import → Training acceptance flow have all passed GitHub-hosted validation, including main CI Run #169 after PR #81 merged to `main`.

## Online-first validation policy

Routine engineering validation happens on GitHub-hosted infrastructure. CI runs Godot import/boot and domain tests, Web export and size-budget checks, Chromium and hosted Microsoft Edge smoke suites, Windows x86_64 native export/smoke, GitHub Pages deployment/public reachability and a production Edge real-game flow. The user's local computer is not required for project validation.

See [`AGENTS.md`](AGENTS.md), [`docs/MVP.md`](docs/MVP.md), [`docs/STATUS.md`](docs/STATUS.md) and [`docs/RELEASE.md`](docs/RELEASE.md) for working rules, roadmap, current status and release usage.
