# distutils: language = c++

from collections import namedtuple
from enum import Enum
from typing import Tuple, List

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


cdef class FliProDriver:
    """Wrapper for the FLI driver."""

    cdef FPRODEVICEINFO _device_info
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
        self._device_info = device_info.obj
        self._handle = 0

    def open(self):
        cdef LIBFLIPRO_API success
        success = FPROCam_Open(&self._device_info, &self._handle)

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
        return pExposureTime

    def set_exposure_time(self, exptime_ns: int):
        cdef LIBFLIPRO_API success
        cdef bool immediately = False
        success = FPROCtrl_SetExposure(self._handle, exptime_ns, 0, immediately)