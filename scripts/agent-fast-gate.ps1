param(
    [switch]$GitOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

function Invoke-NativeChecked {
    param([string]$FilePath, [string[]]$Arguments)
    Write-Host ("[run] " + $FilePath + " " + ($Arguments -join " "))
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath exited with code $LASTEXITCODE"
    }
}

$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or -not $repo) { throw "Not inside a Git repository." }
Set-Location $repo

$branch = "$(git branch --show-current)"
$branch = $branch.Trim()
$head = (git rev-parse HEAD).Trim()
Write-Host "=== Git snapshot ==="
Write-Host ("branch=" + $branch)
Write-Host ("HEAD=" + $head)
git status --short
if ($LASTEXITCODE -ne 0) { throw "git status failed." }

if ($branch) {
    git show-ref --verify --quiet ("refs/remotes/origin/" + $branch)
    if ($LASTEXITCODE -eq 0) {
        $counts = (git rev-list --left-right --count ("HEAD...origin/" + $branch)).Trim()
        Write-Host ("HEAD...origin/" + $branch + "=" + $counts)
    } else {
        Write-Host ("origin/" + $branch + "=not-found")
    }
}

if ($GitOnly) {
    Write-Host "FAST_GATE_RESULT=PASS (GitOnly)"
    exit 0
}

$changed = @()
$changed += @(git diff --name-only --diff-filter=ACMR HEAD)
$changed += @(git ls-files --others --exclude-standard)
$changed = @($changed | Where-Object { $_ } | Sort-Object -Unique)

foreach ($file in @($changed | Where-Object { $_ -match '\.ps1$' })) {
    $full = Join-Path $repo $file
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Error $_.Message }
        throw "PowerShell parse failed: $file"
    }
    Write-Host ("[pass] PowerShell parse: " + $file)
}

if (Get-Command node -ErrorAction SilentlyContinue) {
    foreach ($file in @($changed | Where-Object { $_ -match '\.(js|mjs|cjs)$' })) {
        if (Test-Path -LiteralPath (Join-Path $repo $file)) {
            Invoke-NativeChecked "node" @("--check", $file)
        }
    }
}

if (Get-Command python -ErrorAction SilentlyContinue) {
    foreach ($file in @($changed | Where-Object { $_ -match '\.py$' })) {
        if (Test-Path -LiteralPath (Join-Path $repo $file)) {
            Invoke-NativeChecked "python" @("-m", "py_compile", $file)
        }
    }
}

if (Test-Path "package.json") {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    $runner = "npm"
    if (Test-Path "pnpm-lock.yaml") { $runner = "pnpm" }
    elseif (Test-Path "yarn.lock") { $runner = "yarn" }
    $scriptNames = @($pkg.scripts.psobject.Properties.Name)
    foreach ($name in @("lint", "typecheck")) {
        if ($scriptNames -contains $name) {
            if ($runner -eq "yarn") { Invoke-NativeChecked "yarn" @($name) }
            else { Invoke-NativeChecked $runner @("run", $name) }
        }
    }
}

Write-Host "FAST_GATE_RESULT=PASS"
Write-Host "Note: run project-required affected tests/integration/Playwright separately according to AGENTS.md."
