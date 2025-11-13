class RandomImage {
  const RandomImage({
    required this.url,
  });

  final String url;

  factory RandomImage.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const FormatException('Image url is missing');
    }
    return RandomImage(url: url);
  }
}

