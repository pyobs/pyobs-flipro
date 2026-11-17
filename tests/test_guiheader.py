"""Tests for the FITS header the GUI writes."""

from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

import numpy as np
import pytest

try:
    from pyobs_flipro.gui import make_header
except ImportError as e:  # no Qt extras, or the camera library is not installed
    pytest.skip(f"GUI cannot be imported: {e}", allow_module_level=True)


class FakeDriver:
    device = SimpleNamespace(friendly_name="ProLine", serial_number="PL123")

    def get_temperatures(self) -> tuple[float, float, float]:
        return -9.5, 21.0, -9.4

    def get_sensor_temperature(self) -> float:
        return -9.5

    def get_cooler_duty_cycle(self) -> float:
        return 50.0

    def get_temperature_set_point(self) -> float:
        return -10.0


DATE = datetime(2026, 11, 17, 10, 0, 0, tzinfo=UTC)
DATA = np.array([[1, 2], [3, 6]], dtype=np.uint16)


def test_header_has_the_module_keys() -> None:
    h = make_header(FakeDriver(), DATE, 5.0, (10, 20, 100, 100), (2, 2), DATA)  # type: ignore[arg-type]
    assert h["EXPTIME"] == 5.0 and h["DATE-OBS"] == "2026-11-17T10:00:00.000000"
    assert h["INSTRUME"] == "ProLine PL123"
    assert h["DET-TEMP"] == -9.5 and h["DET-TBAS"] == 21.0 and h["DET-COOL"] == 50.0 and h["DET-TSET"] == -10.0
    assert h["DET-BIN1"] == 2 and h["XORGSUBF"] == 10 and h["YORGSUBF"] == 20
    assert (h["DATAMIN"], h["DATAMAX"], h["DATAMEAN"]) == (1.0, 6.0, 3.0)
