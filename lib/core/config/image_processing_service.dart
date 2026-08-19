import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:blurhash_dart/blurhash_dart.dart';

class ProcessedImage {
  final Uint8List webpBytes;
  final String blurhash;
  const ProcessedImage(this.webpBytes, this.blurhash);
}

/// One shared pipeline for every image in the app — avatars, marketplace
/// listings, report screenshots. Resize -> WebP -> BlurHash, all on-device,
/// so the Worker/R2 side never has to do (or pay for) image processing.
class ImageProcessingService {
  static ProcessedImage process(
    Uint8List originalBytes, {
    int maxDimension = 720,
    int quality = 82,
  }) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw Exception('Could not decode image');
    }

    // Resize only if larger than target — never upscale a small image.
    final resized = decoded.width > maxDimension || decoded.height > maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDimension : null,
            height: decoded.height > decoded.width ? maxDimension : null,
          )
        : decoded;

    final webpBytes = Uint8List.fromList(img.encodeWebP(resized, quality: quality));

    // BlurHash generated from a tiny thumbnail — fast, and the hash only
    // needs to capture rough shape/color, not detail.
    final thumbForHash = img.copyResize(resized, width: 32);
    final blurhash = BlurHash.encode(thumbForHash, numCompX: 4, numCompY: 3).hash;

    return ProcessedImage(webpBytes, blurhash);
  }
}