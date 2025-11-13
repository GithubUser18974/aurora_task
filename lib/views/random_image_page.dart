import 'dart:math';
import 'dart:ui' as ui;

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
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _BlurredMultiColorBackground(
                tint: backgroundColor,
                palette: _controller.backgroundGradient,
              ),
              SafeArea(
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Semantics(
                                  label: 'Randomly fetched image',
                                  image: true,
                                  child: SizedBox(
                                    width: size,
                                    height: size,
                                    child: _buildImageContent(),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _buildStatusText(context),
                            ),
                            const SizedBox(height: 16),
                            _buildPrimaryButton(
                              context,
                              _controller.backgroundGradient,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
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

  Widget _buildPrimaryButton(BuildContext context, List<Color> palette) {
    return Semantics(
      button: true,
      child: Tooltip(
        message: 'Fetch another random image',
        child: _GradientButton(
          isDisabled: _controller.isLoading,
          colors: palette,
          onPressed: _controller.isLoading ? null : _controller.loadRandomImage,
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
        backgroundColor: Colors.transparent,
      );
    }

    if (image == null) {
      return ErrorPlaceholder(
        onRetry: _controller.loadRandomImage,
      );
    }

    return _EdgeFade(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Builder(
              builder: (context) {
                final dp = MediaQuery.of(context).devicePixelRatio;
                final target = (dp * _currentTargetSize(context)).round();
                final sizedUrl = _sizedQualityUrl(image.url, target);
                final memWidth = target;
                final diskWidth = memWidth;
                return CachedNetworkImage(
                  key: ValueKey(sizedUrl),
                  imageUrl: sizedUrl,
                  memCacheWidth: memWidth,
                  maxWidthDiskCache: diskWidth,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                  placeholder: (context, url) => LoadingPlaceholder(
                    backgroundColor: Colors.transparent,
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
      ),
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

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        // Soft feathered edges: keep center opaque, fade to transparent at bounds
        return const RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.70, 0.88, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.child,
    required this.colors,
    this.isDisabled = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final List<Color> colors;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = _resolveColors(colors, theme);

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DefaultTextStyle(
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _resolveColors(List<Color> palette, ThemeData theme) {
    if (palette.isEmpty) {
      final fallback = theme.colorScheme.primary;
      return [fallback.withValues(alpha: 0.9), fallback];
    }
    if (palette.length == 1) {
      final first = palette.first;
      return [first, first.withValues(alpha: 0.75)];
    }
    if (palette.length == 2) {
      return palette;
    }
    return [palette[0], palette[1], palette[2]];
  }
}

class _BlurredMultiColorBackground extends StatelessWidget {
  const _BlurredMultiColorBackground({
    required this.tint,
    required this.palette,
  });

  final Color tint;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    final base = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Blend in the palette colors softly as the base wash
            (palette.isNotEmpty ? palette[0] : tint).withValues(alpha: 0.18),
            (palette.length > 1 ? palette[1] : theme.colorScheme.surface)
                .withValues(alpha: 0.12),
            (palette.length > 2 ? palette[2] : Colors.black)
                .withValues(alpha: 0.10),
          ],
        ),
      ),
    );

    final blobs = Stack(
      children: [
        // Blob 1 top-left
        Positioned(
          left: -size.width * 0.2,
          top: -size.width * 0.2,
          child: _blob(
            diameter: size.width * 0.9,
            color: (palette.isNotEmpty ? palette[0] : const Color(0xFFFF7AD6))
                .withValues(alpha: 0.60),
          ),
        ),
        // Blob 2 top-right
        Positioned(
          right: -size.width * 0.15,
          top: size.height * 0.08,
          child: _blob(
            diameter: size.width * 0.7,
            color: (palette.length > 1 ? palette[1] : const Color(0xFF6AB7FF))
                .withValues(alpha: 0.55),
          ),
        ),
        // Blob 3 center-left
        Positioned(
          left: size.width * 0.05,
          top: size.height * 0.38,
          child: _blob(
            diameter: size.width * 0.65,
            color: (palette.length > 2 ? palette[2] : const Color(0xFF9B6BFF))
                .withValues(alpha: 0.50),
          ),
        ),
        // Blob 4 bottom-right (reusing a blended color)
        Positioned(
          right: -size.width * 0.1,
          bottom: -size.width * 0.2,
          child: _blob(
            diameter: size.width * 0.95,
            color: Color.alphaBlend(
              (palette.isNotEmpty ? palette[0] : const Color(0xFFFFB86C))
                  .withValues(alpha: 0.25),
              (palette.length > 1 ? palette[1] : const Color(0xFFFFB86C))
                  .withValues(alpha: 0.25),
            ).withValues(alpha: 0.50),
          ),
        ),
        // Blob 5 bottom-left (mix of palette extremes)
        Positioned(
          left: -size.width * 0.1,
          bottom: size.height * 0.12,
          child: _blob(
            diameter: size.width * 0.6,
            color: Color.alphaBlend(
              (palette.length > 2 ? palette[2] : const Color(0xFF4BE1C3))
                  .withValues(alpha: 0.25),
              (palette.isNotEmpty ? palette[0] : const Color(0xFF4BE1C3))
                  .withValues(alpha: 0.25),
            ).withValues(alpha: 0.45),
          ),
        ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 90, sigmaY: 90),
          child: blobs,
        ),
        // Subtle overlay to blend with the dynamic tint
        Container(color: tint.withValues(alpha: 0.08)),
      ],
    );
  }

  Widget _blob({required double diameter, required Color color}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

