# RoomWell Competitive Analysis

Weekly listening sweep of what solo massage therapists are saying about the major booking and practice-management platforms — Vagaro, Mindbody, Acuity, Square Appointments, Jane, Noterro, ClinicSense, Schedulicity, and MassageBook.

**Live site:** https://knutesteel.github.io/roomwell-competitive-analysis/

## What's here

- `index.html` — Dashboard with the latest week's highlights, trends, and quote bank.
- `weeks/` — Per-week archive pages. New file each Monday.
- `data/` — Raw outputs: the CSV of findings (`*-findings.csv`) and the markdown source report (`*-report.md`).
- `assets/style.css` — Shared styling.
- `publish.ps1` — Local publish script. See below.

## How it updates

A scheduled task (`weekly-massage-software-listening`) runs every Monday morning. It:

1. Runs targeted web searches across Reddit, G2, Capterra, Trustpilot, Software Advice, BBB, and vendor forums.
2. Captures verbatim quotes with source URLs into a CSV.
3. Generates a themed markdown report.
4. Refreshes the HTML site files in this folder.
5. Commits and pushes to this repo.

Step 5 currently depends on `publish.ps1` being run on the host machine after generation. Run it manually each Monday, or wire it into Windows Task Scheduler.

## Publishing

**Primary workflow — GitHub Desktop.** The repo is already added to GitHub Desktop. After the weekly scheduled task regenerates the site files:

1. Open GitHub Desktop and select the `roomwell-competitive-analysis` repository.
2. Review the changed files in the Changes tab.
3. Type a commit summary, click **Commit to main**.
4. Click **Push origin**.

The live site updates within a minute or two.

**Scriptable fallback.** `publish.ps1` (and the `run-publish.bat` double-click launcher) do the same thing from the command line — init/remote/add/commit/push — if you'd rather not open the GUI. Requires [git](https://git-scm.com/download/win) installed.

GitHub Pages is already enabled (Settings → Pages → `main` / `root`), so no one-time setup is needed anymore.

## Themes captured

1. **Cost** — pricing, processing fees, add-on creep
2. **Complexity** — overwhelm, salon-first UX, learning curve
3. **Switching** — who's leaving what, who's going where
4. **Advice-seeking** — what solos recommend in advice threads

Verbatim quoting is a constraint — never paraphrased — because the exact wording is the asset for product and marketing decisions.
