import asyncio
import logging
import math
from datetime import UTC, datetime
from typing import Any

import numpy as np
from pyobs.images import Image
from pyobs.interfaces import IAbortable, IBinning, ICamera, ICooling, ITemperatures, IWindow
from pyobs.interfaces.IBinning import BinningCapabilities, BinningState
from pyobs.interfaces.ICooling import CoolingState
from pyobs.interfaces.ITemperatures import SensorReading, TemperaturesState
from pyobs.interfaces.IWindow import WindowCapabilities, WindowState
from pyobs.modules.camera.basecamera import BaseCamera
from pyobs.utils.enums import ExposureStatus

log = logging.getLogger(__name__)


class FliProCamera(BaseCamera, ICamera, IAbortable, IWindow, IBinning, ICooling, ITemperatures):
    """A pyobs module for FLIPRO cameras."""

    __module__ = "pyobs_flipro"

    def __init__(self, setpoint: float, **kwargs: Any):
        """Initializes a new FliProCamera.

        Args:
            setpoint: Cooling temperature setpoint.
        """
        BaseCamera.__init__(self, **kwargs)
        from .fliprodriver import DeviceCaps, DeviceInfo, FliProDriver  # type: ignore

        # variables
        self._driver: FliProDriver | None = None
        self._device: DeviceInfo | None = None
        self._caps: DeviceCaps | None = None
        self._temp_setpoint: float | None = setpoint

        # window, binning, and full frame
        self._full_frame = (0, 0, 0, 0)
        self._window = (0, 0, 0, 0)
        self._binning = (1, 1)

        # cooling state
        self._cooling_enabled = False

        # background task for polling cooling/temperature
        self.add_background_task(self._poll_cooling)

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
            raise ValueError(f"Could not open FLIPRO camera: {e}")

        # get caps
        self._caps = self._driver.get_capabilities()
        self._log_capabilities()

        # store full frame from caps
        self._full_frame = (0, 0, self._caps.uiMaxPixelImageWidth, self._caps.uiMaxPixelImageHeight)

        # set cooling
        if self._temp_setpoint is not None:
            await self.set_cooling(True, self._temp_setpoint)

        # get window and binning from driver
        self._window = self._driver.get_image_area()
        self._binning = self._driver.get_binning()

        # publish capabilities and initial states
        await self.comm.set_capabilities(
            IWindow,
            WindowCapabilities(
                full_frame_x=self._full_frame[0],
                full_frame_y=self._full_frame[1],
                full_frame_width=self._full_frame[2],
                full_frame_height=self._full_frame[3],
            ),
        )
        await self.comm.set_state(
            IWindow, WindowState(x=self._window[0], y=self._window[1], width=self._window[2], height=self._window[3])
        )
        await self.comm.set_capabilities(
            IBinning,
            BinningCapabilities(
                binnings=[
                    BinningState(x=1, y=1),
                    BinningState(x=2, y=2),
                    BinningState(x=3, y=3),
                    BinningState(x=4, y=4),
                ]
            ),
        )
        await self.comm.set_state(IBinning, BinningState(x=self._binning[0], y=self._binning[1]))

    async def close(self) -> None:
        """Close the module."""
        await BaseCamera.close(self)

        if self._driver is not None:
            self._driver.close()
            self._driver = None

    def _log_device_info(self) -> None:
        log.info("Device info:")
        log.info("  - Friendly Name: %s", self._device.friendly_name)
        log.info("  - Serial No:     %s", self._device.serial_number)
        log.info("  - Device Path:   %s", self._device.device_path)
        log.info("  - Conn Type:     %s", self._device.conn_type)
        log.info("  - Vendor ID:     %s", self._device.vendor_id)
        log.info("  - Prod ID:       %s", self._device.prod_id)
        log.info("  - USB Speed:     %s", self._device.usb_speed)

    def _log_capabilities(self) -> None:
        log.info("Capabilities:")
        log.info("  - Version:                    %s", self._caps.uiCapVersion)
        log.info("  - Device Type:                %s", self._caps.uiDeviceType)
        log.info("  - Max Pixel Image Width:      %s", self._caps.uiMaxPixelImageWidth)
        log.info("  - Max Pixel Image Height:     %s", self._caps.uiMaxPixelImageHeight)
        log.info("  - Available Pixel Depths:     %s", self._caps.uiAvailablePixelDepths)
        log.info("  - Binning Table Size:         %s", self._caps.uiBinningsTableSize)
        log.info("  - Black Level Max:            %s", self._caps.uiBlackLevelMax)
        log.info("  - Black Sun Max:              %s", self._caps.uiBlackSunMax)
        log.info("  - Low Gain:                   %s", self._caps.uiLowGain)
        log.info("  - High Gain:                  %s", self._caps.uiHighGain)
        log.info("  - Row Scan Time:              %s", self._caps.uiRowScanTime)
        log.info("  - Dummy Pixel Num:            %s", self._caps.uiDummyPixelNum)
        log.info("  - Horizontal Scan Invertable: %s", self._caps.bHorizontalScanInvertable)
        log.info("  - Vertical Scan Invertable:   %s", self._caps.bVerticalScanInvertable)
        log.info("  - NV Storage Available:       %s", self._caps.uiNVStorageAvailable)
        log.info("  - Pre Frame Reference Rows:   %s", self._caps.uiPreFrameReferenceRows)
        log.info("  - Post Frame Reference Rows:  %s", self._caps.uiPostFrameReferenceRows)
        log.info("  - Meta Data Size:             %s", self._caps.uiMetaDataSize)

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
        date_obs = datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f")

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
        self.set_biassec_trimsec(image.header, *self._full_frame)

        # return FITS image
        log.info("Readout finished.")
        return image

    async def _wait_exposure(self, abort_event: asyncio.Event, exposure_time: float, open_shutter: bool) -> None:
        """Wait for exposure to finish."""
        while not self._driver.is_available():
            if abort_event.is_set():
                await self._change_exposure_status(ExposureStatus.IDLE)
                raise InterruptedError("Aborted exposure.")
            await asyncio.sleep(0.01)

    async def _abort_exposure(self) -> None:
        """Abort the running exposure."""
        if self._driver is None:
            raise ValueError("No camera driver.")
        self._driver.cancel_exposure()

    async def set_window(self, left: int, top: int, width: int, height: int, **kwargs: Any) -> None:
        """Set the camera window.

        Args:
            left: X offset of window.
            top: Y offset of window.
            width: Width of window.
            height: Height of window.
        """
        self._window = (left, top, width, height)
        log.info("Setting window to %dx%d at %d,%d...", width, height, left, top)
        await self.comm.set_state(IWindow, WindowState(x=left, y=top, width=width, height=height))

    async def set_binning(self, x: int, y: int, **kwargs: Any) -> None:
        """Set the camera binning.

        Args:
            x: X binning.
            y: Y binning.
        """
        self._binning = (x, y)
        log.info("Setting binning to %dx%d...", x, y)
        await self.comm.set_state(IBinning, BinningState(x=x, y=y))

    async def set_cooling(self, enabled: bool, setpoint: float | None, **kwargs: Any) -> None:
        """Enables/disables cooling and sets setpoint.

        Args:
            enabled: Enable or disable cooling.
            setpoint: Setpoint in celsius for the cooling.
        """
        if self._driver is None:
            raise ValueError("No camera driver.")

        if enabled:
            log.info("Enabling cooling with a setpoint of %.2f°C...", setpoint)
        else:
            log.info("Disabling cooling and setting setpoint to 20°C...")

        actual_setpoint = float(setpoint) if setpoint is not None else 20.0
        self._driver.set_temperature_set_point(actual_setpoint)
        self._cooling_enabled = enabled
        await self.comm.set_state(ICooling, CoolingState(setpoint=actual_setpoint, power=None, enabled=enabled))

    async def _poll_cooling(self) -> None:
        """Background task: periodically reads cooling status and publishes ICooling and ITemperatures state."""
        while True:
            try:
                if self._driver is not None:
                    setpoint = self._driver.get_temperature_set_point()
                    duty = self._driver.get_cooler_duty_cycle()
                    _, t_base, t_cooler = self._driver.get_temperatures()
                    await self.comm.set_state(
                        ICooling, CoolingState(setpoint=setpoint, power=round(duty), enabled=self._cooling_enabled)
                    )
                    await self.comm.set_state(
                        ITemperatures,
                        TemperaturesState(
                            readings=[
                                SensorReading(name="CCD", value=t_cooler),
                                SensorReading(name="Base", value=t_base),
                            ]
                        ),
                    )
            except Exception:
                pass
            await asyncio.sleep(10)


__all__ = ["FliProCamera"]
