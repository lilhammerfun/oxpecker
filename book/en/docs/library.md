# Library Interface

The current library direction is organized around a small set of concepts:

- `Spec` defines the model boundary.
- `Action` defines one possible transition.
- `Invariant` defines a property that must hold for every reachable state.
- `CheckResult` reports whether the model holds, violates a property, deadlocks, or stops incompletely.
- `TraceStep` explains how a counterexample was reached.

The interface should remain explicit enough for reviewers to understand what was checked.

