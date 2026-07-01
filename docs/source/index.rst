pyobs-flipro
############

This is a `pyobs <https://www.pyobs.org>`_ (`documentation <https://docs.pyobs.org>`_) module for FLI PRO cameras.


Example configuration
*********************

This is an example configuration::

    class: pyobs_flipro.FliProCamera

    # filename pattern
    filenames: /cache/pyobs-{DAY-OBS|date:}-{FRAMENUM|string:04d}-{IMAGETYP|type}00.fits

    # cooling
    setpoint: -20.0

    # location
    timezone: utc
    location:
      longitude: 9.944333
      latitude: 51.560583
      elevation: 201.

    # communication
    comm:
      jid: test@example.com
      password: ***

    # virtual file system
    vfs:
      class: pyobs.vfs.VirtualFileSystem
      roots:
        cache:
          class: pyobs.vfs.HttpFile
          upload: http://localhost:37075/


Available classes
*****************

There is one single class for FLI PRO cameras.

FliProCamera
============
.. autoclass:: pyobs_flipro.FliProCamera
   :members:
   :show-inheritance:
