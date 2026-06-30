cmake_minimum_required(VERSION 3.21)
project(pyobs_flipro LANGUAGES C)

# --- Ensure we use the build environment Python ---
set(Python3_FIND_VIRTUALENV ONLY)
set(Python3_FIND_STRATEGY LOCATION)
find_package(Python3 REQUIRED COMPONENTS Interpreter Development.Module)

# --- Paths ---
set(PYX_FILE "${CMAKE_CURRENT_SOURCE_DIR}/pyobs_flipro/fliprodriver.pyx")
set(C_FILE "${CMAKE_CURRENT_BINARY_DIR}/fliprodriver.c")

# --- Get NumPy include dir ---
execute_process(
  COMMAND "${Python3_EXECUTABLE}" -c "import numpy; print(numpy.get_include())"
  OUTPUT_VARIABLE NUMPY_INCLUDE_DIR
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

# --- Run Cython ---
add_custom_command(
  OUTPUT ${C_FILE}
  COMMAND "${Python3_EXECUTABLE}" -m cython
          ${PYX_FILE}
          --output-file ${C_FILE}
          -I "${CMAKE_CURRENT_SOURCE_DIR}/pyobs_flipro"
  DEPENDS ${PYX_FILE} "${CMAKE_CURRENT_SOURCE_DIR}/pyobs_flipro/libflipro.pxd"
  COMMENT "Running Cython on fliprodriver.pyx"
)

# --- Build extension module ---
add_library(fliprodriver MODULE ${C_FILE})
target_include_directories(fliprodriver PRIVATE
  ${Python3_INCLUDE_DIRS}
  ${NUMPY_INCLUDE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/
)

# --- Correct Python module naming ---
execute_process(
  COMMAND "${Python3_EXECUTABLE}" -c
          "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))"
  OUTPUT_VARIABLE PY_EXT_SUFFIX
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set_target_properties(fliprodriver PROPERTIES
  PREFIX ""
  OUTPUT_NAME "fliprodriver"
  SUFFIX "${PY_EXT_SUFFIX}"
  POSITION_INDEPENDENT_CODE ON
  INSTALL_RPATH "$ORIGIN"
  BUILD_WITH_INSTALL_RPATH ON
)
message(STATUS "ext: ${PY_EXT_SUFFIX}")

# --- Bundled FLIPRO libraries (pre-compiled, shipped in lib/) ---
set(FLIPRO_LIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/liblibflipro.so")
set(FLIALGO_LIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/liblibflialgo.so")
target_link_libraries(fliprodriver PRIVATE ${FLIPRO_LIB} ${FLIALGO_LIB})

# --- System libraries ---
find_library(CFITSIO_LIB cfitsio REQUIRED)
find_library(USB_LIB usb-1.0 REQUIRED)
target_link_libraries(fliprodriver PRIVATE ${CFITSIO_LIB} ${USB_LIB})

# --- Install extension and bundled .so files into package ---
install(TARGETS fliprodriver
  LIBRARY DESTINATION ${SKBUILD_PROJECT_NAME}
)
install(FILES ${FLIPRO_LIB} ${FLIALGO_LIB}
  DESTINATION ${SKBUILD_PROJECT_NAME}
)
