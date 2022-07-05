import asyncio
import logging
import math
from datetime import datetime
from typing import Tuple, Any, Optional, Dict
import numpy as np

from pyobs.interfaces import ICamera, IWindow, IBinning, ICooling, IAbortable
from pyobs.modules.camera.basecamera import BaseCamera
from pyobs.images import Image
from pyobs.utils.enums import ExposureStatus
from pyobs.utils.time import Time

log = logging.getLogger(__name__)


class FliProCamera(BaseCamera, ICamera, IAbortable):
    """A pyobs module for FLIPRO cameras."""

    __module__ = "pyobs_flipro"

    def __init__(self, **kwargs: Any):
        """Initializes a new FliProCamera.

        Args:
            setpoint: Cooling temperature setpoint.
            keep_alive_ping: Interval in seconds to ping camera.
        """
        BaseCamera.__init__(self, **kwargs)
        from .fliprodriver import FliProDriver, DeviceInfo  # type: ignore

        # variables
        self._driver: Optional[FliProDriver] = None
        self._device: Optional[DeviceInfo] = None

    async def open(self) -> None:
        """Open module."""
        await BaseCamera.open(self)
        from .fliprodriver import FliProDriver

        # list devices
        devices = FliProDriver.list_devices()
        if len(devices) == 0:
            raise ValueError("No camera found.")

        # open first one
        self._device = devices[0]
        log.info('Opening connection to "%s"...', self._device.friendly_name)
        self._driver = FliProDriver(self._device)
        try:
            self._driver.open()
        except ValueError as e:
            raise ValueError("Could not open FLIPRO camera: %s", e)

    async def close(self) -> None:
        """Close the module."""
        await BaseCamera.close(self)

        # not open?
        if self._driver is not None:
            # close connection
            self._driver.close()
            self._driver = None

    async def _expose(self, exposure_time: float, open_shutter: bool, abort_event: asyncio.Event) -> Image:
        """Actually do the exposure, should be implemented by derived classes.

        Args:
            exposure_time: The requested exposure time in seconds.
            open_shutter: Whether or not to open the shutter.
            abort_event: Event that gets triggered when exposure should be aborted.

        Returns:
            The actual image.

        Raises:
            GrabImageError: If exposure was not successful.
        """

        # check driver
        if self._driver is None:
            raise ValueError("No camera driver.")

        # do exposure
        frame_size = self._driver.get_frame_size()
        date_obs = Time.now()
        self._driver.start_exposure()

        # wait for exposure to finish
        while not self._driver.is_available():
            # aborted?
            if abort_event.is_set():
                await self._change_exposure_status(ExposureStatus.IDLE)
                raise InterruptedError("Aborted exposure.")

            # sleep a little
            await asyncio.sleep(0.01)

        # readout
        log.info("Exposure finished, reading out...")
        await self._change_exposure_status(ExposureStatus.READOUT)
        img = self._driver.read_exposure(frame_size)
        self._driver.stop_exposure()

        # create FITS image and set header
        image = Image(img)
        image.header["DATE-OBS"] = (date_obs, "Date and time of start of exposure")
        image.header["EXPTIME"] = (exposure_time, "Exposure time [s]")
        image.header["DET-TEMP"] = (self._driver.get_sensor_temperature(), "CCD temperature [C]")
        image.header["DET-COOL"] = (self._driver.get_cooler_duty_cycle(), "Cooler power [percent]")
        image.header["DET-TSET"] = (self._driver.get_temperature_set_point(), "Cooler setpoint [C]")

        # instrument and detector
        dev = self._driver.device
        image.header["INSTRUME"] = (f"{dev.friendly_name} {dev.serial_number}", "Name of instrument")

        # binning
        # image.header["XBINNING"] = image.header["DET-BIN1"] = (self._binning[0], "Binning factor used on X axis")
        # image.header["YBINNING"] = image.header["DET-BIN2"] = (self._binning[1], "Binning factor used on Y axis")

        # window
        # image.header["XORGSUBF"] = (self._window[0], "Subframe origin on X axis")
        # image.header["YORGSUBF"] = (self._window[1], "Subframe origin on Y axis")

        # statistics
        image.header["DATAMIN"] = (float(np.min(img)), "Minimum data value")
        image.header["DATAMAX"] = (float(np.max(img)), "Maximum data value")
        image.header["DATAMEAN"] = (float(np.mean(img)), "Mean data value")

        # biassec/trimsec
        full = self._driver.get_image_area()
        self.set_biassec_trimsec(image.header, *full)

        # return FITS image
        log.info("Readout finished.")
        return image

    async def _abort_exposure(self) -> None:
        """Abort the running exposure. Should be implemented by derived class.

        Raises:
            ValueError: If an error occured.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")
        self._driver.cancel_exposure()

    async def get_cooling(self, **kwargs: Any) -> Tuple[bool, float, float]:
        """Returns the current status for the cooling.

        Returns:
            Tuple containing:
                Enabled (bool):         Whether the cooling is enabled
                SetPoint (float):       Setpoint for the cooling in celsius.
                Power (float):          Current cooling power in percent or None.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")
        enabled = self._temp_setpoint is not None
        return (
            enabled,
            self._temp_setpoint if self._temp_setpoint is not None else 99.0,
            self._driver.get_cooler_power(),
        )

    async def get_temperatures(self, **kwargs: Any) -> Dict[str, float]:
        """Returns all temperatures measured by this module.

        Returns:
            Dict containing temperatures.
        """
        from .flidriver import FliTemperature

        if self._driver is None:
            raise ValueError("No camera driver.")
        return {"CCD": self._driver.get_temp(FliTemperature.CCD), "Base": self._driver.get_temp(FliTemperature.BASE)}

    async def set_cooling(self, enabled: bool, setpoint: float, **kwargs: Any) -> None:
        """Enables/disables cooling and sets setpoint.

        Args:
            enabled: Enable or disable cooling.
            setpoint: Setpoint in celsius for the cooling.

        Raises:
            ValueError: If cooling could not be set.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")

        # log
        if enabled:
            log.info("Enabling cooling with a setpoint of %.2f°C...", setpoint)
        else:
            log.info("Disabling cooling and setting setpoint to 20°C...")

        # if not enabled, set setpoint to None
        self._temp_setpoint = setpoint if enabled else None

        # set setpoint
        self._driver.set_temperature(float(setpoint) if setpoint is not None else 20.0)


__all__ = ["FliCamera"]
