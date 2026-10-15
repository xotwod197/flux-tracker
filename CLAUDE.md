# CLAUDE.md — Flux project notes

**Read this first.** This file is the hand-off between work sessions on different machines and
different Claude accounts. It holds what Flux is, where things live, the rules Ramiro has set,
and a dated log of every change. **At the end of any session that changes Flux, add an entry to
the Changelog below and commit it with the change.** Keep it short and factual.

This repo is public — never put passwords, share paths with server names, or anything
company-internal in here.

---

## What Flux is

Self-hosted personal task tracker. One HTML file (`Flux-Tracker.html`) served by one
PowerShell script (`Start-Flux.ps1`) on `http://localhost:7789`. Data is a single
`flux-data.json` in a folder of the user's choosing (atomic writes, rotating backups, graceful
fallback if the folder is unreachable). Runs as a Chrome PWA (`--app=`) via a silent VBS launcher
and a scheduled task so it auto-starts at login.

Features: Dashboard (bento stat cards with sparklines), Kanban / List / Calendar views, task detail
sheet, subtasks, recurring tasks, tags with collapse, completion history, Pomodoro timer,
Comfy/Compact density toggle, light and dark mode.

Publicly it is referred to as **"Task App"** (on the portfolio site), not "Flux".

## Files

| File | Purpose |
|---|---|
| `Flux-Tracker.html` | The whole app — UI, logic, styling. Single self-contained file, no build step, no external dependencies. |
| `Start-Flux.ps1` | PS 5.1-compatible local server + JSON persistence. **The repo copy is the generic/public version** (`DataFolder` defaults to `Documents\Flux_Data`). Ramiro's personal install points at his own share — don't overwrite the repo copy with the personal one. |
| `Flux.vbs` / `Flux-AutoLaunch.vbs` | Silent launchers (start server, open the PWA). |
| `README.md` | Public README with the screenshot gallery. Update the gallery when the look changes. |
| `screenshots/` | 11 demo-data screenshots (`01-dashboard-light.png` … `11-collapsed-sidebar-dark.png`) used by the README. |
| `fluxdashboard.png` | Hero image at the top of the README. |

## Where things live (work PC)

- **Live install:** `C:\My Apps\Flux\` — this is what actually runs. Older looks kept beside it as
  `Flux-Tracker-BEFORE-TERMINAL.html`, `Flux-Tracker-TERMINAL.html`, `Flux-Tracker-IOS.html`.
- **Git clone:** `C:\Users\rherrera\github\flux-tracker\` — kept separate from the install.
- **Workflow:** edit/test in `C:\My Apps\Flux\Flux-Tracker.html` → copy it into the clone →
  `git add -A; git commit; git push` with the git CLI.
- Two Claude accounts are used (work + home). Neither can see the other's chat history — this
  file is the shared memory.

## Rules and preferences

- Keep it **one HTML file**, no frameworks, no CDNs, works offline.
- `Start-Flux.ps1` must stay **PowerShell 5.1 compatible**.
- Current look is **macOS-style** (not iPhone/iOS): Plus Jakarta Sans, system grays, glass chrome,
  Apple/SwiftUI-style spring motion on buttons, hover and view changes. Don't drift back to the
  mint theme, the terminal look, or the iOS look — they're kept only as backups.
- Features and behaviour stay the same across redesigns; a restyle is a restyle.
- Flux is usually open on the **right half** of a vertical monitor, with another tool on the left.
  The UI has to show everything at that width without cramming.
- Before replacing the live file, keep the previous version as a `Flux-Tracker-<LOOK>.html`
  backup in `C:\My Apps\Flux`.
- Screenshots in the repo use **demo data only** — nothing real.

## Changelog (newest first)

### 2026-10-15
- **macOS redesign** (`9b55983`): Apple-style spring motion, Back/Dashboard navigation,
  README rebuilt with an 11-image screenshot gallery (`screenshots/`), new `fluxdashboard.png`.
  Replaced the iOS look from the day before. Features unchanged.
- Added this `CLAUDE.md`.

### 2026-10-14
- **iOS redesign**: Plus Jakarta Sans, system colors, glass chrome, segmented controls, splash
  screen. (Superseded by the macOS look the next day; kept as `Flux-Tracker-IOS.html` locally.)
- **Terminal redesign** earlier the same day: bento dashboard, sparklines, Comfy/Compact density
  toggle, boot-sequence splash. The bento dashboard, sparklines and density toggle carried
  forward into the later looks; the terminal styling did not.
- Removed a duplicate HTML file and refreshed `fluxdashboard.png`.

### 2026-07-02 and earlier
- Apr–Jul 2026: original mint-theme build, several "Add files via upload" revisions of
  `Flux-Tracker.html`, LICENSE added. (Pre-dates this file; details not recorded.)

## Open items

- None recorded. Add here anything half-finished so the next session can pick it up.
