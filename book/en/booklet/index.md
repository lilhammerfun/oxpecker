# Booklet

The Oxpecker booklet teaches formal verification through a Zig-first practice path.

The central question is not how to learn a specific verification language first. The central question is how to make stateful code, especially code changed by coding agents, easier to check.

The Zig library is the teaching tool used by this booklet, not an independent booklet phase. Library API details, engineering direction, and production-readiness work belong in Docs and Roadmap.

## Learning Path

- **FV Practice Intuition** builds the first model-checking loop: state, transition, invariant, reachable state, and counterexample trace.
- **Model Expression** improves how models and actions are written.
- **Temporal Properties** expands beyond simple safety checks.
- **Theorem Proving** explains where finite search stops and proof obligations begin.
- **Engineering Integration** connects checks to coding agents, review, CI, and regression workflows.
