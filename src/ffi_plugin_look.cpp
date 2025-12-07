#include "ffi_plugin_look.h"

#include <algorithm>
#include <cmath>

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

namespace {

inline uint8_t ClampToByte(double value) {
  if (value < 0.0) {
    return 0;
  }
  if (value > 255.0) {
    return 255;
  }
  return static_cast<uint8_t>(value);
}

inline int NormalizeRotation(int rotation_degrees) {
  int normalized = rotation_degrees % 360;
  if (normalized < 0) {
    normalized += 360;
  }
  return normalized;
}

}  // namespace

FFI_PLUGIN_EXPORT void preprocess_camera_frame(
    const uint8_t* y_plane, int y_row_stride, const uint8_t* u_plane,
    int u_row_stride, int u_pixel_stride, const uint8_t* v_plane,
    int v_row_stride, int v_pixel_stride, int width, int height,
    int rotation_degrees, int flip_horizontal, int target_width,
    int target_height, uint8_t* out_rgb_buffer, double* out_scale,
    int32_t* out_pad_x, int32_t* out_pad_y, int32_t* out_processed_width,
    int32_t* out_processed_height) {
  if (y_plane == nullptr || u_plane == nullptr || v_plane == nullptr ||
      out_rgb_buffer == nullptr || width <= 0 || height <= 0 ||
      target_width <= 0 || target_height <= 0) {
    return;
  }

  const int adjusted_u_pixel_stride = std::max(u_pixel_stride, 1);
  const int adjusted_v_pixel_stride = std::max(v_pixel_stride, 1);

  cv::Mat bgr(height, width, CV_8UC3);
  for (int y = 0; y < height; ++y) {
    const uint8_t* y_row = y_plane + y * y_row_stride;
    const uint8_t* u_row = u_plane + (y / 2) * u_row_stride;
    const uint8_t* v_row = v_plane + (y / 2) * v_row_stride;
    cv::Vec3b* bgr_row = bgr.ptr<cv::Vec3b>(y);
    for (int x = 0; x < width; ++x) {
      const int uv_column = x / 2;
      const uint8_t y_value = y_row[x];
      const uint8_t u_value = u_row[uv_column * adjusted_u_pixel_stride];
      const uint8_t v_value = v_row[uv_column * adjusted_v_pixel_stride];

      const double y_d = static_cast<double>(y_value);
      const double u_d = static_cast<double>(u_value) - 128.0;
      const double v_d = static_cast<double>(v_value) - 128.0;

      const double r = y_d + 1.402 * v_d;
      const double g = y_d - 0.344136 * u_d - 0.714136 * v_d;
      const double b = y_d + 1.772 * u_d;

      cv::Vec3b& pixel = bgr_row[x];
      pixel[2] = ClampToByte(r);
      pixel[1] = ClampToByte(g);
      pixel[0] = ClampToByte(b);
    }
  }

  cv::Mat oriented;
  const int normalized_rotation = NormalizeRotation(rotation_degrees);
  if (normalized_rotation == 90) {
    cv::rotate(bgr, oriented, cv::ROTATE_90_CLOCKWISE);
  } else if (normalized_rotation == 180) {
    cv::rotate(bgr, oriented, cv::ROTATE_180);
  } else if (normalized_rotation == 270) {
    cv::rotate(bgr, oriented, cv::ROTATE_90_COUNTERCLOCKWISE);
  } else {
    oriented = bgr;
  }

  if (flip_horizontal) {
    cv::Mat flipped;
    cv::flip(oriented, flipped, 1);
    oriented = flipped;
  }

  if (out_processed_width != nullptr) {
    *out_processed_width = oriented.cols;
  }
  if (out_processed_height != nullptr) {
    *out_processed_height = oriented.rows;
  }

  const double scale =
      std::min(static_cast<double>(target_width) / oriented.cols,
               static_cast<double>(target_height) / oriented.rows);
  const int resized_width =
      std::max(1, static_cast<int>(std::round(oriented.cols * scale)));
  const int resized_height =
      std::max(1, static_cast<int>(std::round(oriented.rows * scale)));
  const int pad_x = std::max(0, (target_width - resized_width) / 2);
  const int pad_y = std::max(0, (target_height - resized_height) / 2);

  if (out_scale != nullptr) {
    *out_scale = scale;
  }
  if (out_pad_x != nullptr) {
    *out_pad_x = pad_x;
  }
  if (out_pad_y != nullptr) {
    *out_pad_y = pad_y;
  }

  cv::Mat resized;
  cv::resize(oriented, resized, cv::Size(resized_width, resized_height), 0, 0,
             cv::INTER_LINEAR);

  cv::Mat letterboxed(
      target_height, target_width, CV_8UC3,
      cv::Scalar(0, 0, 0));  // black padding to mimic letterbox in Dart
  cv::Rect roi(pad_x, pad_y, resized_width, resized_height);
  resized.copyTo(letterboxed(roi));

  uint8_t* dst = out_rgb_buffer;
  for (int y = 0; y < target_height; ++y) {
    const cv::Vec3b* row = letterboxed.ptr<cv::Vec3b>(y);
    for (int x = 0; x < target_width; ++x) {
      const cv::Vec3b& pixel = row[x];
      *dst++ = pixel[2];  // R
      *dst++ = pixel[1];  // G
      *dst++ = pixel[0];  // B
    }
  }
}
