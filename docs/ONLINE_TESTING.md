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

## Same-origin Gallery preview package (proposed infrastructure)

A dedicated PR may attach a validated, SHA-pinned PR Web artifact into the existing main Pages deployment under `/preview/pr-212/`, **not** overwrite the root `index.html` or launch external hosting. The preflight contract is `node tests/pages_preview_contract_test.mjs` in GitHub Actions, which verifies script syntax, exact SHA gating, preservation of main root and fail-closed behavior for missing/mismatched artifacts. Main-push Pages validation must additionally confirm public `index.html`, `index.js` and `preview-source.txt` on that subpath when it was attached. An expired or unavailable preview artifact must not break a production main release. This workflow does not enable a real sharing backend or provide a mock-provider interactive catalogue; screenshots from PR #212 are explicitly mock-only.

Do not deploy unmerged #212 by replacing the production Pages root. Do not enable a billed third-party preview host. The preview infrastructure PR and Gallery PR require separate explicit merge approval after applicable checks and human acceptance.
