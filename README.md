FLI module for *pyobs*
======================

FLI kernel module
-----------------
The FLI kernel module needs to be installed in the system.


Install *pyobs-fli*
-------------------
Clone the repository:

    git clone https://github.com/pyobs/pyobs-fli.git


Install dependencies:

    cd pyobs-fli
    pip3 install -r requirements
        
And install it:

    python3 setup.py install


Configuration
-------------
The *FliCamera* class is derived from *BaseCamera* (see *pyobs* documentation) and adds a single new parameter:

    setpoint:
        The initial setpoint in degrees Celsius for the cooling of the camera.

The class works fine with its default parameters, so a basic module configuration would look like this:

    module:
      class: pyobs_fli.FliCamera
      name: FLI camera

Dependencies
------------
* **pyobs** for the core funcionality. It is not included in the *requirements.txt*, so needs to be installed 
  separately.
* [Cython](https://cython.org/) for wrapping the SBIG Universal Driver.
* [Astropy](http://www.astropy.org/) for FITS file handling.
* [NumPy](http://www.numpy.org/) for array handling.