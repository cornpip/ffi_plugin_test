#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b);

// A longer lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b);

// Multiplies two square matrices of size `dimension` x `dimension`.
//
// Matrices are passed in row-major order and the result buffer must have
// space for `dimension * dimension` doubles.
FFI_PLUGIN_EXPORT void multiply_matrices(const double* a, const double* b,
                                         double* result, int dimension);

// Applies a grayscale filter to an in-memory RGBA image.
//
// `rgba_pixels` must contain `width * height * 4` bytes since the operation
// is performed in-place.
FFI_PLUGIN_EXPORT void apply_grayscale_filter(uint8_t* rgba_pixels, int width,
                                              int height);

// Applies repeated heavy Gaussian blur iterations to stress native processing.
FFI_PLUGIN_EXPORT void apply_heavy_blur(uint8_t* rgba_pixels, int width,
                                        int height, int iterations);

// Converts a planar YUV420 frame into an RGB buffer with rotation, mirroring,
// and letterboxing to the requested output dimensions.
FFI_PLUGIN_EXPORT void preprocess_camera_frame(
    const uint8_t* y_plane, int y_row_stride, const uint8_t* u_plane,
    int u_row_stride, int u_pixel_stride, const uint8_t* v_plane,
    int v_row_stride, int v_pixel_stride, int width, int height,
    int rotation_degrees, int flip_horizontal, int target_width,
    int target_height, uint8_t* out_rgb_buffer, double* out_scale,
    int32_t* out_pad_x, int32_t* out_pad_y, int32_t* out_processed_width,
    int32_t* out_processed_height);

#ifdef __cplusplus
}  // extern "C"
#endif
