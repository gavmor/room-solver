# room-solver

Wave Function Collapse (WFC)-style procedural generation for architectural room and floorplan layouts. An architect sees the full entropy/domain (all remaining valid options) at every cell in the grid, and can click any option to lock it in. Locking a cell doesn't drive an incremental/steppable solver — the entire solve re-runs from scratch each time, with all currently-locked cells baked in as fixed seed constraints, producing a fresh grid of remaining possibilities.

## Pivot (2026-08-16): Revit-native, in-process, enterprise-lockdown-constrained

The original plan (Grasshopper + [Monoceros](https://github.com/subdgtl/Monoceros), with Prolog CLP(FD) as an alternate solver core, Revit only receiving the final approved layout) has been overturned. The target is now **Revit itself**, deployed into an **enterprise environment with locked-down application provisioning**.

**Working assumption (not yet confirmed — revisit if IT posture turns out looser):** worst case — no local admin rights, AppLocker/WDAC blocking unsigned or unapproved binaries, no outbound network access. Everything below follows from that assumption:

- **No Grasshopper/Rhino/Monoceros.** A second licensed app requiring separate enterprise IT approval, install, and patching is exactly the friction this pivot exists to avoid. Revit is presumably already the sanctioned tool.
- **No out-of-process sidecar and no cloud-distributed worker.** Named pipes, gRPC, a local daemon, or a remote service all require spawning processes, opening ports, or reaching the network — all things a locked-down environment is specifically designed to block.
- **Single self-contained, signed Revit add-in DLL, fully in-process.** Heavy compute runs off the UI thread via `Task.Run`, then re-enters Revit's main thread via the standard async bridge pattern (`IExternalEventHandler`/`ExternalEvent` wrapped in a `TaskCompletionSource`, e.g. via [Revit.Async](https://github.com/KennanChan/Revit.Async) or [ricaun.Revit.UI.Tasks](https://github.com/ricaun/Revit.UI.Tasks)) to commit a `Transaction`. No separate process, no IPC, no egress.
- **Solver: Google OR-Tools CP-SAT, in-process**, via the official [Google.OrTools](https://github.com/google/or-tools) C# NuGet bindings (`AddNoOverlap2D`, reified adjacency constraints, etc.). This is the primary constraint-solving engine under this pivot.
- **Clingo (Answer Set Programming) and Prolog CLP(FD) are currently BLOCKED** under the worst-case assumption — both require a native binary/runtime as a separate process, which locked-down IT won't permit without an explicit exception. Not dropped silently; flagged for IT follow-up. See [[Prolog]].
- **WFC reimplemented natively in C#** rather than depending on Monoceros — this also removes the last Grasshopper dependency, since there's no Grasshopper layer left to bridge from (no Rhino.Inside.Revit needed).
- **Geometry ingestion via Revit's native API** — `Room.GetBoundarySegments(SpatialElementBoundaryOptions)` — no Grasshopper geometry import needed.

**Open design question carried into the design doc, not resolved here:** WFC's entropy-minimization + random tie-breaking is a random walk through a latent space that may be exhaustively delineable via constraint solving. Given CP-SAT is available in-process anyway, should the "collapse" step still be stochastic WFC, or should CP-SAT (exhaustive enumeration / an objective function) replace random collapse — or some hybrid? See the design doc for the reasoned answer.

See the [wiki](../../wiki) for the WFC/CSP theory, the Revit-native architecture, CP-SAT, and why Grasshopper/Monoceros/Prolog are no longer primary.
