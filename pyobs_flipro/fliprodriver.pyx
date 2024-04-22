# distutils: language = c

from collections import namedtuple
from enum import Enum
from typing import Tuple, List, Optional
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

import numpy as np
cimport numpy as np
np.import_array()


from pyobs_flipro.libflipro cimport *


cdef class DeviceInfo:
    cdef FPRODEVICEINFO obj
    def __init__(self, obj):
        self.obj = obj

    def __decode(self, w):
        b = bytes(w)
        b = b[:b.index(b"\x00")]
        return b.decode('utf-8')

    @property
    def friendly_name(self):
        return self.__decode(self.obj.cFriendlyName)

    @property
    def serial_number(self):
        return self.__decode(self.obj.cSerialNo)

    @property
    def device_path(self):
        return self.__decode(self.obj.cDevicePath)

    @property
    def conn_type(self)
        return "USB" if self.obj.eConnType == FPRO_CONNECTION_USB else "FIBRE"

    @property
    def vendor_id(self):
        return self.obj.uiVendorId

    @property
    def prod_id(self):
        return self.obj.uiProdId

    @property
    def usb_speed(self):
        return {
            FPRO_USB_FULLSPEED: "FULLSPEED",
            FPRO_USB_HIGHSPEED: "HIGHSPEED",
            FPRO_USB_SUPERSPEED: "SUPERSPEED"
        }[self.obj.eUSBSpeed]


class DeviceCaps:
    def __init__(self, obj):
        self.uiSize = obj["uiSize"]
        self.uiCapVersion = obj["uiCapVersion"]
        self.uiDeviceType = obj["uiDeviceType"]
        self.uiMaxPixelImageWidth = obj["uiMaxPixelImageWidth"]
        self.uiMaxPixelImageHeight = obj["uiMaxPixelImageHeight"]
        self.uiAvailablePixelDepths = obj["uiAvailablePixelDepths"]
        self.uiBinningsTableSize = obj["uiBinningsTableSize"]
        self.uiBlackLevelMax = obj["uiBlackLevelMax"]
        self.uiBlackSunMax = obj["uiBlackSunMax"]
        self.uiLowGain = obj["uiLowGain"]
        self.uiHighGain = obj["uiHighGain"]
        self.uiReserved = obj["uiReserved"]
        self.uiRowScanTime = obj["uiRowScanTime"]
        self.uiDummyPixelNum = obj["uiDummyPixelNum"]
        self.bHorizontalScanInvertable = obj["bHorizontalScanInvertable"]
        self.bVerticalScanInvertable = obj["bVerticalScanInvertable"]
        self.uiNVStorageAvailable = obj["uiNVStorageAvailable"]
        self.uiPreFrameReferenceRows = obj["uiPreFrameReferenceRows"]
        self.uiPostFrameReferenceRows = obj["uiPostFrameReferenceRows"]
        self.uiMetaDataSize = obj["uiMetaDataSize"]


