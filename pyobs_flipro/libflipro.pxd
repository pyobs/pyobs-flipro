from libc.stdint cimport int32_t, uint32_t, uint8_t, uint16_t, uint64_t
from libc.stddef cimport wchar_t
from libcpp cimport bool


cdef extern from "../lib/libflipro.h":
    ctypedef int32_t LIBFLIPRO_API
    ctypedef void LIBFLIPRO_VOID

    ctypedef enum FPROCONNECTION: FPRO_CONNECTION_USB, FPRO_CONNECTION_FIBRE
    ctypedef enum FPROUSBSPEED: FPRO_USB_FULLSPEED, FPRO_USB_HIGHSPEED, FPRO_USB_SUPERSPEED
    ctypedef enum FPRO_MERGEALGO: FPROMERGE_ALGO, FPROMERGE_ALGO_REF_FRAME

    ctypedef struct FPRO_CROP:
        uint32_t uiColumnOffset
        uint32_t uiRowOffset
        uint32_t uiWidth
        uint32_t uiHeight

    ctypedef struct FPRODEVICEINFO:
        wchar_t cFriendlyName[256]
        wchar_t cSerialNo[256]
        wchar_t cDevicePath[1024]
        FPROCONNECTION eConnType
        uint32_t uiVendorId
        uint32_t uiProdId
        FPROUSBSPEED eUSBSpeed
    
    ctypedef struct FPROPOINT:
        int32_t X
        int32_t Y
    
    ctypedef struct FPROPIXELINFO:
        FPROPOINT ptPosition
        uint32_t  uiValue
    
    ctypedef struct FPROPLANESTATS:
        uint32_t uiLCutoff
        uint32_t uiUCutoff
        uint32_t uiHistogramSize
        double *pdblHistogram
        double   dblMean
        double   dblMedian
        double   dblMode
        double   dblStandardDeviation
        FPROPIXELINFO pixBrightest
        FPROPIXELINFO pixDimmest
    
    ctypedef struct FPROUNPACKEDIMAGES:
        uint8_t  *pMetaData
        uint32_t uiMetaDataSize
        bool     bMetaDataRequest
        uint16_t *pLowImage
        uint64_t uiLowImageSize
        uint64_t uiLowBufferSize
        bool     bLowImageRequest
        uint16_t *pHighImage
        uint64_t uiHighImageSize
        uint64_t uiHighBufferSize
        bool     bHighImageRequest
        uint16_t *pMergedImage
        uint64_t uiMergedImageSize
        uint64_t uiMergedBufferSize
        bool     bMergedImageRequest
        FPRO_MERGEALGO eMergAlgo

    ctypedef struct FPROUNPACKEDSTATS:
        FPROPLANESTATS statsLowImage;
        bool     bLowRequest;
        FPROPLANESTATS statsHighImage;
        bool     bHighRequest;
        FPROPLANESTATS statsMergedImage;
        bool     bMergedRequest;

    ctypedef struct FPROCAP:
        uint32_t uiSize;
        uint32_t uiCapVersion;
        uint32_t uiDeviceType;
        uint32_t uiMaxPixelImageWidth;
        uint32_t uiMaxPixelImageHeight;
        uint32_t uiAvailablePixelDepths;
        uint32_t uiBinningsTableSize;
        uint32_t uiBlackLevelMax;
        uint32_t uiBlackSunMax;
        uint32_t uiLowGain;
        uint32_t uiHighGain;
        uint32_t uiReserved;
        uint32_t uiRowScanTime;
        uint32_t uiDummyPixelNum;
        bool     bHorizontalScanInvertable;
        bool     bVerticalScanInvertable;
        uint32_t uiNVStorageAvailable;
        uint32_t uiPreFrameReferenceRows;
        uint32_t uiPostFrameReferenceRows;
        uint32_t uiMetaDataSize;


    LIBFLIPRO_API FPROCam_GetAPIVersion(wchar_t *pVersion, uint32_t uiLength)
    LIBFLIPRO_API FPROCam_GetCameraList(FPRODEVICEINFO *pDeviceInfo, uint32_t *pNumDevices)
    LIBFLIPRO_API FPROCam_Open(FPRODEVICEINFO *pDevInfo, int32_t *pHandle)
    LIBFLIPRO_API FPROCam_Close(int32_t iHandle)
    LIBFLIPRO_API FPROFrame_GetImageArea(int32_t iHandle, uint32_t *pColOffset, uint32_t *pRowOffset, uint32_t *pWidth,
                                         uint32_t *pHeight)
    LIBFLIPRO_API FPROFrame_SetImageArea(int32_t iHandle, uint32_t uiColOffset, uint32_t uiRowOffset, uint32_t uiWidth,
                                         uint32_t uiHeight)
    LIBFLIPRO_API FPROCtrl_GetExposure(int32_t iHandle, uint64_t *pExposureTime, uint64_t *pFrameDelay,
                                       bool *pImmediate);
    LIBFLIPRO_API FPROCtrl_SetExposure(int32_t iHandle, uint64_t uiExposureTime, uint64_t uiFrameDelay,
                                       bool bImmediate);
    LIBFLIPRO_API FPROFrame_CaptureStart(int32_t iHandle, uint32_t uiFrameCount)
    LIBFLIPRO_API FPROFrame_CaptureStop(int32_t iHandle)
    LIBFLIPRO_API FPROFrame_ComputeFrameSize(int32_t iHandle)
    LIBFLIPRO_VOID FPROFrame_FreeUnpackedBuffers(FPROUNPACKEDIMAGES *pUPBuffers)
    LIBFLIPRO_API FPROFrame_GetVideoFrame(int32_t iHandle, uint8_t *pFrameData, uint32_t *pSize, uint32_t uiTimeoutMS)
    LIBFLIPRO_API FPROFrame_GetVideoFrameUnpacked(int32_t iHandle, uint8_t *pFrameData, uint32_t *pSize,
                                                  uint32_t uiTimeoutMS, FPROUNPACKEDIMAGES *pUPBuffers,
                                                  FPROUNPACKEDSTATS *pStats);
    LIBFLIPRO_API FPROCtrl_GetSensorTemperature(int32_t iHandle, int32_t *pTemp);
    LIBFLIPRO_API FPROCtrl_GetTemperatures(int32_t iHandle, double *pAmbientTemp, double *pBaseTemp,
                                           double *pCoolerTemp);
    LIBFLIPRO_API FPROCtrl_GetTemperatureSetPoint(int32_t iHandle, double *pSetPoint);
    LIBFLIPRO_API FPROCtrl_SetTemperatureSetPoint(int32_t iHandle, double dblSetPoint);
    LIBFLIPRO_API FPROCtrl_GetCoolerDutyCycle(int32_t iHandle, uint32_t *pDutyCycle);
    LIBFLIPRO_API FPROFrame_IsAvailable(int32_t iHandle, bool *pAvailable);
    LIBFLIPRO_API FPROSensor_GetBinning(int32_t iHandle, uint32_t *pXBin, uint32_t *pYBin)
    LIBFLIPRO_API FPROSensor_SetBinning(int32_t iHandle, uint32_t uiXBin, uint32_t uiYBin);
    LIBFLIPRO_API FPROSensor_GetCapabilities(int32_t iHandle, FPROCAP *pCap, uint32_t *pCapLength);