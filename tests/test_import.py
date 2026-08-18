"""Smoke tests: import the driver and instantiate it without hardware, asserting the
interfaces it claims.

The Cython extension (fliprodriver) links the bundled FLIPRO .so libraries during
install, but device enumeration/opening only happens inside open(), so instantiation
is safe with no FLIPRO hardware attached.
"""

from pyobs.interfaces import IAbortable, IBinning, ICamera, ICooling, ITemperatures, IWindow
from pyobs.modules import Module

from pyobs_flipro import FliProCamera


def test_instantiate_camera() -> None:
    camera = FliProCamera(-20.0)
    assert isinstance(camera, Module)
    assert isinstance(camera, ICamera)
    assert isinstance(camera, IWindow)
    assert isinstance(camera, IBinning)
    assert isinstance(camera, ICooling)
    assert isinstance(camera, ITemperatures)
    assert isinstance(camera, IAbortable)
