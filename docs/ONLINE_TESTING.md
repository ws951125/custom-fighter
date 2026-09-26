# Online Testing

Project validation is GitHub-only. Engineering checks must run through GitHub Actions and GitHub Pages; the user's local computer is not a validation environment for this repository.

## Pull requests

Every pull request should run the `CI` workflow and validate:

1. Godot 4.7.2 setup on a GitHub-hosted runner.
2. Headless project import.
3. Headless boot of the main scene.
4. Domain/data tests.
5. Web export.
6. Real Chromium startup using Playwright.
7. Windows Microsoft Edge smoke on a GitHub-hosted Windows runner when applicable.
8. Upload of the resulting Web artifact.

A PR is not considered validated merely because files were created successfully.

## Main branch

A successful push to `main` repeats validation and then uploads the same successful Web build to GitHub Pages.

Expected public URL after Pages is enabled:

`https://ws951125.github.io/custom-fighter/`

## Human testing

When subjective feedback is required (combat feel, animation timing, UI size, mobile touch comfort), use the deployed GitHub Pages Web build. Do not request local Godot/Windows project testing, local command execution, or local repository setup. Do not use Remote Desktop Commander or any other remote connection to the user's computer.

If a behavior cannot currently be validated through GitHub Actions or the deployed GitHub Pages build, record it as blocked or residual risk until a GitHub-hosted validation path exists.

## Evidence

When reporting a development step, record the relevant GitHub workflow status and any error/fix history. Never report a check as passed unless GitHub Actions or GitHub Pages actually executed the validation and produced that evidence.

## PR-only Creator Gallery visual evidence

When Creator Gallery code is on an unmerged PR and a separate no-charge interactive preview is unavailable, the Chromium test may capture bounded **mock-API** screenshots for human layout review. The PR-only workflow uploads a short-retention `creator-gallery-visual-evidence` screenshot bundle (including the import-confirmation dialog) and a standalone `03-publication-details.png` artifact that a GitHub-signed-in reviewer can open in a browser. These screenshots are not production catalogue or interactive UX acceptance; they do not imply that the PR is deployed to GitHub Pages. The real production Pages site remains main-only, no other project/site is overwritten, and actual manual interaction remains a separate gate before merge.
