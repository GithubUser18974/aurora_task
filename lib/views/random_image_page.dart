import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../controllers/random_image_controller.dart';
import '../models/random_image.dart';
import '../services/random_image_service.dart';
import 'widgets/common_widgets.dart';

class RandomImagePage extends StatefulWidget {
  const RandomImagePage({
    super.key,
    this.controller,
    this.autoLoad = true,
  });

  final RandomImageController? controller;
  final bool autoLoad;

  @override
  State<RandomImagePage> createState() => _RandomImagePageState();
}

class _RandomImagePageState extends State<RandomImagePage> {
  static const _baseUrl =
      'https://november7-730026606190.europe-west1.run.app';
  late final RandomImageController _controller;
  RandomImageController? _ownedController;

  @override
  void initState() {
    super.initState();
    final controller = widget.controller ?? _createController();
    if (widget.controller == null) {
      _ownedController = controller;
    }
    _controller = controller;

    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.loadRandomImage();
      });
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  RandomImageController _createController() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    return RandomImageController(
      RandomImageService(dio),
      dio: dio,
      initialBackgroundColor: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final backgroundColor = _controller.backgroundColor;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              color: backgroundColor,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double size = _imageSize(constraints);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Semantics(
                            label: 'Randomly fetched image',
                            image: true,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                width: size,
                                height: size,
                                child: _buildImageContent(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildPrimaryButton(context),
                          const SizedBox(height: 12),
                          _buildStatusText(context),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _imageSize(BoxConstraints constraints) {
    final shortestSide = min(constraints.maxWidth, constraints.maxHeight);
    final target = shortestSide * 0.7;
    return target.clamp(220.0, 420.0);
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return Semantics(
      button: true,
      child: Tooltip(
        message: 'Fetch another random image',
        child: FilledButton(
          onPressed: _controller.isLoading ? null : _controller.loadRandomImage,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Another'),
        ),
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage = _controller.errorMessage;

    if (errorMessage != null) {
      return AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 300),
        child: Text(
          errorMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    if (_controller.isLoading) {
      return Text(
        'Fetching a new image...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageContent() {
    final RandomImage? image = _controller.currentImage;

    if (image == null && _controller.isLoading) {
      return LoadingPlaceholder(
        backgroundColor: Colors.black.withValues(alpha: 0.2),
      );
    }

    if (image == null) {
      return ErrorPlaceholder(
        onRetry: _controller.loadRandomImage,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Builder(
            builder: (context) {
              final dp = MediaQuery.of(context).devicePixelRatio;
              final sizedUrl = _sizedQualityUrl(image.url, (dp * _currentTargetSize(context)).round());
              final memWidth = (dp * _currentTargetSize(context)).round();
              final diskWidth = memWidth;
              return CachedNetworkImage(
                key: ValueKey(sizedUrl),
                imageUrl: sizedUrl,
                memCacheWidth: memWidth,
                maxWidthDiskCache: diskWidth,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (context, url) => LoadingPlaceholder(
                  backgroundColor: Colors.black.withValues(alpha: 0.15),
                ),
                errorWidget: (context, url, error) => ErrorPlaceholder(
                  onRetry: _controller.loadRandomImage,
                ),
              );
            },
          ),
        ),
        if (_controller.isLoading) const LoadingOverlay(),
      ],
    );
  }

  double _currentTargetSize(BuildContext context) {
    final constraints = BoxConstraints.tight(MediaQuery.of(context).size);
    return _imageSize(constraints);
  }

  String _sizedQualityUrl(String url, int targetPixelWidth) {
    final separator = url.contains('?') ? '&' : '?';
    // Request server-sized image to save bandwidth/CPU. Quality 75 is a good balance.
    return '$url${separator}w=$targetPixelWidth&q=75&fit=crop';
  }
}

