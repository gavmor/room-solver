# room-solver wiki

Reference pages for the WFC room/floorplan solver project.

**Pivoted 2026-08-16** from a Grasshopper/Monoceros target to a Revit-native, in-process, enterprise-lockdown-constrained architecture. Pages below reflect the current direction; superseded pages are marked accordingly.

- [[WFC]] — the core algorithm, and the open question of whether "collapse" should stay stochastic or become CP-SAT-driven
- [[CP-SAT]] — Google OR-Tools' in-process C# constraint solver, now the primary solver candidate
- [[Revit]] — the current primary target: a self-contained in-process add-in, and why
- [[AC-3-CSP]] — the constraint-propagation theory underlying both WFC's collapse+propagate loop and CP-SAT's constraint model
- [[Prolog]] — CLP(FD)/Clingo as alternate solver cores — currently BLOCKED under the worst-case locked-down-IT assumption
- [[Grasshopper]] — *(superseded)* Rhino's visual scripting environment; no longer a target
- [[Monoceros]] — *(superseded)* the Grasshopper WFC plugin this project used to target
