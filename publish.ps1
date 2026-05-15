# publish.ps1 - RoomWell Competitive Analysis
# Pushes this folder to the GitHub repo (which already exists).
# Requirements: git installed. First push will prompt for GitHub sign-in
# via your browser / Windows Credential Manager - that's normal.
#
# Note: this script deliberately does NOT use $ErrorActionPreference = "Stop".
# git writes routine progress to stderr, which "Stop" mode misreads as fatal.
# Instead we check $LASTEXITCODE where it actually matters.

$repoUrl = "https://github.com/knutesteel/roomwell-competitive-analysis.git"
Set-Location $PSScriptRoot

# 1. Verify git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'git' is not installed or not on PATH." -ForegroundColor Red
    Write-Host "Install from: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# 2. Initialize repo if needed
if (-not (Test-Path ".git")) {
    Write-Host "==> Initializing git repo..." -ForegroundColor Cyan
    git init
    git branch -M main
}

# 3. Ensure the remote is set. `git remote` lists remotes and returns
#    empty (no error) when there are none - safe to inspect.
$remotes = @(git remote)
if ($remotes -notcontains "origin") {
    Write-Host "==> Adding remote origin..." -ForegroundColor Cyan
    git remote add origin $repoUrl
}

# 4. Stage everything
Write-Host "==> Staging files..." -ForegroundColor Cyan
git add -A

# 5. Bail if nothing changed
if (-not (git status --porcelain)) {
    Write-Host "==> Nothing to commit. Working tree clean." -ForegroundColor Green
    exit 0
}

# 6. Commit
$commitMsg = "Site update $(Get-Date -Format 'yyyy-MM-dd')"
Write-Host "==> Committing: $commitMsg" -ForegroundColor Cyan
git commit -m $commitMsg

# 7. Push
Write-Host "==> Pushing to origin/main..." -ForegroundColor Cyan
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: push failed. If you were prompted to sign in, complete it and re-run." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==> Done." -ForegroundColor Green
Write-Host "    Repo:  https://github.com/knutesteel/roomwell-competitive-analysis" -ForegroundColor Green
Write-Host "    Pages: https://knutesteel.github.io/roomwell-competitive-analysis/" -ForegroundColor Green
Write-Host ""
Write-Host "    If this is the FIRST push, enable GitHub Pages once:" -ForegroundColor DarkGray
Write-Host "    Settings > Pages > Source: 'Deploy from a branch' > Branch: main / root > Save" -ForegroundColor DarkGray
