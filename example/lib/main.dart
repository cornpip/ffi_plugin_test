import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:ffi_plugin_look/ffi_plugin_look.dart' as ffi_plugin_look;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const int _demoWidth = 160;
  static const int _demoHeight = 120;
  static const int _heavyDemoWidth = 512;
  static const int _heavyDemoHeight = 512;

  late int sumResult;
  late Future<int> sumAsyncResult;
  late List<double> matrixResult;
  Uint8List? _originalPixels;
  ui.Image? _originalImage;
  ui.Image? _grayscaleImage;
  bool _isGrayscaleProcessing = false;

  Uint8List? _heavyPixels;
  ui.Image? _heavyOriginalImage;
  ui.Image? _heavyBlurredImage;
  bool _isHeavyBlurProcessing = false;
  String? _heavyBlurError;

  @override
  void initState() {
    super.initState();
    sumResult = ffi_plugin_look.sum(1, 2);
    sumAsyncResult = ffi_plugin_look.sumAsync(3, 4);
    matrixResult = ffi_plugin_look.multiplyMatrices(
      const [1, 2, 3, 4],
      const [5, 6, 7, 8],
      2,
    );
    _prepareDemoImage();
    _prepareHeavyDemoImage();
  }

  Future<void> _prepareDemoImage() async {
    final Uint8List demoPixels = _createDemoPixels(_demoWidth, _demoHeight);
    final ui.Image original =
        await _decodeRgbaToImage(demoPixels, _demoWidth, _demoHeight);
    if (!mounted) {
      return;
    }
    setState(() {
      _originalPixels = demoPixels;
      _originalImage = original;
      _grayscaleImage = null;
    });
  }

  Future<void> _prepareHeavyDemoImage() async {
    final Uint8List pixels =
        _createDemoPixels(_heavyDemoWidth, _heavyDemoHeight);
    final ui.Image original = await _decodeRgbaToImage(
      pixels,
      _heavyDemoWidth,
      _heavyDemoHeight,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _heavyPixels = pixels;
      _heavyOriginalImage = original;
      _heavyBlurredImage = null;
    });
  }

  Future<void> _runGrayscaleFilter() async {
    final Uint8List? pixels = _originalPixels;
    if (pixels == null || _isGrayscaleProcessing) {
      return;
    }
    setState(() {
      _isGrayscaleProcessing = true;
      _grayscaleImage = null;
    });

    final Uint8List filteredPixels = ffi_plugin_look.applyGrayscaleFilter(
      pixels,
      _demoWidth,
      _demoHeight,
    );
    final ui.Image filtered =
        await _decodeRgbaToImage(filteredPixels, _demoWidth, _demoHeight);
    if (!mounted) {
      return;
    }
    setState(() {
      _grayscaleImage = filtered;
      _isGrayscaleProcessing = false;
    });
  }

  Uint8List _createDemoPixels(int width, int height) {
    final Uint8List data = Uint8List(width * height * 4);
    final double widthRange = (width - 1).clamp(1, width).toDouble();
    final double heightRange = (height - 1).clamp(1, height).toDouble();
    final double diagonalRange = (width + height - 2).clamp(1, width + height).toDouble();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width + x) * 4;
        data[offset] = ((x / widthRange) * 255).clamp(0, 255).toInt();
        data[offset + 1] = ((y / heightRange) * 255).clamp(0, 255).toInt();
        final double blue = ((x + y) / diagonalRange) * 255;
        data[offset + 2] = blue.clamp(0, 255).toInt();
        data[offset + 3] = 255;
      }
    }
    return data;
  }

  Future<ui.Image> _decodeRgbaToImage(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
  Future<void> _runHeavyBlurDemo() async {
    final Uint8List? pixels = _heavyPixels;
    if (pixels == null || _isHeavyBlurProcessing) {
      return;
    }
    setState(() {
      _isHeavyBlurProcessing = true;
      _heavyBlurredImage = null;
      _heavyBlurError = null;
    });

    try {
      final Uint8List filtered = await ffi_plugin_look.applyHeavyBlurAsync(
        pixels,
        _heavyDemoWidth,
        _heavyDemoHeight,
        iterations: 1000,
      );
      final ui.Image image = await _decodeRgbaToImage(
        filtered,
        _heavyDemoWidth,
        _heavyDemoHeight,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _heavyBlurredImage = image;
        _isHeavyBlurProcessing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isHeavyBlurProcessing = false;
        _heavyBlurError = error.toString();
      });
    }
  }

  Future<void> _runHeavyBlurBlockingDemo() async {
    final Uint8List? pixels = _heavyPixels;
    if (pixels == null || _isHeavyBlurProcessing) {
      return;
    }
    setState(() {
      _isHeavyBlurProcessing = true;
      _heavyBlurredImage = null;
      _heavyBlurError = null;
    });

    try {
      final Uint8List filtered = ffi_plugin_look.applyHeavyBlurBlocking(
        pixels,
        _heavyDemoWidth,
        _heavyDemoHeight,
        iterations: 1000,
      );
      final ui.Image image = await _decodeRgbaToImage(
        filtered,
        _heavyDemoWidth,
        _heavyDemoHeight,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _heavyBlurredImage = image;
        _isHeavyBlurProcessing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isHeavyBlurProcessing = false;
        _heavyBlurError = error.toString();
      });
    }
  }

  Widget _buildImagePreview({
    required String label,
    required ui.Image? image,
    required double aspectRatio,
    required Widget placeholder,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: image != null
                    ? RawImage(
                        image: image,
                        filterQuality: FilterQuality.none,
                      )
                    : Center(child: placeholder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 20);
    const textStyle2 = TextStyle(fontSize: 14);
    const spacerSmall = SizedBox(height: 10);
    const spacerLarge = SizedBox(height: 30);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                spacerSmall,
                Text(
                  'sum(1, 2) = $sumResult',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Text(
                  'Matrix result = ${matrixResult.map((v) => v.toStringAsFixed(0)).toList()}',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                FutureBuilder<int>(
                  future: sumAsyncResult,
                  builder: (BuildContext context, AsyncSnapshot<int> value) {
                    final displayValue =
                        (value.hasData) ? value.data : 'loading';
                    return Text(
                      'await sumAsync(3, 4) = $displayValue',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                spacerLarge,
                const Text(
                  'OpenCV Grayscale Demo',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                const Text(
                  'Send a sample RGBA buffer to native OpenCV and convert it to grayscale.',
                  style: textStyle2,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Row(
                  children: [
                    _buildImagePreview(
                      label: 'Original',
                      image: _originalImage,
                      aspectRatio: _demoWidth / _demoHeight,
                      placeholder: const Text('Preparing...'),
                    ),
                    const SizedBox(width: 16),
                    _buildImagePreview(
                      label: 'Grayscale',
                      image: _grayscaleImage,
                      aspectRatio: _demoWidth / _demoHeight,
                      placeholder: Text(
                        _isGrayscaleProcessing
                            ? 'Processing...'
                            : 'Tap the button to run',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed:
                      (_originalPixels == null || _isGrayscaleProcessing)
                          ? null
                          : _runGrayscaleFilter,
                  child: Text(
                    _isGrayscaleProcessing ? 'Processing...' : 'Run OpenCV filter',
                  ),
                ),
                spacerLarge,
                const Text(
                  'Heavy Gaussian Blur (Isolate + OpenCV)',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                const Text(
                  'Run repeated blur on a helper isolate via _helperIsolateSendPort.',
                  style: textStyle2,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Row(
                  children: [
                    _buildImagePreview(
                      label: 'Source 512x512',
                      image: _heavyOriginalImage,
                      aspectRatio: _heavyDemoWidth / _heavyDemoHeight,
                      placeholder: const Text('Preparing...'),
                    ),
                    const SizedBox(width: 16),
                    _buildImagePreview(
                      label: 'Blur result',
                      image: _heavyBlurredImage,
                      aspectRatio: _heavyDemoWidth / _heavyDemoHeight,
                      placeholder: _isHeavyBlurProcessing
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 3),
                                ),
                                SizedBox(height: 8),
                                Text('Loading...'),
                              ],
                            )
                          : const Text('Tap the button to run'),
                    ),
                  ],
                ),
                if (_heavyBlurError != null) ...[
                  spacerSmall,
                  Text(
                    'Error: $_heavyBlurError',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                spacerSmall,
                ElevatedButton(
                  onPressed:
                      (_heavyPixels == null || _isHeavyBlurProcessing)
                          ? null
                          : _runHeavyBlurDemo,
                  child: Text(
                    _isHeavyBlurProcessing ? 'Running...' : 'Run heavy blur in isolate',
                  ),
                ),
                spacerSmall,
                const Text(
                  'Running the same work on the main isolate will freeze the loader above.',
                  style: textStyle2,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed:
                      (_heavyPixels == null || _isHeavyBlurProcessing)
                          ? null
                          : _runHeavyBlurBlockingDemo,
                  child: Text(
                    _isHeavyBlurProcessing
                        ? 'Running...'
                        : 'Run on main isolate (UI freeze test)',
                  ),
                ),
                spacerLarge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
