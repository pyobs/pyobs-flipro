import asyncio
import logging
import math
from datetime import datetime
from typing import Tuple, Any, Optional, Dict, List
import numpy as np

from pyobs.interfaces import ICamera, IWindow, IBinning, ICooling, IAbortable
from pyobs.modules.camera.basecamera import BaseCamera
from pyobs.images import Image
from pyobs.utils.enums import ExposureStatus
from pyobs.utils.time import Time

from pyobs_flipro.fliprodriver import DeviceCaps

log = logging.getLogger(__name__)


class FliProCamera(BaseCamera, ICamera, IAbortable, IWindow, IBinning, ICooling):
    """A pyobs module for FLIPRO cameras."""

    __module__ = "pyobs_flipro"

    def __init__(self, setpoint: float, **kwargs: Any):
        """Initializes a new FliProCamera.

        Args:
            setpoint: Cooling temperature setpoint.
        """
        BaseCamera.__init__(self, **kwargs)
        from .fliprodriver import FliProDriver, DeviceInfo  # type: ignore

        # variables
        self._driver: Optional[FliProDriver] = None
        self._device: Optional[DeviceInfo] = None
        self._caps: Optional[DeviceCaps] = None
        self._temp_setpoint: Optional[float] = setpoint

        # window and binning
        self._window = (0, 0, 0, 0)
        self._binning = (1, 1)

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
        self._log_device_info()
        log.info('Opening connection to "%s"...', self._device.friendly_name)
        self._driver = FliProDriver(self._device)
        try:
            self._driver.open()
        except ValueError as e:
            raise ValueError("Could not open FLIPRO camera: %s", e)

        # get caps
        self._caps = self._driver.get_capabilities()
        self._log_capabilities()

        # set cooling
        if self._temp_setpoint is not None:
            await self.set_cooling(True, self._temp_setpoint)

        # get window and binning
        self._window = self._driver.get_image_area()
        self._binning = self._driver.get_binning()

    async def close(self) -> None:
        """Close the module."""
        await BaseCamera.close(self)

        # not open?
        if self._driver is not None:
            # close connection
            self._driver.close()
            self._driver = None

    def _log_device_info(self):
        log.info("Device info:")
        log.info(f"  - Friendly Name: {self._device.friendly_name}")
        log.info(f"  - Serial No:     {self._device.serial_number}")
        log.info(f"  - Device Path:   {self._device.device_path}")
        log.info(f"  - Conn Type:     {self._device.conn_type}")
        log.info(f"  - Vendor ID:     {self._device.vendor_id}")
        log.info(f"  - Prod ID:       {self._device.prod_id}")
        log.info(f"  - USB Speed:     {self._device.usb_speed}")

    def _log_capabilities(self):
        log.info("Capabilities:")
        log.info(f"  - Version:                    {self._caps.uiCapVersion}")
        log.info(f"  - Device Type:                {self._caps.uiDeviceType}")
        log.info(f"  - Max Pixel Image Width:      {self._caps.uiMaxPixelImageWidth}")
        log.info(f"  - Max Pixel Image Height:     {self._caps.uiMaxPixelImageHeight}")
        log.info(f"  - Available Pixel Depths:     {self._caps.uiAvailablePixelDepths}")
        log.info(f"  - Binning Table Size:         {self._caps.uiBinningsTableSize}")
        log.info(f"  - Black Level Max:            {self._caps.uiBlackLevelMax}")
        log.info(f"  - Black Sun Max:              {self._caps.uiBlackSunMax}")
        log.info(f"  - Low Gain:                   {self._caps.uiLowGain}")
        log.info(f"  - High Gain:                  {self._caps.uiHighGain}")
        log.info(f"  - Row Scan Time:              {self._caps.uiRowScanTime}")
        log.info(f"  - Dummy Pixel Num:            {self._caps.uiDummyPixelNum}")
        log.info(f"  - Horizontal Scan Invertable: {self._caps.bHorizontalScanInvertable}")
        log.info(f"  - Vertical Scan Invertable:   {self._caps.bVerticalScanInvertable}")
        log.info(f"  - NV Storage Available:       {self._caps.uiNVStorageAvailable}")
        log.info(f"  - Pre Frame Reference Rows:   {self._caps.uiPreFrameReferenceRows}")
        log.info(f"  - Post Frame Reference Rows:  {self._caps.uiPostFrameReferenceRows}")
        log.info(f"  - Meta Data Size:             {self._caps.uiMetaDataSize}")

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

        # set binning
        log.info("Set binning to %dx%d.", self._binning[0], self._binning[1])
        self._driver.set_binning(*self._binning)

        # set window, size is given in unbinned pixels
        width = int(math.floor(self._window[2]) / self._binning[0])
        height = int(math.floor(self._window[3]) / self._binning[1])
        log.info(
            "Set window to %dx%d (binned %dx%d) at %d,%d.",
            self._window[2],
            self._window[3],
            width,
            height,
            self._window[0],
            self._window[1],
        )
        self._driver.set_image_area(self._window[0], self._window[1], self._window[2], self._window[3])

        # set exposure time
        self._driver.set_exposure_time(int(exposure_time * 1e9))

        # calculate frame size
        frame_size = self._driver.get_frame_size()

        # get date obs
        log.info(
            "Starting exposure with %s shutter for %.2f seconds...", "open" if open_shutter else "closed", exposure_time
        )
        date_obs = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.%f")

        # start exposure
        self._driver.start_exposure()

        # wait exposure
        await self._wait_exposure(abort_event, exposure_time, open_shutter)

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
        image.header["XBINNING"] = image.header["DET-BIN1"] = (self._binning[0], "Binning factor used on X axis")
        image.header["YBINNING"] = image.header["DET-BIN2"] = (self._binning[1], "Binning factor used on Y axis")

        # window
        image.header["XORGSUBF"] = (self._window[0], "Subframe origin on X axis")
        image.header["YORGSUBF"] = (self._window[1], "Subframe origin on Y axis")

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

    async def _wait_exposure(self, abort_event: asyncio.Event, exposure_time: float, open_shutter: bool) -> None:
        """Wait for exposure to finish.

        Params:
            abort_event: Event that aborts the exposure.
            exposure_time: Exp time in sec.
        """
        # wait for exposure to finish
        while not self._driver.is_available():
            # aborted?
            if abort_event.is_set():
                await self._change_exposure_status(ExposureStatus.IDLE)
                raise InterruptedError("Aborted exposure.")

            # sleep a little
            await asyncio.sleep(0.01)

    async def _abort_exposure(self) -> None:
        """Abort the running exposure. Should be implemented by derived class.

        Raises:
            ValueError: If an error occured.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")
        self._driver.cancel_exposure()

    async def get_full_frame(self, **kwargs: Any) -> Tuple[int, int, int, int]:
        """Returns full size of CCD.

        Returns:
            Tuple with left, top, width, and height set.
        """
        if self._caps is None:
            raise ValueError("No camera driver.")
        return 0, 0, self._caps.uiMaxPixelImageWidth, self._caps.uiMaxPixelImageHeight

    async def get_window(self, **kwargs: Any) -> Tuple[int, int, int, int]:
        """Returns the camera window.

        Returns:
            Tuple with left, top, width, and height set.
        """
        return self._window

    async def get_binning(self, **kwargs: Any) -> Tuple[int, int]:
        """Returns the camera binning.

        Returns:
            Tuple with x and y.
        """
        return self._binning

    async def set_window(self, left: int, top: int, width: int, height: int, **kwargs: Any) -> None:
        """Set the camera window.

        Args:
            left: X offset of window.
            top: Y offset of window.
            width: Width of window.
            height: Height of window.

        Raises:
            ValueError: If binning could not be set.
        """
        self._window = (left, top, width, height)
        log.info("Setting window to %dx%d at %d,%d...", width, height, left, top)

    async def list_binnings(self, **kwargs: Any) -> List[Tuple[int, int]]:
        """List available binnings.

        Returns:
            List of available binnings as (x, y) tuples.
        """
        return [(1, 1), (2, 2), (3, 3), (4, 4)]

    async def set_binning(self, x: int, y: int, **kwargs: Any) -> None:
        """Set the camera binning.

        Args:
            x: X binning.
            y: Y binning.

        Raises:
            ValueError: If binning could not be set.
        """
        self._binning = (x, y)
        log.info("Setting binning to %dx%d...", x, y)

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
        set_temp = self._driver.get_temperature_set_point()
        await asyncio.sleep(0.1)
        return (
            True,
            set_temp,
            self._driver.get_cooler_duty_cycle(),
        )

    async def get_temperatures(self, **kwargs: Any) -> Dict[str, float]:
        """Returns all temperatures measured by this module.

        Returns:
            Dict containing temperatures.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")
        _, t_base, t_cooler = self._driver.get_temperatures()
        # print(self._driver.get_sensor_temperature(), t_base, t_cooler)
        return {"CCD": t_cooler, "Base": t_base}

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

        # set setpoint
        self._driver.set_temperature_set_point(float(setpoint) if setpoint is not None else 20.0)


__all__ = ["FliProCamera"]
