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
    def __getattr__(self, item):
        return getattr(self.obj, item)


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