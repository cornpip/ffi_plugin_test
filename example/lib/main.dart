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

  late int sumResult;
  late Future<int> sumAsyncResult;
  late List<double> matrixResult;
  Uint8List? _originalPixels;
  ui.Image? _originalImage;
  ui.Image? _grayscaleImage;
  bool _isProcessing = false;

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
  }

  Future<void> _prepareDemoImage() async {
    final Uint8List demoPixels = _createDemoPixels(_demoWidth, _demoHeight);
    final ui.Image original = await _decodeRgbaToImage(demoPixels);
    if (!mounted) {
      return;
    }
    setState(() {
      _originalPixels = demoPixels;
      _originalImage = original;
      _grayscaleImage = null;
    });
  }

  Future<void> _runOpenCvFilter() async {
    final Uint8List? pixels = _originalPixels;
    if (pixels == null || _isProcessing) {
      return;
    }
    setState(() {
      _isProcessing = true;
      _grayscaleImage = null;
    });

    final Uint8List filteredPixels = ffi_plugin_look.applyGrayscaleFilter(
      pixels,
      _demoWidth,
      _demoHeight,
    );
    final ui.Image filtered = await _decodeRgbaToImage(filteredPixels);
    if (!mounted) {
      return;
    }
    setState(() {
      _grayscaleImage = filtered;
      _isProcessing = false;
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

  Future<ui.Image> _decodeRgbaToImage(Uint8List pixels) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _demoWidth,
      _demoHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Widget _buildDemoPreview(String label, ui.Image? image, String placeholder) {
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
            aspectRatio: _demoWidth / _demoHeight,
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
                    : Center(
                        child: Text(
                          placeholder,
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    const spacerLarge = SizedBox(height: 30);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
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
                  'OpenCV 회색조 예제',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                const Text(
                  '샘플 RGBA 버퍼를 네이티브 OpenCV로 보내 회색조로 변환합니다.',
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Row(
                  children: [
                    _buildDemoPreview(
                      '원본',
                      _originalImage,
                      '생성 중...',
                    ),
                    const SizedBox(width: 16),
                    _buildDemoPreview(
                      '회색조',
                      _grayscaleImage,
                      _isProcessing ? '처리 중...' : '버튼을 눌러주세요',
                    ),
                  ],
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed:
                      (_originalPixels == null || _isProcessing)
                          ? null
                          : _runOpenCvFilter,
                  child: Text(_isProcessing ? '처리 중...' : 'OpenCV 필터 실행'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
