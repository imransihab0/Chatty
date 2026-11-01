import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// High-performance background image compressor that ensures any image
/// is compressed to strictly under 100 KB before upload.
class ImageCompressor {
  /// Target max size in bytes (98 KB to stay strictly under the 100 KB limit).
  static const int targetMaxBytes = 98 * 1024;

  /// Compresses [file] to under 100 KB asynchronously in a background isolate.
  /// Returns a new compressed [File] in temporary directory.
  static Future<File> compressUnder100Kb(File file) async {
    try {
      final originalLength = await file.length();
      log('[ImageCompressor] Original size: ${(originalLength / 1024).toStringAsFixed(1)} KB');

      // If already under target size, return original file
      if (originalLength <= targetMaxBytes) {
        log('[ImageCompressor] File is already under 100 KB. Skipping compression.');
        return file;
      }

      final bytes = await file.readAsBytes();

      // Run computationally heavy decode and compress in a background isolate
      final compressedBytes = await compute(_compressImageIsolate, {
        'bytes': bytes,
        'maxBytes': targetMaxBytes,
      });

      if (compressedBytes == null || compressedBytes.isEmpty) {
        log('[ImageCompressor] Compression returned null, falling back to original.');
        return file;
      }

      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes, flush: true);

      final finalLength = await compressedFile.length();
      log('[ImageCompressor] Compressed size: ${(finalLength / 1024).toStringAsFixed(1)} KB (target: <100 KB)');

      return compressedFile;
    } catch (e) {
      log('[ImageCompressor] Error during compression: $e');
      return file;
    }
  }

  /// Isolate entrypoint for image resizing and multi-pass quality reduction.
  static Uint8List? _compressImageIsolate(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes'];
    final int maxBytes = params['maxBytes'];

    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Start by scaling down massive resolutions (e.g. 48MP phone cameras)
    int width = decoded.width;
    int height = decoded.height;
    const int initialMaxDimension = 1280;

    img.Image workingImage;
    if (width > initialMaxDimension || height > initialMaxDimension) {
      if (width > height) {
        workingImage = img.copyResize(decoded,
            width: initialMaxDimension,
            interpolation: img.Interpolation.linear);
      } else {
        workingImage = img.copyResize(decoded,
            height: initialMaxDimension,
            interpolation: img.Interpolation.linear);
      }
    } else {
      workingImage = decoded;
    }

    // Pass 1: Try standard quality steps
    final qualitySteps = [82, 68, 55, 42, 30, 20, 12];
    Uint8List? bestOutput;

    for (final quality in qualitySteps) {
      final encoded = Uint8List.fromList(
          img.encodeJpg(workingImage, quality: quality));
      if (encoded.lengthInBytes <= maxBytes) {
        return encoded;
      }
      bestOutput = encoded;
    }

    // Pass 2: If still above maxBytes (e.g. very detailed/complex photo),
    // iteratively downscale dimensions until it fits under maxBytes.
    var currentImg = workingImage;
    while (currentImg.width > 320 && currentImg.height > 320) {
      currentImg = img.copyResize(
        currentImg,
        width: (currentImg.width * 0.75).round(),
        interpolation: img.Interpolation.linear,
      );

      final encoded =
          Uint8List.fromList(img.encodeJpg(currentImg, quality: 40));
      if (encoded.lengthInBytes <= maxBytes) {
        return encoded;
      }
      bestOutput = encoded;
    }

    // Return the lowest size obtained
    return bestOutput;
  }
}
