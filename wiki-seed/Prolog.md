# Prolog / CLP(FD)

## What it is

Prolog is a logic-programming language: you declare facts and rules, and the runtime searches for variable assignments (via unification and backtracking) that satisfy them. **CLP(FD)** ("Constraint Logic Programming over Finite Domains") is a Prolog extension/library (available in SWI-Prolog, GNU Prolog, and others) that adds first-class support for declaring variables with finite integer domains and constraints between them (`X #= Y + 1`, `all_different/1`, etc.), with efficient constraint propagation baked into the runtime instead of relying on Prolog's plain backtracking search.

## Why it's relevant to room-solver

[[WFC]] *is* a constraint satisfaction problem: each grid cell is a variable, its domain is the set of remaining tile/module options, and adjacency rules are binary constraints between neighboring variables. That's the exact problem shape CLP(FD) is built to solve, and its underlying propagation algorithms are close cousins of (and historically predate/generalize) the arc-consistency technique WFC's "propagate" step reimplements from scratch (see [[AC-3-CSP]]). This makes Prolog/CLP(FD) a legitimate **alternate constraint-solver core** to consider instead of hand-rolling (or depending on [[Monoceros]]'s bespoke implementation of) the collapse+propagate loop:

- Modeling: grid cells become `#Domain` finite-domain variables; module compatibility rules become CLP(FD) constraints; a solve is a single `labeling/2` (or similar) call.
- Locking a cell maps directly to unifying that variable with a fixed value before labeling — again, "add a constraint and re-solve from scratch" rather than incremental solver-state management, which is the same shape the project already committed to for the Grasshopper path.
- CLP(FD) solvers do genuine backtracking search with propagation, so they can find a satisfying assignment even in cases where WFC's simpler forward-only propagation would hit a dead end and need an ad-hoc restart-with-different-random-seed strategy.

## Tradeoffs vs. the Grasshopper-native approach

**In favor of Prolog/CLP(FD):**
- Battle-tested constraint propagation and search (decades of CSP-solver research), likely more robust against contradictions/dead-ends than WFC's typical restart-on-failure approach.
- Clean, declarative way to express architectural constraints beyond simple adjacency (e.g. "at most N bedrooms," "every room needs a path to an exit") that get awkward to express as pure module-adjacency rules in WFC/Monoceros.
- Decoupled from Rhino/Grasshopper entirely — could run as a standalone service, useful if the project ever needs the solver independent of a Rhino license (e.g. for the standalone-prototype spike, or a server-side solve).

**In favor of staying Grasshopper-native (Monoceros/WFC):**
- Zero interop cost: stays inside the same tool architects already use, with live geometry feedback — a Prolog core would need a bridge (HTTP call out from a Grasshopper script component, or similar) to get results back into the Grasshopper canvas as geometry.
- Monoceros already models the module/slot/rule vocabulary architects think in; re-expressing that as raw CLP(FD) constraints is more implementation work up front, even if the propagation underneath ends up more robust.
- WFC's frequency-weighted random selection (not just "any satisfying assignment") is central to getting organic-feeling layouts; CLP(FD)'s default labeling strategies optimize for finding *a* solution, not for weighted-random aesthetic variety — that would need custom labeling heuristics.

**Recommendation for this project**: prefer the Grasshopper/Monoceros path as primary (see [[Grasshopper]], [[Monoceros]]) since it matches the target workflow and users; keep Prolog/CLP(FD) in reserve as the fallback if Monoceros' rule/constraint expressiveness turns out to be too limited for real architectural requirements (room adjacency *plus* programmatic requirements like square-footage minimums, egress paths, etc.).

## Key gotchas / links

- SWI-Prolog CLP(FD) docs: https://www.swi-prolog.org/man/clpfd.html
- GNU Prolog also ships a well-regarded native FD solver: https://www.gprolog.org/
- Markus Triska's CLP(FD) tutorials are widely considered the best modern reference for idiomatic usage.
