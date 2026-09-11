# Custom Fighter — MVP Plan & Technical Architecture

## Product thesis

Custom Fighter is a 2D side-scrolling action-fighting game with a built-in creator direction. The differentiator is not imitation of an existing title; it is the combination of:

- responsive 2D arena combat,
- player-created characters,
- data-driven skills,
- player-provided VFX assets,
- future image-assisted AI VFX generation,
- portable character packages,
- a shareable creator ecosystem.

## MVP success criterion

A new user should eventually be able to complete this loop without writing code:

```text
Open Creator
→ create a character
→ choose/create a skill
→ provide/import a fireball or sword-formation visual
→ configure timing/damage/MP/cooldown
→ preview the effect
→ save the character
→ enter Training
→ cast the skill
→ hit a target
```

If that loop is reliable and enjoyable, the core product value is proven.

## Platform strategy

### MVP

- Web: primary online test and share target.
- Windows: native desktop build target.

### Later

- Android.
- iOS/iPadOS.

The runtime core must remain platform-neutral from the beginning. Creator Studio can be PC/Web-first because advanced timeline/hitbox editing is better suited to larger screens.

## Technology

- Engine: Godot 4.7.2 stable.
- Language: GDScript.
- Rendering baseline: GL Compatibility for broad Web/device coverage.
- Source control: GitHub.
- CI: GitHub Actions.
- Web deployment: GitHub Pages.
- Browser smoke/E2E: Playwright.

## Architecture

### Runtime

Responsible for gameplay only:

- character state/movement,
- combat resolution,
- hit/hurt boxes,
- skills,
- projectiles,
- status effects,
- AI opponents,
- stages/game modes,
- package loading.

### Creator Studio

Responsible for authoring and previewing player content:

- character editor,
- skill editor,
- animation/VFX editor,
- timelines/events,
- validation,
- training preview,
- package import/export.

### AI/VFX adapter layer

AI generation is outside the runtime and behind an adapter boundary:

```text
Creator UI
  → AI/VFX Provider Adapter
      → Local provider (future ComfyUI/open model)
      → Cloud provider (optional)
  → Asset Processor
  → Sprite/VFX asset
  → Skill definition
```

The game must continue to run without AI availability.

## Data-driven skill model

Normal skills should be assembled from reusable templates/events instead of bespoke code per skill.

Initial template families:

1. Melee.
2. Projectile.
3. Dash attack.
4. Area attack.
5. Rain / formation.
6. Buff.

Future additions can include summon, grab, counter, teleport, trap, beam, aura, and scripted event compositions without allowing arbitrary user code.

Typical skill fields:

```text
id
name
type
damage
mp_cost
cooldown
startup
active
recovery
speed
range
hitstun
knockback
visual
impact_visual
```

Later skills can use an event timeline:

```text
0.00 cast starts
0.20 magic circle appears
0.50 projectiles spawn
1.20 projectiles launch
1.50 impact VFX
```

## Player content security

Character packages may eventually include:

- manifest JSON,
- character/skill definitions,
- images/sprite sheets,
- approved audio,
- metadata.

They must not execute user-supplied scripts, binaries, native libraries, or arbitrary code.

## Balance strategy

Sandbox/single-player can permit relaxed limits. Competitive modes should use a validated power budget and server/host-authoritative rules rather than trusting player-authored damage/cooldown values.

## Milestones

### M0 — Foundation

- Repository and architecture docs.
- Minimal Godot project.
- Headless project validation.
- Automated logic tests.
- Web export.
- Browser smoke test.
- GitHub Pages deployment workflow.

### M1 — Combat Prototype

- 2.5D arena movement.
- run/jump/dash.
- basic attack/chain.
- defense.
- HP/MP.
- hit/hurt boxes.
- hitstun/knockback/knockdown.
- training dummy.

Acceptance: browser build feels like an actual playable action prototype, not only a technical demo.

### M2 — Skill Engine

- SkillDefinition.
- melee/projectile/area/dash/formation/buff templates.
- startup/active/recovery timing.
- MP/cooldown.
- VFX/audio/gameplay events.

Acceptance: a normal new skill can be added from data without editing combat engine code.

### M3 — Character System

- CharacterDefinition.
- stats.
- animation mapping.
- skill slots/loadouts.
- 2–3 reference characters.

Acceptance: a normal character can be added from content data without editing core combat code.

### M4 — Creator Studio

- character editor.
- skill editor.
- parameter validation.
- preview/training room.

Acceptance: a non-programmer can create a basic character and skill.

### M5 — VFX Creator

- PNG/sprite-sheet import.
- crop/scale/offset/FPS.
- preview.
- VFX binding to skills.

Acceptance: a player's own image sequence can become an in-game skill effect.

### M6 — AI-assisted VFX

- reference image input.
- prompt/skill description.
- provider adapter.
- generated frames/sprite processing.
- preview/regenerate workflow.

Acceptance: a reference image can become a usable skill VFX without coupling the runtime to a specific AI service.

### M7 — Character Packages

- export/import.
- schema/version validation.
- unsafe-file rejection.

Acceptance: one user can create a character package and another can load it safely.

### M8 — MVP Release

- Web release.
- Windows build.
- basic documentation.
- stable creator-to-training loop.

## Testing strategy

Routine validation happens online:

1. GDScript/project import check.
2. Pure logic tests.
3. Godot headless integration tests.
4. Web export.
5. Playwright browser startup check.
6. GitHub Pages deployment for human feel/UX checks.

Local user testing is a last resort, not the default workflow.
