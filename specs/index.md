# specs/

This repo keeps its own implementation plans under `plans/`. Design docs and ADRs that concern
`pyobs-flipro` live in `pyobs-core`'s `specs/` tree instead (`specs/design/`, `specs/plans/`,
`specs/adrs/`), each tagged with a `Repos:` line naming every repo it concerns — see
`pyobs-core/CLAUDE.md`'s "Cross-repo docs" section.

Plans:

- [plans/2026-08-16-nogil-libflipro-driver-calls.md](plans/2026-08-16-nogil-libflipro-driver-calls.md)
  — **in progress**. Release the GIL around blocking `libflipro` SDK calls so a hung FLI Pro
  device no longer freezes the whole module (including XMPP); `libflipro.pxd` declared the
  relevant functions without `nogil`, so the existing `_run_blocking`/timeout mitigation couldn't
  actually bound a hung call (issue #29).
