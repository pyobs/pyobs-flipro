cdef extern from "../lib/libfli.h":
    # An opaque handle used by library functions to refer to FLI
    # hardware.
    cdef int FLI_INVALID_DEVICE
    ctypedef long flidev_t

    # The domain of an FLI device.  This consists of a bitwise ORed
    # combination of interface method and device type.  Valid interfaces
    # are \texttt{FLIDOMAIN_PARALLEL_PORT}, \texttt{FLIDOMAIN_USB},
    # \texttt{FLIDOMAIN_SERIAL}, and \texttt{FLIDOMAIN_INET}.  Valid
    # device types are \texttt{FLIDEVICE_CAMERA},
    # \texttt{FLIDOMAIN_FILTERWHEEL}, and \texttt{FLIDOMAIN_FOCUSER}.
    #
    # @see FLIOpen
    # @see FLIList
    ctypedef long flidomain_t

    cdef int FLIDOMAIN_NONE
    cdef int FLIDOMAIN_PARALLEL_PORT
    cdef int FLIDOMAIN_USB
    cdef int FLIDOMAIN_SERIAL
    cdef int FLIDOMAIN_INET
    cdef int FLIDOMAIN_SERIAL_19200
    cdef int FLIDOMAIN_SERIAL_1200

    cdef int FLIDEVICE_NONE
    cdef int FLIDEVICE_CAMERA
    cdef int FLIDEVICE_FILTERWHEEL
    cdef int FLIDEVICE_FOCUSER
    cdef int FLIDEVICE_HS_FILTERWHEEL
    cdef int FLIDEVICE_RAW
    cdef int FLIDEVICE_ENUMERATE_BY_CONNECTION

    # The frame type for an FLI CCD camera device.  Valid frame types are
    # \texttt{FLI_FRAME_TYPE_NORMAL} and \texttt{FLI_FRAME_TYPE_DARK}.
    #
    # @see FLISetFrameType
    ctypedef long fliframe_t

    cdef int FLI_FRAME_TYPE_NORMAL
    cdef int FLI_FRAME_TYPE_DARK
    cdef int FLI_FRAME_TYPE_FLOOD
    cdef int FLI_FRAME_TYPE_RBI_FLUSH

    # The gray-scale bit depth for an FLI camera device.  Valid bit
    # depths are \texttt{FLI_MODE_8BIT} and \texttt{FLI_MODE_16BIT}.
    #
    # @see FLISetBitDepth
    ctypedef long flibitdepth_t

    cdef int FLI_MODE_8BIT
    cdef int FLI_MODE_16BIT

    # Type used for shutter operations for an FLI camera device.  Valid
    # shutter types are \texttt{FLI_SHUTTER_CLOSE},
    # \texttt{FLI_SHUTTER_OPEN},
    # \texttt{FLI_SHUTTER_EXTERNAL_TRIGGER},
    # \texttt{FLI_SHUTTER_EXTERNAL_TRIGGER_LOW}, and
    # \texttt{FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH}.
    #
    # @see FLIControlShutter
    ctypedef long flishutter_t

    cdef int FLI_SHUTTER_CLOSE
    cdef int FLI_SHUTTER_OPEN
    cdef int FLI_SHUTTER_EXTERNAL_TRIGGER
    cdef int FLI_SHUTTER_EXTERNAL_TRIGGER_LOW
    cdef int FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH
    cdef int FLI_SHUTTER_EXTERNAL_EXPOSURE_CONTROL

    # Type used for background flush operations for an FLI camera device.  Valid
    # bgflush types are \texttt{FLI_BGFLUSH_STOP} and
    # \texttt{FLI_BGFLUSH_START}.
    #
    # @see FLIControlBackgroundFlush
    ctypedef long flibgflush_t

    cdef int FLI_BGFLUSH_STOP
    cdef int FLI_BGFLUSH_START

    # Type used to determine which temperature channel to read.  Valid
    # channel types are \texttt{FLI_TEMPERATURE_INTERNAL} and
    # \texttt{FLI_TEMPERATURE_EXTERNAL}.
    #
    # @see FLIReadTemperature
    ctypedef long flichannel_t

    cdef int FLI_TEMPERATURE_INTERNAL
    cdef int FLI_TEMPERATURE_EXTERNAL
    cdef int FLI_TEMPERATURE_CCD
    cdef int FLI_TEMPERATURE_BASE

    # Type specifying library debug levels.  Valid debug levels are
    # \texttt{FLIDEBUG_NONE}, \texttt{FLIDEBUG_INFO},
    # \texttt{FLIDEBUG_WARN}, and \texttt{FLIDEBUG_FAIL}.
    #
    # @see FLISetDebugLevel
    ctypedef long flidebug_t
    ctypedef long flimode_t
    ctypedef long flistatus_t
    ctypedef long flitdirate_t
    ctypedef long flitdiflags_t

    # Status settings
    cdef int FLI_CAMERA_STATUS_UNKNOWN
    cdef int FLI_CAMERA_STATUS_MASK
    cdef int FLI_CAMERA_STATUS_IDLE
    cdef int FLI_CAMERA_STATUS_WAITING_FOR_TRIGGER
    cdef int FLI_CAMERA_STATUS_EXPOSING
    cdef int FLI_CAMERA_STATUS_READING_CCD
    cdef int FLI_CAMERA_DATA_READY

    cdef int FLI_FOCUSER_STATUS_UNKNOWN
    cdef int FLI_FOCUSER_STATUS_HOMING
    cdef int FLI_FOCUSER_STATUS_MOVING_IN
    cdef int FLI_FOCUSER_STATUS_MOVING_OUT
    cdef int FLI_FOCUSER_STATUS_MOVING_MASK
    cdef int FLI_FOCUSER_STATUS_HOME
    cdef int FLI_FOCUSER_STATUS_LIMIT
    cdef int FLI_FOCUSER_STATUS_LEGACY

    cdef int FLI_FILTER_WHEEL_PHYSICAL
    cdef int FLI_FILTER_WHEEL_VIRTUAL
    cdef int FLI_FILTER_WHEEL_LEFT
    cdef int FLI_FILTER_WHEEL_RIGHT
    cdef int FLI_FILTER_STATUS_MOVING_CCW
    cdef int FLI_FILTER_STATUS_MOVING_CW
    cdef int FLI_FILTER_POSITION_UNKNOWN
    cdef int FLI_FILTER_POSITION_CURRENT
    cdef int FLI_FILTER_STATUS_HOMING
    cdef int FLI_FILTER_STATUS_HOME
    cdef int FLI_FILTER_STATUS_HOME_LEFT
    cdef int FLI_FILTER_STATUS_HOME_RIGHT
    cdef int FLI_FILTER_STATUS_HOME_SUCCEEDED

    cdef int FLIDEBUG_NONE
    cdef int FLIDEBUG_INFO
    cdef int FLIDEBUG_WARN
    cdef int FLIDEBUG_FAIL
    cdef int FLIDEBUG_IO
    cdef int FLIDEBUG_ALL

    cdef int FLI_IO_P0
    cdef int FLI_IO_P1
    cdef int FLI_IO_P2
    cdef int FLI_IO_P3

    cdef int FLI_FAN_SPEED_OFF
    cdef int FLI_FAN_SPEED_ON

    cdef int FLI_EEPROM_USER
    cdef int FLI_EEPROM_PIXEL_MAP

    cdef int FLI_PIXEL_DEFECT_COLUMN
    cdef int FLI_PIXEL_DEFECT_CLUSTER
    cdef int FLI_PIXEL_DEFECT_POINT_BRIGHT
    cdef int FLI_PIXEL_DEFECT_POINT_DARK
    
    long FLIOpen(flidev_t *dev, char *name, flidomain_t domain)
    long FLISetDebugLevel(char *host, flidebug_t level)
    long FLIClose(flidev_t dev)
    long FLIGetLibVersion(char* ver, size_t len)
    long FLIGetModel(flidev_t dev, char* model, size_t len)
    long FLIGetPixelSize(flidev_t dev, double *pixel_x, double *pixel_y)
    long FLIGetHWRevision(flidev_t dev, long *hwrev)
    long FLIGetFWRevision(flidev_t dev, long *fwrev)
    long FLIGetArrayArea(flidev_t dev, long* ul_x, long* ul_y, long* lr_x, long* lr_y)
    long FLIGetVisibleArea(flidev_t dev, long* ul_x, long* ul_y, long* lr_x, long* lr_y)
    long FLISetExposureTime(flidev_t dev, long exptime)
    long FLISetImageArea(flidev_t dev, long ul_x, long ul_y, long lr_x, long lr_y)
    long FLISetHBin(flidev_t dev, long hbin)
    long FLISetVBin(flidev_t dev, long vbin)
    long FLISetFrameType(flidev_t dev, fliframe_t frametype)
    long FLICancelExposure(flidev_t dev)
    long FLIGetExposureStatus(flidev_t dev, long *timeleft)
    long FLISetTemperature(flidev_t dev, double temperature)
    long FLIGetTemperature(flidev_t dev, double *temperature)
    long FLIGetCoolerPower(flidev_t dev, double *power)
    long FLIGrabRow(flidev_t dev, void *buff, size_t width)
    long FLIExposeFrame(flidev_t dev)
    long FLIFlushRow(flidev_t dev, long rows, long repeat)
    long FLISetNFlushes(flidev_t dev, long nflushes)
    long FLISetBitDepth(flidev_t dev, flibitdepth_t bitdepth)
    long FLIReadIOPort(flidev_t dev, long *ioportset)
    long FLIWriteIOPort(flidev_t dev, long ioportset)
    long FLIConfigureIOPort(flidev_t dev, long ioportset)
    long FLILockDevice(flidev_t dev)
    long FLIUnlockDevice(flidev_t dev)
    long FLIControlShutter(flidev_t dev, flishutter_t shutter)
    long FLIControlBackgroundFlush(flidev_t dev, flibgflush_t bgflush)
    long FLISetDAC(flidev_t dev, unsigned long dacset)
    long FLIList(flidomain_t domain, char ***names)
    long FLIFreeList(char **names)
    
    long FLIGetFilterName(flidev_t dev, long filter, char *name, size_t len)
    long FLISetActiveWheel(flidev_t dev, long wheel)
    long FLIGetActiveWheel(flidev_t dev, long *wheel)
    
    long FLISetFilterPos(flidev_t dev, long filter)
    long FLIGetFilterPos(flidev_t dev, long *filter)
    long FLIGetFilterCount(flidev_t dev, long *filter)
    
    long FLIStepMotor(flidev_t dev, long steps)
    long FLIStepMotorAsync(flidev_t dev, long steps)
    long FLIGetStepperPosition(flidev_t dev, long *position)
    long FLIGetStepsRemaining(flidev_t dev, long *steps)
    long FLIHomeFocuser(flidev_t dev)
    long FLICreateList(flidomain_t domain)
    long FLIDeleteList()
    long FLIListFirst(flidomain_t *domain, char *filename, size_t fnlen, char *name, size_t namelen)
    long FLIListNext(flidomain_t *domain, char *filename, size_t fnlen, char *name, size_t namelen)
    long FLIReadTemperature(flidev_t dev, flichannel_t channel, double *temperature)
    long FLIGetFocuserExtent(flidev_t dev, long *extent)
    long FLIUsbBulkIO(flidev_t dev, int ep, void *buf, long *len)
    long FLIGetDeviceStatus(flidev_t dev, long *status)
    long FLIGetCameraModeString(flidev_t dev, flimode_t mode_index, char *mode_string, size_t siz)
    long FLIGetCameraMode(flidev_t dev, flimode_t *mode_index)
    long FLISetCameraMode(flidev_t dev, flimode_t mode_index)
    long FLIHomeDevice(flidev_t dev)
    long FLIGrabFrame(flidev_t dev, void* buff, size_t buffsize, size_t* bytesgrabbed)
    long FLISetTDI(flidev_t dev, flitdirate_t tdi_rate, flitdiflags_t flags)
    long FLIGrabVideoFrame(flidev_t dev, void *buff, size_t size)
    long FLIStopVideoMode(flidev_t dev)
    long FLIStartVideoMode(flidev_t dev)
    long FLIGetSerialString(flidev_t dev, char* serial, size_t len)
    long FLIEndExposure(flidev_t dev)
    long FLITriggerExposure(flidev_t dev)
    long FLISetFanSpeed(flidev_t dev, long fan_speed)
    long FLISetVerticalTableEntry(flidev_t dev, long index, long height, long bin, long mode)
    long FLIGetVerticalTableEntry(flidev_t dev, long index, long *height, long *bin, long *mode)
    long FLIGetReadoutDimensions(flidev_t dev, long *width, long *hoffset, long *hbin, long *height, long *voffset, long *vbin)
    long FLIEnableVerticalTable(flidev_t dev, long width, long offset, long flags)
    long FLIReadUserEEPROM(flidev_t dev, long loc, long address, long length, void *rbuf)
    long FLIWriteUserEEPROM(flidev_t dev, long loc, long address, long length, void *wbuf)
