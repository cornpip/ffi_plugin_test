// Relative import to reuse the cross-platform C++ implementation.
// See the comment in ../ffi_plugin_look.podspec for more information.
#ifdef NO
#undef NO  // Avoid collision with OpenCV enums in ObjC++ builds
#endif
#ifdef YES
#undef YES
#endif
#include "../../src/ffi_plugin_look.cpp"
