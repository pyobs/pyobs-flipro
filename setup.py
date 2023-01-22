from setuptools import Extension, setup
from Cython.Build import cythonize
import numpy

extensions = [
    Extension(
        "pyobs_flipro.fliprodriver",
        ["pyobs_flipro/fliprodriver.pyx"],
        include_dirs=[numpy.get_include()],
        libraries=["libflipro", "libflialgo", "cfitsio", "usb-1.0"],
        library_dirs=["lib/"],
        extra_compile_args=["-fPIC"],
    )
]
setup(
    name="pyobs-flipro",
    ext_modules=cythonize(extensions),
)
