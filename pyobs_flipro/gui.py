import asyncio
import sys
import time

import qasync  # type: ignore[import-untyped]
from astropy.io import fits
from pyobs.utils.gui.camera import BinningWidget, DataDisplayWidget, ExposeWidget, ExposureTimeWidget, ListPickerDialog
from pyobs.utils.gui.camera.windowingwidget import WindowingWidget
from PySide6 import QtCore, QtWidgets  # type: ignore[import-untyped]

from .fliprodriver import FliProDriver  # type: ignore[import-untyped]


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self, device_info) -> None:
        super().__init__()
        self.setWindowTitle("FLIPRO Camera")

        self._driver = FliProDriver(device_info)
        self._driver.open()
        caps = self._driver.get_capabilities()

        self._abort_event = asyncio.Event()

        # --- layout: controls on left, image on right ---
        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        global_layout = QtWidgets.QHBoxLayout(central)

        controls = QtWidgets.QGroupBox("Controls")
        global_layout.addWidget(controls)
        layout = QtWidgets.QVBoxLayout(controls)

        self._window_widget = WindowingWidget(caps.uiMaxPixelImageWidth, caps.uiMaxPixelImageHeight)
        layout.addWidget(self._window_widget)

        self._binning_widget = BinningWidget([(1, 1), (2, 2), (3, 3), (4, 4)])
        self._binning_widget.binning_changed.connect(self._window_widget.set_binning)
        layout.addWidget(self._binning_widget)

        self._exposure_time = ExposureTimeWidget()
        layout.addWidget(self._exposure_time)

        self._expose_widget = ExposeWidget()
        self._expose_widget.expose_clicked.connect(self._expose_clicked)
        self._expose_widget.abort_clicked.connect(self._abort_clicked)
        layout.addWidget(self._expose_widget)

        # temperature readout
        temp_group = QtWidgets.QGroupBox("Temperature")
        temp_layout = QtWidgets.QFormLayout(temp_group)
        self._label_ccd = QtWidgets.QLabel("—")
        self._label_base = QtWidgets.QLabel("—")
        self._label_setpoint = QtWidgets.QLabel("—")
        self._label_power = QtWidgets.QLabel("—")
        temp_layout.addRow("CCD:", self._label_ccd)
        temp_layout.addRow("Base:", self._label_base)
        temp_layout.addRow("Setpoint:", self._label_setpoint)
        temp_layout.addRow("Cooler:", self._label_power)
        layout.addWidget(temp_group)
        layout.addStretch()

        self._data_display = DataDisplayWidget()
        global_layout.addWidget(self._data_display)

        # periodic temperature refresh
        self._temp_timer = QtCore.QTimer()
        self._temp_timer.timeout.connect(self._refresh_temp)
        self._temp_timer.start(5000)
        self._refresh_temp()

    def _refresh_temp(self) -> None:
        try:
            _, t_base, t_cooler = self._driver.get_temperatures()
            setpoint = self._driver.get_temperature_set_point()
            duty = self._driver.get_cooler_duty_cycle()
            self._label_ccd.setText(f"{t_cooler:.1f} °C")
            self._label_base.setText(f"{t_base:.1f} °C")
            self._label_setpoint.setText(f"{setpoint:.1f} °C")
            self._label_power.setText(f"{duty:.0f} %")
        except Exception:
            pass

    @qasync.asyncSlot(int)  # type: ignore[misc]
    async def _expose_clicked(self, count: int) -> None:
        x, y, width, height = self._window_widget.values
        idx = self._binning_widget.combo_binnings.currentIndex()
        xbin, ybin = self._binning_widget._binnings[idx]  # noqa: SLF001

        self._driver.set_binning(xbin, ybin)
        self._driver.set_image_area(x, y, width, height)
        self._driver.set_exposure_time(int(self._exposure_time.value * 1e9))
        frame_size = self._driver.get_frame_size()

        loop = asyncio.get_running_loop()
        for i in range(count):
            if self._abort_event.is_set():
                break

            self._expose_widget.start_exposure(self._exposure_time.value)
            self._driver.start_exposure()
            await loop.run_in_executor(None, self._wait_for_frame)
            data = self._driver.read_exposure(frame_size)
            self._driver.stop_exposure()

            self._expose_widget.set_exposures_left(count - i - 1)
            self._data_display.set_data(fits.PrimaryHDU(data))
            self._refresh_temp()

        self._abort_event.clear()

    def _wait_for_frame(self) -> None:
        while not self._driver.is_available():
            time.sleep(0.01)

    @qasync.asyncSlot()  # type: ignore[misc]
    async def _abort_clicked(self) -> None:
        self._abort_event.set()

    def closeEvent(self, event) -> None:  # type: ignore[override]
        self._temp_timer.stop()
        self._driver.close()
        super().closeEvent(event)


async def async_main(app: QtWidgets.QApplication) -> None:
    devices = FliProDriver.list_devices()
    if not devices:
        QtWidgets.QMessageBox.critical(None, "Error", "No FLIPRO camera found.")
        return

    if len(devices) > 1:
        picker = ListPickerDialog([d.friendly_name for d in devices])
        if picker.exec() != QtWidgets.QDialog.DialogCode.Accepted:
            return
        device = devices[picker.comboBox().currentIndex()]
    else:
        device = devices[0]

    app_close_event = asyncio.Event()
    app.aboutToQuit.connect(app_close_event.set)

    window = MainWindow(device)
    window.show()

    await app_close_event.wait()


def main() -> None:
    app = QtWidgets.QApplication(sys.argv)
    asyncio.run(async_main(app), loop_factory=qasync.QEventLoop)  # type: ignore[arg-type]


if __name__ == "__main__":
    main()
