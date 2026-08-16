# Wave Function Collapse (WFC)

## What it is

Wave Function Collapse is a procedural generation algorithm published by [Maxim Gumin](https://github.com/mxgmn/WaveFunctionCollapse) in 2016. It generates output that is *locally similar* to a small input example (or, in the "tiled model" variant, satisfies a set of adjacency rules between predefined tiles/modules) by treating generation as a constraint satisfaction problem:

1. **Initialize**: every cell in the output grid starts in *superposition* — it could be any of the available tiles/modules.
2. **Observe (collapse)**: pick the cell with the lowest Shannon entropy (fewest remaining options, weighted by tile frequency) and collapse it to a single concrete tile, chosen randomly weighted by that tile's frequency.
3. **Propagate**: for every neighbor of the collapsed cell, remove any tile options that are no longer compatible with the adjacency rules given the neighbor's new, reduced possibility set. This cascades outward (it's an [[AC-3-CSP|arc-consistency]] propagation pass) until no more options can be eliminated.
4. **Repeat** steps 2-3 until every cell has collapsed to one tile (success) or some cell's possibility set becomes empty (contradiction — the classic implementation backtracks or restarts on this).

The name is a physics metaphor: each cell is a "wave function" of possible states until it's "observed" and collapses to one.

## Why it's relevant to room-solver

This project's entire interaction model is built directly on top of WFC's structure:

- The **entropy/domain** the architect sees at each cell *is* the WFC possibility set from step 1/3 above — we're just surfacing the algorithm's internal state as the primary UI, rather than hiding it.
- **Locking a cell** is exactly a pre-collapse in step 2 — you're telling the solver "this cell's tile is fixed before you start," not injecting state into a mid-run solver.
- Because propagation (step 3) is a full pass over the grid from whatever the current collapsed/locked cells are, **there is no meaningful "resume" state to preserve** — re-running the entire algorithm from scratch with the locked cells pre-seeded produces the same result as if those locks had always been there. This is precisely why room-solver's "full re-solve on every lock" design isn't a shortcut or a compromise — it's the natural shape of the algorithm, and it happens to line up perfectly with Grasshopper's own solve-once graph execution model (see [[Grasshopper]]).

## Architectural-layout adaptations

Gumin's original WFC operates on pixel/voxel tiles for texture and level generation. Adapting it to floorplans/room layouts generally means:

- Tiles become **modules**: room types, wall segments, doors, corridors — each with explicit connector/socket definitions on each face (compatible edges must match, e.g. "corridor-end can only neighbor corridor-end or room-entrance").
- The grid is usually a 2D or 2.5D (multi-floor) grid rather than a single-plane texture.
- Frequency weighting doubles as a design lever — e.g. weighting corridor modules low keeps generated layouts room-dense rather than maze-like.
- **(Pivoted 2026-08-16)** [[Monoceros]] is no longer the reference implementation — under the Revit-native, in-process pivot, WFC is reimplemented natively in C#. This is simple enough to do directly and removes the last Grasshopper dependency (no Rhino.Inside.Revit bridge needed, since there's no Grasshopper layer left to bridge from). See [[Revit]] for the hosting architecture and [[CP-SAT]] for the solver alternative discussed below.

## Hierarchical WFC (HWFC)

For floorplan-scale problems, flat single-pass WFC scales poorly once it has to balance local wall alignment against long-range concerns like circulation. HWFC decomposes the solve into sequential, scale-dependent passes instead of one flat grid:

1. **Structural pass** — envelope and cores on a coarse grid.
2. **Spatial zoning pass** — programmatic regions (which rooms go roughly where).
3. **Circulation pass** — corridors and egress paths traced between zones.
4. **Detailing pass** — demising walls, doors, fixtures within the now-bounded rooms.

Worth evaluating for room-solver once real floorplan sizes are known — a flat single-grid WFC/CP-SAT model may need this decomposition to stay tractable and to keep circulation from fighting local adjacency rules.

## Open design question (raised 2026-08-16, not yet resolved — see the design doc)

Gavin's framing: *"WFC seems to be a random-walk through a latent space that's potentially exhaustively delineable via constraint solving."* WFC's entropy-minimization + weighted-random tie-breaking is non-deterministic by construction — useful for organic variety, but arguably unnecessary friction in an architect-facing lock/re-solve UI where repeatability and explainability matter, especially now that [[CP-SAT]] is available in-process anyway. Whether the "collapse" step should stay stochastic-WFC, become CP-SAT-driven (exhaustive enumeration or an objective function), or some hybrid (WFC propagation for speed/preview, CP-SAT as the source of truth for what's actually possible at a cell) is an open question the design doc addresses directly — don't assume WFC "wins" just because it's already documented here.

## Connectivity/egress repair pass

Early WFC (or CP-SAT) tile/room decisions can isolate rooms with no valid door/egress path — neither solver inherently guarantees full connectivity. The production-proven mitigation: let the primary solver assign room zones and structural boundaries first, then run a **separate graph-traversal pass (BFS or Minimum Spanning Tree) over the resulting room-adjacency graph** to insert doors between isolated components (and prune redundant connections), rather than requiring the primary solver to guarantee connectivity itself. This applies regardless of which collapse strategy wins the open question above — CP-SAT doesn't get this for free either.

## Key gotchas

- **Contradictions**: naive WFC can paint itself into a corner (a cell's domain becomes empty) and needs a backtrack or full restart. Because room-solver already restarts the whole solve on every lock, contradiction-handling is simpler here than in a typical live/incremental WFC UI — a contradiction just means "these locks are jointly unsatisfiable," surfaced as a solve failure rather than a partial-undo problem.
- **Determinism vs. seed**: the same locked-cell set plus the same RNG seed always produces the same solve. Useful for reproducing/debugging a specific layout — and a point in favor of leaning more CP-SAT/deterministic per the open question above.
- **Performance**: full-grid propagation on every lock is O(grid size × rule complexity) per lock, not free — worth profiling once the grid/tileset size for real floorplans is known.
- **Isolation**: see the connectivity/egress repair pass above — don't assume a "successful" solve is a valid, egress-compliant one.

## References

- Maxim Gumin, original repo: https://github.com/mxgmn/WaveFunctionCollapse
- Oskar Stålberg's talks on WFC-adjacent techniques (Townscaper, Bad North) are widely cited in the architectural-WFC community.
