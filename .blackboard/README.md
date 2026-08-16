# Blackboard — Revit add-in implementation fan-out

This branch (`blackboard/revit-addin`) is coordination-only. It never carries product code and is never merged into `main` or any `feature/*` branch. See `docs/DESIGN.md` §8 on the `docs/revit-native-pivot` branch for the full rationale.

## Rules

1. **Append-only.** Every file here grows by appending new entries at the bottom of your own section (or a new timestamped line in a log file). Never edit or delete another agent's prior entries.
2. **One owning agent per interface** in `interfaces.md`. Mark your section `PROPOSED` when you post it, `ACCEPTED` once you know someone else is coding against it. Changing an `ACCEPTED` interface requires a note in `decisions.md` explaining what changed and who it affects.
3. **Check in often**: at slice start, at least once mid-slice, on any blocker (raised or resolved), and at slice completion. Don't wait until you're done to post anything.
4. **Product code never lands here.** Your actual implementation lives on your own `feature/revit-addin-<slice>` branch/worktree.
5. Before appending: `git fetch && git merge --ff-only origin/blackboard/revit-addin` (or rebase if it's diverged), then append, commit, push. Small frequent commits, not batched.

## Slices

| Slice | Branch | Owns |
|---|---|---|
| A — Add-in scaffold + async bridge + panel shell | `feature/revit-addin-scaffold` | Project/manifest scaffolding, `RevitTask`/`Revit.Async` wiring, modeless WPF panel shell, `IExternalEventHandler` plumbing |
| B — Geometry ingestion / grid model | `feature/revit-addin-ingestion` | `GetBoundarySegments` → grid/dual-graph conversion, void-cell handling, the shared `Cell`/`Grid` data model |
| C — WFC possibility-set engine | `feature/revit-addin-wfc-propagation` | Arc-consistency propagation producing the live per-cell possibility set |
| D — CP-SAT fill + connectivity repair | `feature/revit-addin-cpsat-fill` | `Google.OrTools` model, objective function, BFS/MST connectivity repair |
| E — Reification | `feature/revit-addin-reification` | `TransactionGroup`, Douglas-Peucker simplification, `JoinGeometryUtils` |

Files: `status.md` (progress log), `interfaces.md` (shared contracts), `decisions.md` (cross-slice decisions), `blockers.md` (raised/resolved).
