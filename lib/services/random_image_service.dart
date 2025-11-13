import 'package:dio/dio.dart';

import '../models/random_image.dart';

class RandomImageService {
  RandomImageService(this._dio);

  final Dio _dio;

  Future<RandomImage> fetchRandomImage() async {
    final response = await _dio.get<Map<String, dynamic>>('/image');
    final data = response.data;

    if (data == null) {
      throw const FormatException('Missing response body');
    }

    return RandomImage.fromJson(data);
  }
}