cdef class FliProDriver:
    """Wrapper for the FLI driver."""

    cdef DeviceInfo _device_info
    cdef FPRODEVICEINFO _device
    cdef int32_t _handle

    @staticmethod
    def get_api_version() -> str:
        cdef LIBFLIPRO_API success
        cdef wchar_t[100] version
        cdef uint32_t length = 100

        success = FPROCam_GetAPIVersion(version, length)

    @staticmethod
    def list_devices() -> List[DeviceInfo]:
        cdef FPRODEVICEINFO pDeviceInfo[10]
        cdef uint32_t pNumDevices = 10

        # get list of cameras
        if FPROCam_GetCameraList(pDeviceInfo, &pNumDevices) < 0:
            raise ValueError('Could not fetch list of devices.')

        # return DeviceInfos
        devices = [DeviceInfo(pDeviceInfo[i]) for i in range(pNumDevices)]
        return devices

    def __init__(self, device_info: DeviceInfo):
        self._device_info = device_info
        self._device = device_info.obj
        self._handle = 0

    @property
    def device(self):
        return self._device_info

    def open(self):
        if FPROCam_Open(&self._device, &self._handle) < 0:
            raise ValueError('Could not open camera.')

    def close(self):
        if FPROCam_Close(self._handle) < 0:
            raise ValueError('Could not close camera.')

    def get_capabilities(self):
        cdef FPROCAP pCap
        cdef uint32_t pCapLength = sizeof(FPROCAP)
        if FPROSensor_GetCapabilities(self._handle, &pCap, &pCapLength) < 0:
            raise ValueError('Could not fetch camera capabalities.')
        return DeviceCaps(pCap)

    def get_image_area(self) -> Tuple[int, int, int, int]:
        cdef uint32_t pColOffset, pRowOffset, pWidth, pHeight
        if FPROFrame_GetImageArea(self._handle, &pColOffset, &pRowOffset, &pWidth, &pHeight) < 0:
            raise ValueError('Could not fetch image area.')
        return pColOffset, pRowOffset, pWidth, pHeight

    def set_image_area(self, col_offset, row_offset, width, height):
        if FPROFrame_SetImageArea(self._handle, col_offset, row_offset, width, height) < 0:
            raise ValueError('Could not set image area.')

    def get_exposure_time(self) -> int:
        cdef uint64_t pExposureTime, pDelay
        cdef bool immediately
        if FPROCtrl_GetExposure(self._handle, &pExposureTime, &pDelay, &immediately) < 0:
            raise ValueError('Could not fetch exposure time.')
        return pExposureTime

    def set_exposure_time(self, exptime_ns: int):
        cdef LIBFLIPRO_API success
        cdef bool immediately = False
        if FPROCtrl_SetExposure(self._handle, exptime_ns, 0, immediately) < 0:
            raise ValueError('Could not set exposure time.')

    def get_frame_size(self):
        # calculate size of the frame to retrieve from camera
        return FPROFrame_ComputeFrameSize(self._handle)

    def start_exposure(self):
        # start exposure
        if FPROFrame_CaptureStart(self._handle, 1) < 0:
            raise ValueError('Could not start exposure.')

    def read_exposure(self, frame_size):
        # allocate memory
        cdef uint32_t c_frame_size = frame_size
        cdef uint8_t *frame_data = <uint8_t *> malloc(c_frame_size * sizeof(uint8_t))

        # create buffers, only request merged image
        cdef FPROUNPACKEDIMAGES buffers
        buffers.pMergedImage = NULL
        buffers.pMetaData = NULL
        buffers.pHighImage = NULL
        buffers.pLowImage = NULL
        buffers.bMergedImageRequest = True
        buffers.bMetaDataRequest = False
        buffers.bHighImageRequest = False
        buffers.bLowImageRequest = False

        # create stats, don't request anything
        cdef FPROUNPACKEDSTATS stats
        stats.bLowRequest = False
        stats.bHighRequest = False
        stats.bMergedRequest = False

        # get image size
        _, _, width, height = self.get_image_area()
        xbin, ybin = self.get_binning()
        width = width // xbin
        height = height // ybin

        # read frame
        # TODO: this fails on images that have not full width of sensor
        if FPROFrame_GetVideoFrameUnpacked(self._handle, frame_data, &c_frame_size, 100, &buffers, &stats) < 0:
            raise ValueError('Could not fetch frame.')

        # check size
        if width * height * sizeof(uint16_t) != buffers.uiMergedBufferSize:
            raise ValueError('Invalid image size.')

        # create numpy array of given dimensions
        cdef np.ndarray data = np.empty((height, width), dtype=np.ushort)

        # get pointer to data and copy data
        cdef void* raw_data = <void*> data.data
        memcpy(raw_data, buffers.pMergedImage, buffers.uiMergedBufferSize)

        # clean up and return image
        free(frame_data)
        FPROFrame_FreeUnpackedBuffers(&buffers)
        return data

    def stop_exposure(self):
        # start exposure
        if FPROFrame_CaptureStop(self._handle) < 0:
            raise ValueError('Could not stop exposure.')

    def is_available(self):
        cdef bool pAvailable
        if  FPROFrame_IsAvailable(self._handle, &pAvailable) < 0:
            raise ValueError('Could not fetch exposure status.')
        return pAvailable

    def get_sensor_temperature(self):
        cdef int32_t pTemp
        if FPROCtrl_GetSensorTemperature(self._handle, &pTemp) < 0:
            raise ValueError('Could not fetch sensor temperature.')
        return pTemp

    def get_temperatures(self):
        cdef double pAmbientTemp, pBaseTemp, pCoolerTemp
        if FPROCtrl_GetTemperatures(self._handle, &pAmbientTemp, &pBaseTemp, &pCoolerTemp) < 0:
            raise ValueError('Could not fetch temperatures.')
        return pAmbientTemp, pBaseTemp, pCoolerTemp

    def get_temperature_set_point(self):
        cdef double pSetPoint
        if FPROCtrl_GetTemperatureSetPoint(self._handle, &pSetPoint) < 0:
            raise ValueError('Could not get setpoint temperature.')
        return pSetPoint

    def set_temperature_set_point(self, temp):
        cdef double dblSetPoint = temp
        if FPROCtrl_SetTemperatureSetPoint(self._handle, dblSetPoint) < 0:
            raise ValueError('Could not fetch setpoint temperature.')

    def get_cooler_duty_cycle(self):
        cdef uint32_t pDutyCycle
        if FPROCtrl_GetCoolerDutyCycle(self._handle, &pDutyCycle) < 0:
            raise ValueError('Could not fetch cooler duty cycle.')
        return pDutyCycle

    def get_binning(self):
        cdef uint32_t pXBin, pYBin
        if FPROSensor_GetBinning(self._handle, &pXBin, &pYBin) < 0:
            raise ValueError('Could not fetch binning.')
        return pXBin, pYBin

    def set_binning(self, x, y):
        if FPROSensor_SetBinning(self._handle, x, y) < 0:
            raise ValueError('Could not set binning.')