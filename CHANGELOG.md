# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for releases before this file existed were generated from commit subjects.

## [2.0.4] - 2026-09-28

- Maintenance release (dependency and metadata updates only).

## [2.0.3] - 2026-09-28

- Add IResettable.full_reset() override, moving cooling setup out of open()
- Add CLAUDE.md entry point pointing to specs/ conventions and tooling

## [2.0.2] - 2026-09-03

- Add DET-TBAS (base-plate temperature) FITS header (#872)

## [2.0.1] - 2026-09-01

- Maintenance release (dependency and metadata updates only).

## [2.0.0] - 2026-08-26

- Require stable pyobs-core>=2.0.0
- Remove stale poetry.lock; project now uses uv.lock
- ci: retrigger checks (pyrefly runner hung on apt step)
- Release the GIL around libflipro calls
- Gate auto-merge on the PR author, not the event actor
- Enable Dependabot auto-merge for patch/minor updates
- Camera driver/GUI split: fix abort, get_api_version, exception handling, open leak, locking (#35)
- tests: assert comm.set_state call shape in window/binning tests
- fliprocamera: defer native driver import to TYPE_CHECKING
- Add baseline test suite and CI (pytest, pyrefly), grouped Dependabot
- Disable uv cache in publish job (no deps installed there to cache)
- Pin cibuildwheel action to v4.2.0 (bare @v2 tag doesn't exist upstream)
- Build and publish manylinux wheels via cibuildwheel, include Python 3.14
- Upgrade uv.lock to clear open Dependabot alerts
- Require pyobs-core>=2.0.0.dev48
- Add dependabot.yml, targeting develop for PRs
- Run FLIPRO SDK calls through a background thread instead of the event loop
- Restore Sphinx documentation
- Rewrite README for uv-based install, config docs, and GUI
- Use pyobs-core[gui] extra instead of separate Qt packages
- Use `--no-sync` flag in Ruff GitHub workflow.
- install libcfitsio-dev libusb-1.0-0-dev
- pypi workflow to uv, and added ruff workflow
- Remove `DEVELOPMENT.md` migration guide for pyobs 2.0
- Add GUI support for FLIPRO camera with PySide6 and qasync
- Add ITemperatures interface, cooling polling task, and full-frame support to FliProCamera
- Replace flake8 with ruff in pre-commit configuration
- Transition pyobs-flipro to Scikit-Build and update dependencies for pyobs-core 2.0 compatibility.
- Add DEVELOPMENT.md documentation for pyobs 2.0 migration
- back to poetry for building cython...
- new lock file

## [1.2.0] - 2025-07-07

- migrated to uv
- datetime.utcnow() to datetime.utc(timezone.utc)

## [1.1.5] - 2024-04-21

- log format

## [1.1.4] - 2024-04-21

- debug logging

## [1.1.3] - 2024-04-21

- debug logging

## [1.1.2] - 2024-04-21

- debug logging

## [1.1.1] - 2024-04-21

- debug logging

## [1.1.0] - 2024-04-21

- add cooling

## [1.0.4] - 2024-04-21

- added list_binnings

## [1.0.3] - 2024-04-21

- numpy support

## [1.0.2] - 2024-04-21

- fixed import

## [1.0.1] - 2024-04-21

- python 3.11
- don't open shutter for darks etc
- add packages
- added setup.py

## [1.0.0] - 2023-01-22

- added pypi action
- refactored expose method
- added license
- everything seems to be working, except windowing with smaller widths
- added file
- testing
- module working
- finishing up module
- capabilities
- window and binning
- working on module
- added is_available
- temps and cooling
- taking images workd
- expose
- image area and exposure time
- basic functionality works
- working on wrapper
- replaced static libflipro library with dynamic one
- initial
- first commit
