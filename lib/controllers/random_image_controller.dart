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
        _backgroundColor = initialBackgroundColor ?? const Color(0xFF101010),
        _backgroundGradient = [
          (initialBackgroundColor ?? const Color(0xFF101010)),
          (initialBackgroundColor ?? const Color(0xFF101010)),
          (initialBackgroundColor ?? const Color(0xFF101010)),
        ];

  final RandomImageService _service;
  final Dio _dio;

  RandomImage? _currentImage;
  bool _isLoading = false;
  String? _errorMessage;
  Color _backgroundColor;
  List<Color> _backgroundGradient;

  RandomImage? get currentImage => _currentImage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Color get backgroundColor => _backgroundColor;
  List<Color> get backgroundGradient => _backgroundGradient;

  Future<void> loadRandomImage() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final image = await _service.fetchRandomImage();
      final palette = await _extractPalette(image.url);

      _currentImage = image;
      if (palette.isNotEmpty) {
        _backgroundColor = palette.first;
        // Ensure at least 3 colors for the background
        if (palette.length >= 3) {
          _backgroundGradient = palette.take(3).toList();
        } else if (palette.length == 2) {
          _backgroundGradient = [palette[0], palette[1], palette[0]];
        } else {
          _backgroundGradient = [palette[0], palette[0], palette[0]];
        }
      }
    } on Object catch (error) {
      _errorMessage = _mapError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Color>> _extractPalette(String imageUrl) async {
    try {
      final thumbUrl = _thumbnailUrl(imageUrl);
      final response = await _dio.get<List<int>>(
        thumbUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return const [];
      final argbList =
          await compute(_computePaletteArgb, Uint8List.fromList(bytes));
      if (argbList.isEmpty) return const [];
      return argbList.map((c) => Color(c)).toList(growable: false);
    } on Object {
      return const [];
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
// Returns up to 3 ARGB colors: [dominantAvg, vibrant, contrast]
List<int> _computePaletteArgb(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return [0xFF101010, 0xFF101010, 0xFF101010];
  }
  final width = decoded.width;
  final height = decoded.height;
  final total = width * height;
  int step = total ~/ 4096;
  if (step < 1) step = 1;
  if (step > 16) step = 16;

  int rSum = 0, gSum = 0, bSum = 0, count = 0;
  // Track vibrant (highest saturation with moderate brightness)
  double bestSatScore = -1.0;
  int vibrantR = 16, vibrantG = 16, vibrantB = 16;
  // For contrast color, pick hue farthest from vibrant among saturated candidates
  double bestHueDistance = -1.0;
  int contrastR = 16, contrastG = 16, contrastB = 16;
  double vibrantHue = -1.0;

  for (int y = 0; y < height; y += step) {
    for (int x = 0; x < width; x += step) {
      final pixel = decoded.getPixel(x, y);
      final pr = pixel.r.toInt();
      final pg = pixel.g.toInt();
      final pb = pixel.b.toInt();

      rSum += pr;
      gSum += pg;
      bSum += pb;
      count++;

      final maxC = pr > pg ? (pr > pb ? pr : pb) : (pg > pb ? pg : pb);
      final minC = pr < pg ? (pr < pb ? pr : pb) : (pg < pb ? pg : pb);
      final delta = (maxC - minC).toDouble();
      final brightness = maxC / 255.0; // V in HSV
      final saturation = maxC == 0 ? 0.0 : (delta / maxC);

      // Compute hue in degrees [0,360)
      double hue;
      if (delta == 0) {
        hue = 0.0;
      } else if (maxC == pr) {
        hue = 60.0 * (((pg - pb) / delta) % 6);
      } else if (maxC == pg) {
        hue = 60.0 * (((pb - pr) / delta) + 2);
      } else {
        hue = 60.0 * (((pr - pg) / delta) + 4);
      }
      if (hue < 0) hue += 360.0;

      // Favor high saturation and mid brightness (avoid too dark/too light)
      final satScore = saturation * (1.0 - (brightness - 0.6).abs());
      if (satScore > bestSatScore) {
        bestSatScore = satScore;
        vibrantR = pr;
        vibrantG = pg;
        vibrantB = pb;
        vibrantHue = hue;
      }

      // After we have at least one vibrant hue, track contrast farthest hue
      if (vibrantHue >= 0.0 && saturation > 0.25) {
        final hueDistance = _circularHueDistance(hue, vibrantHue);
        if (hueDistance > bestHueDistance) {
          bestHueDistance = hueDistance;
          contrastR = pr;
          contrastG = pg;
          contrastB = pb;
        }
      }
    }
  }

  if (count == 0) {
    return [0xFF101010, 0xFF101010, 0xFF101010];
  }
  final r = (rSum ~/ count) & 0xFF;
  final g = (gSum ~/ count) & 0xFF;
  final b = (bSum ~/ count) & 0xFF;

  final dominant = (0xFF << 24) | (r << 16) | (g << 8) | b;
  final vibrant = (0xFF << 24) | (vibrantR << 16) | (vibrantG << 8) | vibrantB;
  final contrast = (0xFF << 24) | (contrastR << 16) | (contrastG << 8) | contrastB;

  return [dominant, vibrant, contrast];
}

double _circularHueDistance(double a, double b) {
  final diff = (a - b).abs();
  return diff > 180.0 ? 360.0 - diff : diff;
}

