# CP-SAT (Google OR-Tools)

## What it is

CP-SAT is Google [OR-Tools](https://developers.google.com/optimization)' constraint programming solver — a hybrid of CP (constraint propagation) and SAT (boolean satisfiability) search techniques, exposed with official language bindings including C#/.NET via the `Google.OrTools` NuGet package.

## Why it's relevant to room-solver (new, added 2026-08-16 as part of the Revit-native pivot)

Under the Revit pivot's "single in-process, signed add-in DLL, no subprocess" constraint (see [[Revit]]), the solver has to be a managed .NET library with no native sidecar. `Google.OrTools` ships official C# bindings, so CP-SAT can run **fully in-process** — this is the one significant difference from [[Prolog]]/Clingo, which both currently require an external native runtime and are BLOCKED under the worst-case lockdown assumption.

## How it models the room-layout problem

Rooms are modeled as 2D interval variables:

- Each room `i` gets `(x_start, x_size, x_end)` and `(y_start, y_size, y_end)`, with `x_size`/`y_size` bounded by min/max dimension constraints from the room program.
- A global `NoOverlap2D([x_intervals], [y_intervals])` constraint enforces non-overlap across all rooms at once.
- Adjacency is modeled with reified booleans: `b_left`, `b_right`, `b_below`, `b_above` per room pair, each with `OnlyEnforceIf` (e.g. `x_i_end == x_j_start` reified on `b_ij_left`), with `b_left + b_right + b_below + b_above >= 1` forcing at least one contact direction where adjacency is required.
- This is native to continuous/high-resolution dimensional packing — a good fit for architectural rooms with real min/max square-footage constraints, not just discrete-tile adjacency.

## Open design question: does CP-SAT replace WFC's "collapse" step?

This is the question Gavin raised directly and it's carried into the design doc rather than resolved here — see the design doc's reasoning. In short, the tension is:

- **WFC's collapse** is a random walk: pick lowest-entropy cell, weighted-random pick a tile, propagate, repeat. Non-deterministic by design (weighted randomness gives organic-feeling variety), but that same non-determinism is friction in a lock/re-solve UI where an architect expects explainability and (arguably) repeatability given the same locks.
- **CP-SAT** can, in principle, replace random collapse with an actual objective function (`Maximize`/`Minimize` over placement/adjacency terms) or exhaustively evaluate what's feasible at a given cell rather than guessing-and-backtracking. Since CP-SAT is already in-process for dimensional packing, it's available for this without adding a new dependency.
- Candidate designs: (a) pure stochastic WFC as before, CP-SAT unused for collapse; (b) pure CP-SAT — treat the whole layout as one CP-SAT model with locked cells as fixed constraints, no WFC loop at all; (c) hybrid — WFC-style local propagation for interactive speed/preview, CP-SAT as the source of truth for "what's actually possible at this cell" (i.e. CP-SAT computes the true remaining domain, WFC's propagate step becomes redundant/a fast-path approximation of it); (d) CP-SAT with an objective function entirely replacing random collapse, keeping WFC-style propagation for adjacency-only cases where CP-SAT would be overkill.

## Key gotchas

- CP-SAT is an optimization/feasibility solver, not inherently a *sampling* one — getting WFC's "organic variety across re-solves" behavior out of it (if that's still wanted) means either re-seeding with randomized objective tie-breaks or accepting more deterministic output as an explicit UX trade-off, per the design doc.
- CP-SAT doesn't guarantee reachability/connectivity (no inherent egress-path constraint) any more than WFC does — pair it with the connectivity-repair (BFS/MST over the room-adjacency graph) pass described in [[WFC]], regardless of which collapse strategy wins.
- `NoOverlap2D` and reified-adjacency models scale in variable/constraint count with room count squared (all-pairs adjacency reification) — worth profiling at realistic floorplan sizes before assuming it's fast enough for a live re-solve-per-lock UI loop.

## References

- Google OR-Tools CP-SAT docs: https://developers.google.com/optimization/cp/cp_solver
- `Google.OrTools` NuGet package: https://www.nuget.org/packages/Google.OrTools
