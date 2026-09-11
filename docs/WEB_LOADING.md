# Web Loading Strategy

## Current baseline

Measured from the `main` Web artifact before this optimization slice:

- `index.wasm`: 39,514,754 bytes
- `index.pck`: 30,968 bytes
- Total unpacked Web output: 39,880,338 bytes

The current loading cost is therefore dominated by the Godot WebAssembly runtime, not game content.

## Immediate policy

1. Keep release exports (`--export-release`).
2. Enable PWA/service-worker caching so repeat visits can reuse engine assets.
3. Enforce CI size budgets for WASM, PCK, and total Web output.
4. Log browser startup time and transferred Web resources during smoke tests.
5. Keep the core PCK small while the game is still in prototype stage.

## Build-size budgets

The first guard rails are intentionally above the current baseline:

- WASM: 42,000,000 bytes maximum
- PCK: 1,000,000 bytes maximum
- Total Web output: 44,000,000 bytes maximum

These are regression budgets, not final performance targets.

## Future asset splitting

Large creator-generated content must not be bundled into the core startup PCK. Future content is separated conceptually into packages:

- core runtime: engine-facing code and the minimum startup UI
- official character packages
- stage packages
- VFX packages
- user-generated character / skill packages

The runtime should fetch or import those packages only when needed. This prevents future character sprites, audio, AI-generated VFX, and stages from turning the first page load into a hundreds-of-megabytes download.

## Later optimization: stripped Godot Web template

A custom Godot Web export template can remove unused engine modules and reduce the fixed WASM cost. That work is deliberately separate because it requires maintaining a custom engine build pipeline and has a larger compatibility surface than normal project changes.
