# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(ffi_plugin_look_library VERSION 0.0.1 LANGUAGES C CXX)

add_library(ffi_plugin_look SHARED
  "ffi_plugin_look.cpp"
)

set(OPENCV_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/opencv/sdk/native")
set(OPENCV_INCLUDE_DIR "${OPENCV_ROOT}/jni/include")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set_target_properties(ffi_plugin_look PROPERTIES
  PUBLIC_HEADER ffi_plugin_look.h
  OUTPUT_NAME "ffi_plugin_look"
)

target_compile_definitions(ffi_plugin_look PUBLIC DART_SHARED_LIB)
target_include_directories(ffi_plugin_look PRIVATE "${OPENCV_INCLUDE_DIR}")

if (ANDROID)
  # Provide the prebuilt OpenCV shared library shipped with the Android SDK.
  add_library(opencv_java4 SHARED IMPORTED)
  set_target_properties(opencv_java4 PROPERTIES
    IMPORTED_LOCATION "${OPENCV_ROOT}/libs/${ANDROID_ABI}/libopencv_java4.so"
  )
  target_link_libraries(ffi_plugin_look PRIVATE opencv_java4)
  # Ensure libc++_shared is packaged since OpenCV depends on it.
  find_library(CPP_SHARED_LIB c++_shared)
  if (CPP_SHARED_LIB)
    target_link_libraries(ffi_plugin_look PRIVATE ${CPP_SHARED_LIB})
    add_custom_command(TARGET ffi_plugin_look POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CPP_SHARED_LIB}"
        "$<TARGET_FILE_DIR:ffi_plugin_look>/libc++_shared.so"
    )
  endif()
  # Support Android 15 16k page size
  target_link_options(ffi_plugin_look PRIVATE "-Wl,-z,max-page-size=16384")
endif()
