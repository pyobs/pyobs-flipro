from libc.stdint cimport int32_t, uint32_t
from libc.stddef cimport wchar_t

cdef extern from "../lib/libflipro.h":
    ctypedef int32_t LIBFLIPRO_API

    ctypedef enum FPROCONNECTION: FPRO_CONNECTION_USB, FPRO_CONNECTION_FIBRE
    ctypedef enum FPROUSBSPEED: FPRO_USB_FULLSPEED, FPRO_USB_HIGHSPEED, FPRO_USB_SUPERSPEED

    ctypedef struct FPRODEVICEINFO:
        wchar_t cFriendlyName[256]
        wchar_t cSerialNo[256]
        wchar_t cDevicePath[1024]
        FPROCONNECTION eConnType
        uint32_t uiVendorId
        uint32_t uiProdId
        FPROUSBSPEED eUSBSpeed

    LIBFLIPRO_API FPROCam_GetAPIVersion(wchar_t *pVersion, uint32_t uiLength)
    LIBFLIPRO_API FPROCam_GetCameraList(FPRODEVICEINFO *pDeviceInfo, uint32_t *pNumDevices)
    LIBFLIPRO_API FPROCam_Open(FPRODEVICEINFO *pDevInfo, int32_t *pHandle)
    LIBFLIPRO_API FPROCam_Close(int32_t iHandle)
    LIBFLIPRO_API FPROFrame_GetImageArea(int32_t iHandle, uint32_t *pColOffset, uint32_t *pRowOffset, uint32_t *pWidth,
                                         uint32_t *pHeight);

