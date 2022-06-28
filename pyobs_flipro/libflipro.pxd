from libc.stdint cimport int32_t, uint32_t
from libc.stddef cimport wchar_t


cdef extern from "../lib/libflipro.h":
    ctypedef int32_t LIBFLIPRO_API

    LIBFLIPRO_API FPROCam_GetAPIVersion(wchar_t *pVersion, uint32_t uiLength);
