# Online Testing

Routine project validation is intentionally cloud-first.

## Pull requests

Every pull request should run the `CI` workflow and validate:

1. Godot 4.7.2 setup.
2. Headless project import.
3. Headless boot of the main scene.
4. Domain/data tests.
5. Web export.
6. Real Chromium startup using Playwright.
7. Upload of the resulting Web artifact.

A PR is not considered validated merely because files were created successfully.

## Main branch

A successful push to `main` repeats validation and then uploads the same successful Web build to GitHub Pages.

Expected public URL after Pages is enabled:

`https://ws951125.github.io/custom-fighter/`

## Human testing

When subjective feedback is required (combat feel, animation timing, UI size, mobile touch comfort), use the deployed Web build first. Local Godot/Windows testing is only requested when the problem is specifically platform/hardware dependent and cannot be reproduced in the cloud/browser workflow.

## Evidence

When reporting a development step, record the relevant workflow status and any error/fix history. Never report a check as passed unless GitHub Actions or another actually executed validation produced that evidence.
