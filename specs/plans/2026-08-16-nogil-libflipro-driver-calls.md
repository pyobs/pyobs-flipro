# Plan: Release the GIL around libflipro calls

Status: in progress

Tracks: https://github.com/pyobs/pyobs-flipro/issues/29

## Problem

A hung FLI Pro device freezes the whole module, including XMPP. `FliProCamera` already runs
every FLIPRO SDK call in a daemon thread bounded by `asyncio.wait_for(...)` via
`_run_blocking`/`_run_blocking_or_raise` (`pyobs_flipro/fliprocamera.py`) — the correct
mitigation for a blocking vendor SDK call made from an `async def` method. It doesn't actually
bound a hung call, because `libflipro.pxd` declares `FPROCam_Open`, `FPROCam_GetCameraList`,
`FPROFrame_GetVideoFrameUnpacked`, etc. without `nogil`. Cython calls into a non-`nogil` C
function while still holding the GIL, so when the call blocks (unresponsive device), the daemon
thread holds the GIL for the entire hang. The event loop thread cannot run *anything* on that
GIL, including the `asyncio.wait_for` timeout machinery meant to bound the call. The timeout
never fires; the module goes fully unresponsive (same shape as `pyobs/pyobs-fli#75`, fixed there
in `pyobs/pyobs-fli#76`).

## Decision

Mark the libflipro C functions `nogil` in `libflipro.pxd`, and wrap each call site in
`fliprodriver.pyx` in `with nogil:` so the GIL is actually released while the call runs. This
restores the daemon-thread timeout's ability to fire, since the event loop thread can run while
the SDK call blocks.

Considered and rejected: running FLIPRO calls in a subprocess. Same reasoning as
`pyobs/pyobs-fli#76` — a much larger change (IPC, serialization of frame buffers, process
lifecycle) for the same practical outcome. Revisit only if a `with nogil:` call still wedges
(e.g. the SDK deadlocks internally in a way that isn't a simple blocking wait).

## Design

### `libflipro.pxd`

Change the whole `cdef extern from "../lib/libflipro.h":` block to
`cdef extern from "../lib/libflipro.h" nogil:`. This marks every declared function `nogil` at
once, including ones not yet called from `fliprodriver.pyx`, so new call sites added later don't
silently regress. Safe for the whole block: libflipro is a pure hardware-I/O C library, none of
its functions take a Python object or call back into the interpreter.

### `fliprodriver.pyx`

`nogil` only changes what's *allowed* inside `with nogil:` — it does not by itself move existing
calls off the GIL. Every call site needs a `with nogil:` around the actual `FPRO*()`/`LIBFLIPRO_*`
call, and anything inside that block that isn't a C primitive has to move outside it first:

- **Typed-arg unboxing** (`set_image_area`'s `col_offset`/`row_offset`/`width`/`height`,
  `set_exposure_time`'s `exptime_ns`, `set_binning`'s `x`/`y`): read into local `cdef` C
  variables before the `with nogil:` block, since Python->C unboxing touches the GIL.
  (`set_temperature_set_point` already hoisted `temp` into `cdef double dblSetPoint`.)
- **`self._handle` / `self._device`**: no change needed. They are C-typed (`cdef int32_t` /
  `cdef FPRODEVICEINFO`) fields of a `cdef class`, so reading them inside `with nogil:` is a
  direct field access, not a Python attribute lookup.
- **`read_exposure()`**: `frame_data`, `c_frame_size`, `buffers`, `stats` are all C locals; only
  the `FPROFrame_GetVideoFrameUnpacked` and `FPROFrame_FreeUnpackedBuffers` calls need wrapping.
  Buffer bookkeeping (`malloc`, `memcpy`, `free`) stays where it is — the `libc` declarations
  are `nogil` anyway.
- **Results**: every call's return value is captured in a `cdef LIBFLIPRO_API success` local
  inside the `with nogil:` block and checked after it, preserving the existing
  `if success < 0: raise ValueError(...)` behavior.

Cython raises a compile-time error for any Python-object touch inside a `with nogil:` block, so
this is self-checking: if an extraction is missed, `cython` on `fliprodriver.pyx` fails before
any build/link step.

### `_wait_exposure()` in `fliprocamera.py`

No change needed here: the poll loop already runs `is_available()` inside a single
`_run_blocking_or_raise` call rather than polling per-tick on the event loop, so only the
underlying `FPROFrame_IsAvailable` call in `fliprodriver.pyx` needed the `nogil` wrapping.

## Verification

No existing test suite exercises the Cython extension (no way to run libflipro calls without
real hardware). Verification is:

1. `cython pyobs_flipro/fliprodriver.pyx -I pyobs_flipro` compiles clean (catches any missed
   nogil extraction as a hard error, not just a lint).
2. Full `uv sync` (scikit-build-core/CMake) build succeeds, the generated C shows
   `PyEval_SaveThread()`/`PyEval_RestoreThread()` around every SDK call, and the resulting
   extension imports.
3. `pytest tests` passes (regression: `_run_blocking`/`_run_blocking_or_raise` wrappers and
   constructor/setter behavior unchanged).
4. Manual read-through confirming every `FPRO*`/`LIBFLIPRO_*` call site in the diff is inside a
   `with nogil:` block, and that nothing added to `libflipro.pxd`'s `nogil` block passes a Python
   object by reference to a C function that could retain/mutate it — none of the current API does.

No hardware-in-the-loop test is possible from here; actual freeze recovery on a hung FLI Pro
device can only be confirmed on-site.

## Implementation checklist

- [x] `libflipro.pxd`: add `nogil` to the `cdef extern from "../lib/libflipro.h":` line.
- [x] `fliprodriver.pyx`: wrap every `FPRO*`/`LIBFLIPRO_*` call site in `with nogil:`, hoisting
      typed-arg reads above the block as described in Design.
- [x] `cython pyobs_flipro/fliprodriver.pyx -I pyobs_flipro` compiles with no errors.
- [x] Full build (`uv sync`) succeeds; the generated C releases the GIL around each SDK call and
      the extension imports.
- [x] `pytest tests` passes.
- [x] Open a PR against `develop` (matches this repo's branch convention — dependabot/feature
      PRs land on `develop`, which then gets version-bumped into `main`). Opened as #36.
- [ ] Update this doc's `Status:` to `implemented` once merged.
