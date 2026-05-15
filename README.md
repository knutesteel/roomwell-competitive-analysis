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

Prereq: [git](https://git-scm.com/download/win) installed. The repo `knutesteel/roomwell-competitive-analysis` already exists on GitHub, so no GitHub CLI is needed.

```powershell
cd "C:\Users\knute\OneDrive\Documents\Claude\Projects\Massage Management Software\roomwell-competitive-analysis"
.\publish.ps1
```

The script initializes git locally (first run only), wires up the remote, commits, and pushes. The first push will prompt you to sign in to GitHub via your browser or Windows Credential Manager — that's expected.

After the **first** push, enable GitHub Pages once: repo **Settings → Pages → Source: "Deploy from a branch" → Branch: `main` / `root` → Save**. After that, every `publish.ps1` run updates the live site automatically.

## Themes captured

1. **Cost** — pricing, processing fees, add-on creep
2. **Complexity** — overwhelm, salon-first UX, learning curve
3. **Switching** — who's leaving what, who's going where
4. **Advice-seeking** — what solos recommend in advice threads

Verbatim quoting is a constraint — never paraphrased — because the exact wording is the asset for product and marketing decisions.
