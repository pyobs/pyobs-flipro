# distutils: language = c++

from collections import namedtuple
from enum import Enum
from typing import Tuple, List

import numpy as np
cimport numpy as np
np.import_array()

from libflipro cimport *

cdef class FliProDriver:
    """Wrapper for the FLI driver."""

    @staticmethod
    def get_api_version() -> str:
        cdef LIBFLIPRO_API success
        cdef wchar_t[100] version
        cdef uint32_t length = 100

        success = FPROCam_GetAPIVersion(version, length)