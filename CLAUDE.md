# CLAUDE.md

Entry points for working in this repo.

## What this is

`pyobs-flipro` is a `pyobs` module for FLI PRO cameras (`FliProCamera`). Needs
`libcfitsio-dev`/`libusb-1.0-0-dev` system packages. Has an optional `gui` extra
(`uv sync --extra gui`, then `uv run flipro-gui`) for testing a camera without a full `pyobs` setup.

## Design history and planning

This repo keeps its own implementation plans under `specs/plans/`. Design docs and ADRs that
concern `pyobs-flipro` live in `pyobs-core`'s `specs/` tree instead, tagged with a `Repos:` line —
see `pyobs-core/CLAUDE.md`'s "Cross-repo docs" section for the convention.

## Tooling

- Lint: `ruff` (config in `pyproject.toml`)
- Format: `black`
- Type checking: `pyrefly` (excludes `pyobs_flipro/gui.py`)
- Tests: `pytest` (`asyncio_mode = "strict"`)
