# AC-3 / Constraint Satisfaction Fundamentals

## What it is

A **Constraint Satisfaction Problem (CSP)** is defined by: a set of variables, a domain of possible values for each, and a set of constraints restricting which combinations of values are jointly allowed. **Arc consistency** is a local-consistency property: a binary constraint between variables X and Y is arc-consistent if, for every remaining value in X's domain, there's at least one compatible value still in Y's domain (and vice versa). **AC-3** (Mackworth, 1977) is the classic algorithm for enforcing arc consistency across an entire constraint graph: it maintains a queue of arcs (variable pairs with a constraint between them), repeatedly picks an arc, removes any values from one side that have no compatible value on the other side, and — if anything was removed — re-queues all arcs pointing back into the changed variable, since removing a value there might now invalidate consistency elsewhere. It terminates when the queue is empty (fully arc-consistent) or some domain becomes empty (no solution exists under current constraints).

## Why it's relevant to room-solver

This is the theoretical skeleton underneath [[WFC]]'s "propagate" step: when a WFC cell collapses (or gets locked), removing incompatible options from its neighbors and cascading that removal outward *is* AC-3 running on a grid-shaped constraint graph, where "variable" = grid cell, "domain" = remaining tile/module options, and "constraint" = the adjacency rule between neighboring cells. Understanding it explicitly (rather than only through WFC's specific framing) is useful for this project because:

- It explains *why* re-running the full solve from scratch after every lock is cheap and correct: arc consistency is a property of the current domains and constraints only, not of solve history — recomputing it from a fresh full-domain grid plus the current locked-cell constraints always converges to the same result as if those locks had been enforced from the start. There's no hidden state a "from scratch" recompute could miss.
- It's the right vocabulary for reasoning about [[Monoceros]]'s solver behavior *(superseded — no longer used, see [[Revit]])*, for evaluating [[Prolog]]/CLP(FD) as an alternate core (currently blocked), and — most relevantly post-pivot — for reasoning about [[CP-SAT]]: its constraint propagation during search is a generalization of the same arc-consistency idea to n-ary constraints, richer domains, and continuous interval variables, not just adjacent-pair binary tile rules.
- Arc consistency alone doesn't guarantee a full solution exists (it only prunes; it can leave every domain non-empty and still have no consistent joint assignment) — this is why both WFC and CLP(FD) solvers need a *search* step (WFC: pick lowest-entropy cell and guess, backtrack/restart on failure; CLP(FD): systematic labeling/backtracking search) layered on top of pure constraint propagation. Worth remembering when a WFC solve reports a contradiction: that's a search failure, not a bug in the propagation logic.

## Key gotchas

- AC-3's worst-case complexity is O(e·d³) for e constraint edges and domain size d — fine for the small per-cell tile counts typical in WFC tilesets, but worth keeping in mind if the module/tileset library grows large.
- Arc consistency is a *necessary but not sufficient* condition for a full solution — don't confuse "the propagation pass finished without any domain going empty" with "a valid complete layout is guaranteed to exist"; the collapse/search step can still fail later.
- There are stronger consistency notions (path consistency, k-consistency) used in more general CSP solvers; WFC and most Monoceros-style tools stick to arc consistency because it's cheap and sufficient in practice for grid-adjacency-style rules.

## References

- Mackworth, A.K. (1977). "Consistency in Networks of Relations." *Artificial Intelligence*, 8(1), 99-118. (Original AC-3 paper.)
- Russell & Norvig, *Artificial Intelligence: A Modern Approach* — standard textbook treatment of CSPs, arc consistency, and backtracking search.
