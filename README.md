# room-solver

Wave Function Collapse (WFC) procedural generation for architectural room and floorplan layouts. An architect sees the full entropy/domain (all remaining valid options) at every cell in the grid, and can click any option to lock it in. Locking a cell doesn't drive an incremental/steppable solver — the entire WFC solve re-runs from scratch each time, with all currently-locked cells baked in as fixed seed constraints, producing a fresh grid of remaining possibilities.

The primary target is [Grasshopper](https://www.rhino3d.com/features/grasshopper/) (Rhino's visual scripting environment), building on the existing FOSS WFC plugin [Monoceros](https://github.com/subdgtl/Monoceros) rather than reimplementing WFC from scratch — its solve-once, pull-based graph model fits the restart-on-lock interaction naturally. [Prolog](https://en.wikipedia.org/wiki/Prolog) with CLP(FD) is under consideration as an alternate constraint-solver core, since WFC is fundamentally a constraint satisfaction problem.

See the [wiki](../../wiki) for background on WFC, Monoceros, Grasshopper/Revit interop, and the CSP/arc-consistency theory underlying the collapse+propagate loop.
