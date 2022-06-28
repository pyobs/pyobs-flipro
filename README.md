FLIPRO module for *pyobs*
=========================

Install *pyobs-fli*
-------------------
Use pip

    pip install pyobs-flipro


Configuration
-------------
The *FliProCamera* class is derived from *BaseCamera* (see *pyobs* documentation) and adds a single new parameter:

    setpoint:
        The initial setpoint in degrees Celsius for the cooling of the camera.

The class works fine with its default parameters, so a basic module configuration would look like this:

    module:
      class: pyobs_flipro.FliProCamera
      name: FLIPRO camera

Dependencies
------------
* **pyobs** for the core funcionality. It is not included in the *requirements.txt*, so needs to be installed 
  separately.
* [Cython](https://cython.org/) for wrapping the SBIG Universal Driver.
* [Astropy](http://www.astropy.org/) for FITS file handling.
* [NumPy](http://www.numpy.org/) for array handling.