# distutils: language = c

from collections import namedtuple
from enum import Enum
from typing import Tuple, List
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

import numpy as np
cimport numpy as np
np.import_array()


from libflipro cimport *


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


cdef class FliProDriver:
    """Wrapper for the FLI driver."""

    cdef FPRODEVICEINFO device
    cdef int32_t _handle

    @staticmethod
    def get_api_version() -> str:
        cdef LIBFLIPRO_API success
        cdef wchar_t[100] version
        cdef uint32_t length = 100

        success = FPROCam_GetAPIVersion(version, length)

    @staticmethod
    def list_devices() -> List[DeviceInfo]:
        cdef LIBFLIPRO_API success
        cdef FPRODEVICEINFO pDeviceInfo[10]
        cdef uint32_t pNumDevices = 10

        success = FPROCam_GetCameraList(pDeviceInfo, &pNumDevices)

        devices = [DeviceInfo(pDeviceInfo[i]) for i in range(pNumDevices)]
        return devices

    def __init__(self, device_info: DeviceInfo):
        self.device = device_info.obj
        self._handle = 0

    def open(self):
        cdef LIBFLIPRO_API success
        success = FPROCam_Open(&self.device, &self._handle)

    def close(self):
        cdef LIBFLIPRO_API success
        success = FPROCam_Close(self._handle)

    def get_image_area(self) -> Tuple[int, int, int, int]:
        cdef LIBFLIPRO_API success
        cdef uint32_t pColOffset, pRowOffset, pWidth, pHeight
        success = FPROFrame_GetImageArea(self._handle, &pColOffset, &pRowOffset, &pWidth, &pHeight)
        return pColOffset, pRowOffset, pWidth, pHeight

    def set_image_area(self, col_offset, row_offset, width, height):
        cdef LIBFLIPRO_API success
        success = FPROFrame_SetImageArea(self._handle, col_offset, row_offset, width, height)

    def get_exposure_time(self) -> int:
        cdef LIBFLIPRO_API success
        cdef uint64_t pExposureTime, pDelay
        cdef bool immediately
        success = FPROCtrl_GetExposure(self._handle, &pExposureTime, &pDelay, &immediately)
        print('FPROCtrl_GetExposure', success)
        print(pExposureTime, pDelay, immediately)
        return pExposureTime

    def set_exposure_time(self, exptime_ns: int):
        cdef LIBFLIPRO_API success
        cdef bool immediately = False
        print(exptime_ns)
        success = FPROCtrl_SetExposure(self._handle, exptime_ns, 0, immediately)
        print('FPROCtrl_SetExposure', success)

    def get_frame_size(self):
        # calculate size of the frame to retrieve from camera
        return FPROFrame_ComputeFrameSize(self._handle)

    def start_exposure(self):
        # start exposure
        success = FPROFrame_CaptureStart(self._handle, 1)
        print('start', success)

    def read_exposure(self, frame_size):
        cdef LIBFLIPRO_API success

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
        success = FPROFrame_GetVideoFrameUnpacked(self._handle, frame_data, &c_frame_size, 100, &buffers, &stats)

        # check size
        print(width * height * sizeof(uint16_t), buffers.uiMergedBufferSize)
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
        success = FPROFrame_CaptureStop(self._handle)

    def is_available(self):
        cdef bool pAvailable
        success = FPROFrame_IsAvailable(self._handle, &pAvailable)
        return pAvailable

    def get_sensor_temperature(self):
        cdef LIBFLIPRO_API success
        cdef int32_t pTemp
        success = FPROCtrl_GetSensorTemperature(self._handle, &pTemp)
        return pTemp

    def get_temperatures(self):
        cdef LIBFLIPRO_API success
        cdef double pAmbientTemp, pBaseTemp, pCoolerTemp
        success = FPROCtrl_GetTemperatures(self._handle, &pAmbientTemp, &pBaseTemp, &pCoolerTemp)
        return pAmbientTemp, pBaseTemp, pCoolerTemp

    def get_temperature_set_point(self):
        cdef LIBFLIPRO_API success
        cdef double pSetPoint
        success = FPROCtrl_GetTemperatureSetPoint(self._handle, &pSetPoint)
        return pSetPoint

    def set_temperature_set_point(self, temp):
        cdef LIBFLIPRO_API success
        cdef double dblSetPoint = temp
        success = FPROCtrl_SetTemperatureSetPoint(self._handle, dblSetPoint)

    def get_cooler_duty_cycle(self):
        cdef LIBFLIPRO_API success
        cdef uint32_t pDutyCycle
        success = FPROCtrl_GetCoolerDutyCycle(self._handle, &pDutyCycle)
        return pDutyCycle

    def get_binning(self):
        cdef uint32_t pXBin, pYBin
        success = FPROSensor_GetBinning(self._handle, &pXBin, &pYBin)
        return pXBin, pYBin

    def set_binning(self, x, y):
        success = FPROSensor_SetBinning(self._handle, x, y)