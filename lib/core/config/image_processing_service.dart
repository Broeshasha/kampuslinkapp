import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:blurhash_dart/blurhash_dart.dart';

class ProcessedImage {
  final Uint8List imageBytes;
  final String blurhash;
  const ProcessedImage(this.imageBytes, this.blurhash);
}

/// One shared pipeline for every image in the app — avatars, marketplace
/// listings, report screenshots. Resize -> JPEG -> BlurHash, all on-device.
/// Note: pure-Dart WebP *encoding* isn't available cross-platform (the
/// `image` package only decodes WebP, it can't write it) — JPEG at high
/// quality gets nearly the same size reduction and works everywhere.
class ImageProcessingService {
  static ProcessedImage process(
    Uint8List originalBytes, {
    int maxDimension = 720,
    int quality = 85,
  }) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw Exception('Could not decode image');
    }

    final resized = decoded.width > maxDimension || decoded.height > maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDimension : null,
            height: decoded.height > decoded.width ? maxDimension : null,
          )
        : decoded;

    final jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    final thumbForHash = img.copyResize(resized, width: 32);
    final blurhash = BlurHash.encode(thumbForHash, numCompX: 4, numCompY: 3).hash;

    return ProcessedImage(jpegBytes, blurhash);
  }
}