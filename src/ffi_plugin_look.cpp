#include "ffi_plugin_look.h"

#include <opencv2/imgproc.hpp>

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b) { return a + b; }

// A longer-lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b) {
  // Simulate work.
#if _WIN32
  Sleep(5000);
#else
  usleep(5000 * 1000);
#endif
  return a + b;
}

FFI_PLUGIN_EXPORT void multiply_matrices(const double* a, const double* b,
                                         double* result, int dimension) {
  for (int row = 0; row < dimension; row++) {
    for (int col = 0; col < dimension; col++) {
      double value = 0.0;
      for (int k = 0; k < dimension; k++) {
        value += a[row * dimension + k] * b[k * dimension + col];
      }
      result[row * dimension + col] = value;
    }
  }
}

FFI_PLUGIN_EXPORT void apply_grayscale_filter(uint8_t* rgba_pixels, int width,
                                              int height) {
  if (rgba_pixels == nullptr || width <= 0 || height <= 0) {
    return;
  }

  cv::Mat rgba(height, width, CV_8UC4, rgba_pixels);
  cv::Mat gray;
  cv::cvtColor(rgba, gray, cv::COLOR_RGBA2GRAY);

  cv::Mat rgba_output(height, width, CV_8UC4, rgba_pixels);
  cv::cvtColor(gray, rgba_output, cv::COLOR_GRAY2RGBA);
}

FFI_PLUGIN_EXPORT void apply_heavy_blur(uint8_t* rgba_pixels, int width,
                                        int height, int iterations) {
  if (rgba_pixels == nullptr || width <= 0 || height <= 0 ||
      iterations <= 0) {
    return;
  }

  cv::Mat rgba(height, width, CV_8UC4, rgba_pixels);
  cv::Mat blurred;
  const cv::Size kernel_size(31, 31);
  const double sigma = 11.0;

  for (int i = 0; i < iterations; ++i) {
    cv::GaussianBlur(rgba, blurred, kernel_size, sigma);
    blurred.copyTo(rgba);
  }
}
