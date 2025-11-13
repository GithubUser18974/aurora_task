import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/random_image.dart';
import '../services/random_image_service.dart';

class RandomImageController extends ChangeNotifier {
  RandomImageController(
    this._service, {
    required Dio dio,
    Color? initialBackgroundColor,
  })  : _dio = dio,
        _backgroundColor = initialBackgroundColor ?? const Color(0xFF101010);

  final RandomImageService _service;
  final Dio _dio;

  RandomImage? _currentImage;
  bool _isLoading = false;
  String? _errorMessage;
  Color _backgroundColor;

  RandomImage? get currentImage => _currentImage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Color get backgroundColor => _backgroundColor;

  Future<void> loadRandomImage() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final image = await _service.fetchRandomImage();
      final paletteColor = await _extractDominantColor(image.url);

      _currentImage = image;
      if (paletteColor != null) {
        _backgroundColor = paletteColor;
      }
    } on Object catch (error) {
      _errorMessage = _mapError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Color?> _extractDominantColor(String imageUrl) async {
    try {
      final thumbUrl = _thumbnailUrl(imageUrl);
      final response = await _dio.get<List<int>>(
        thumbUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final colorValue =
          await compute(_computeAverageArgbColor, Uint8List.fromList(bytes));
      return Color(colorValue);
    } on Object {
      return null;
    }
  }

  String _thumbnailUrl(String imageUrl) {
    final separator = imageUrl.contains('?') ? '&' : '?';
    // Very small, fast-to-decode thumbnail for palette: 64px wide, low quality
    return '$imageUrl${separator}w=64&q=20&fit=crop';
  }

  String _mapError(Object error) {
    if (error is FormatException) {
      return 'The image data could not be parsed.';
    }

    return 'Something went wrong while loading the image. Please try again.';
  }
}

// Runs in a background isolate via `compute`.
int _computeAverageArgbColor(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    // Fallback to opaque dark
    return 0xFF101010;
  }
  final width = decoded.width;
  final height = decoded.height;
  final total = width * height;
  int step = total ~/ 4096;
  if (step < 1) step = 1;
  if (step > 16) step = 16;

  int rSum = 0, gSum = 0, bSum = 0, count = 0;
  for (int y = 0; y < height; y += step) {
    for (int x = 0; x < width; x += step) {
      final pixel = decoded.getPixel(x, y);
      rSum += pixel.r.toInt();
      gSum += pixel.g.toInt();
      bSum += pixel.b.toInt();
      count++;
    }
  }
  if (count == 0) return 0xFF101010;
  final r = (rSum ~/ count) & 0xFF;
  final g = (gSum ~/ count) & 0xFF;
  final b = (bSum ~/ count) & 0xFF;
  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

