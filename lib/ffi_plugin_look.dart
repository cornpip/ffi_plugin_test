
import 'dart:async';
import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import 'ffi_plugin_look_bindings_generated.dart';

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) => _bindings.sum(a, b);

/// Multiplies two [dimension] x [dimension] matrices given in row-major order.
///
/// The returned list contains the result matrix flattened in row-major order.
List<double> multiplyMatrices(
  List<double> matrixA,
  List<double> matrixB,
  int dimension,
) {
  final int elementCount = dimension * dimension;
  if (matrixA.length != elementCount || matrixB.length != elementCount) {
    throw ArgumentError(
      'Each matrix must contain $elementCount values '
      '(${dimension}x$dimension in row-major order).',
    );
  }

  final ffi.Pointer<ffi.Double> aPtr = ffi.calloc<ffi.Double>(elementCount);
  final ffi.Pointer<ffi.Double> bPtr = ffi.calloc<ffi.Double>(elementCount);
  final ffi.Pointer<ffi.Double> resultPtr = ffi.calloc<ffi.Double>(elementCount);

  try {
    aPtr.asTypedList(elementCount).setAll(0, matrixA);
    bPtr.asTypedList(elementCount).setAll(0, matrixB);

    _bindings.multiply_matrices(aPtr, bPtr, resultPtr, dimension);

    return List<double>.from(resultPtr.asTypedList(elementCount));
  } finally {
    ffi.calloc.free(aPtr);
    ffi.calloc.free(bPtr);
    ffi.calloc.free(resultPtr);
  }
}

/// Applies an in-place OpenCV grayscale filter to RGBA pixels and returns a new list.
Uint8List applyGrayscaleFilter(
  Uint8List rgbaPixels,
  int width,
  int height,
) {
  final int expectedBytes = width * height * 4;
  if (rgbaPixels.lengthInBytes != expectedBytes) {
    throw ArgumentError(
      'rgbaPixels must contain exactly $expectedBytes bytes for the provided '
      'dimensions ($width x $height).',
    );
  }

  final ffi.Pointer<ffi.Uint8> pixelPtr =
      ffi.calloc<ffi.Uint8>(rgbaPixels.lengthInBytes);

  try {
    pixelPtr.asTypedList(rgbaPixels.lengthInBytes).setAll(0, rgbaPixels);
    _bindings.apply_grayscale_filter(pixelPtr, width, height);
    return Uint8List.fromList(pixelPtr.asTypedList(rgbaPixels.lengthInBytes));
  } finally {
    ffi.calloc.free(pixelPtr);
  }
}

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'ffi_plugin_look';

/// The dynamic library in which the symbols for [FfiPluginLookBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final FfiPluginLookBindings _bindings = FfiPluginLookBindings(_dylib);


/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
