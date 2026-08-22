import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class BlurHashImage extends StatelessWidget {
  final String imageUrl;
  final String? blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const BlurHashImage({
    super.key,
    required this.imageUrl,
    this.blurhash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => blurhash != null
          ? BlurHash(hash: blurhash!)
          : Container(color: Colors.grey.shade900),
      errorWidget: (context, url, error) {
        debugPrint('BlurHashImage failed to load: $url — $error');
        return Container(
          color: Colors.grey.shade900,
          child: const Icon(Icons.person, color: Colors.white38),
        );
      },
      fadeInDuration: const Duration(milliseconds: 250),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}