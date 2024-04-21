import os
from setuptools import Extension, Distribution
import numpy
from Cython.Build import cythonize
from Cython.Distutils.build_ext import new_build_ext as cython_build_ext


def build(**kwargs) -> None:
    # if running in RTD, skip compilation
    if os.environ.get("READTHEDOCS") == "True":
        return

    # compile FLI library
    os.system("cd lib && make && cd ..")

    extensions = [
        Extension(
            "pyobs_flipro.fliprodriver",
            ["pyobs_flipro/fliprodriver.pyx"],
            library_dirs=["lib/"],
            libraries=["libflipro", "libflialgo", "cfitsio", "usb-1.0"],
            include_dirs=[numpy.get_include()],
            extra_compile_args=["-fPIC"],
            define_macros=[("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")],
        )
    ]
    ext_modules = cythonize(extensions)

    distribution = Distribution(
        {
            "name": "extended",
            "ext_modules": ext_modules,
            "cmdclass": {
                "build_ext": cython_build_ext,
            },
        }
    )

    distribution.run_command("build_ext")
    build_ext_cmd = distribution.get_command_obj("build_ext")
    build_ext_cmd.copy_extensions_to_source()


if __name__ == "__main__":
    build()
