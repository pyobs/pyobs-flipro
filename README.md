FLIPRO module for *pyobs*
=========================

This is a [pyobs](https://www.pyobs.org) module for FLI PRO cameras.


System dependencies
--------------------
On Debian/Ubuntu:

    sudo apt-get install libcfitsio-dev libusb-1.0-0-dev


Install *pyobs-flipro*
------------------------
Clone the repository:

    git clone https://github.com/pyobs/pyobs-flipro.git
    cd pyobs-flipro

Install it with [uv](https://docs.astral.sh/uv/):

    uv sync

Alternatively, with plain `venv`/`pip`:

    python3 -m venv .venv
    source .venv/bin/activate
    pip install .


Configuration
-------------
The *FliProCamera* class is derived from *BaseCamera* (see *pyobs* documentation) and adds a single new parameter:

    setpoint:
        The cooling temperature setpoint in degrees Celsius.

A basic module configuration would look like this:

    class: pyobs_flipro.FliProCamera
    name: FLIPRO camera
    setpoint: -20.0


GUI
---
For testing a camera without a full *pyobs* setup, install the optional `gui` extra:

    uv sync --extra gui

and run:

    uv run flipro-gui


Dependencies
------------
* [pyobs-core](https://github.com/pyobs/pyobs-core) for the core functionality.
* [Astropy](http://www.astropy.org/) for FITS file handling.
* [NumPy](http://www.numpy.org/) for array handling.
