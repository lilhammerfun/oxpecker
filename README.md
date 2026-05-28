# Oxpecker

[![license: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![zig](https://img.shields.io/badge/zig-0.15.1-orange.svg)
![booklet](https://img.shields.io/badge/booklet-VitePress-blue.svg)

Oxpecker explores whether formal verification can make AI-generated code easier
to review, reproduce, and verify.

AI-assisted development can increase code production speed, but review,
validation, and regression confidence do not automatically scale with it.
Oxpecker uses small, runnable Zig models to study how specs, model checking,
invariants, and counterexample traces can turn stateful behavior into reviewable
evidence.

The project site has three sections:

- **Booklet**: formal verification onboarding from real engineering problems.
  The Zig library appears here as a teaching tool, not as a standalone booklet
  phase.
- **Docs**: API and development notes for the Oxpecker Zig library.
- **Roadmap**: long-term tool direction for checker core, model expression,
  state-space engineering, property systems, symbolic methods, proof boundaries,
  and engineering integration.

The codebase includes an early explicit-state model checker written in Zig plus
examples that connect a specification to candidate business logic.

See the site Roadmap for the longer-term technical direction.

## Development

Run the project site locally:

```sh
bun install
bun run dev
bun run build
```

Run the first Zig model-checking exercise:

```sh
zig build run
zig build test
```

The current examples include a task-cancellation teaching model and an
agent-task example where the checker finds a late tool-result path that can
complete a cancelled task.

## License

MIT
