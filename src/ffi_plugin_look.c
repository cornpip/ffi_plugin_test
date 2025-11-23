#include "ffi_plugin_look.h"

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
