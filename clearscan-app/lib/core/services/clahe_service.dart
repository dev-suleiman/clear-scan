// import 'dart:io';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image/image.dart' as img;
// import 'package:path_provider/path_provider.dart';

// class ClaheService {
//   /// Offline enhancement pipeline:
//   /// grayscale → histogram equalisation → gaussian blur → unsharp mask
//   Future<File> enhanceImage(File imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       var image = img.decodeImage(bytes);
//       if (image == null) return imageFile;

//       image = img.grayscale(image);
//       image = _histogramEqualise(image);
//       final blurred = img.gaussianBlur(image, radius: 1);
//       image = _unsharpMask(image, blurred);

//       final tmp = await getTemporaryDirectory();
//       final out = File(
//           '${tmp.path}/clahe_${DateTime.now().millisecondsSinceEpoch}.png')
//         ..writeAsBytesSync(img.encodePng(image));
//       return out;
//     } catch (_) {
//       return imageFile;
//     }
//   }

//   img.Image _histogramEqualise(img.Image src) {
//     final hist = List<int>.filled(256, 0);
//     for (final pixel in src) {
//       hist[pixel.r.toInt().clamp(0, 255)]++;
//     }
//     final cdf = List<int>.filled(256, 0);
//     cdf[0] = hist[0];
//     for (int i = 1; i < 256; i++) {
//       cdf[i] = cdf[i - 1] + hist[i];
//     }
//     final cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 1);
//     final n = src.width * src.height;
//     final lut = List<int>.generate(256, (i) {
//       if (n <= cdfMin) return i;
//       return ((cdf[i] - cdfMin) / (n - cdfMin) * 255).round().clamp(0, 255);
//     });
//     final out = src.clone();
//     for (final pixel in out) {
//       final eq = lut[pixel.r.toInt().clamp(0, 255)];
//       pixel.r = eq;
//       pixel.g = eq;
//       pixel.b = eq;
//     }
//     return out;
//   }

//   img.Image _unsharpMask(img.Image original, img.Image blurred) {
//     final out = original.clone();
//     final w = original.width;
//     final h = original.height;
//     for (int y = 0; y < h; y++) {
//       for (int x = 0; x < w; x++) {
//         final oc = original.getPixel(x, y);
//         final bc = blurred.getPixel(x, y);
//         final v = ((oc.r * 1.5) - (bc.r * 0.5)).round().clamp(0, 255);
//         final p = out.getPixel(x, y);
//         p.r = v;
//         p.g = v;
//         p.b = v;
//       }
//     }
//     return out;
//   }
// }

// final claheServiceProvider = Provider<ClaheService>((ref) => ClaheService());


import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ClaheService {
  Future<File> enhanceImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      // Convert to grayscale
      image = img.grayscale(image);

      // Apply CLAHE (tile-based limited histogram equalisation)
      image = _applyClahe(image, tileSize: 64, clipLimit: 2.0);

      // Gentle unsharp mask for sharpness
      final blurred = img.gaussianBlur(image, radius: 1);
      image = _unsharpMask(image, blurred, amount: 0.5);

      final tmp = await getTemporaryDirectory();
      final out =
          File('${tmp.path}/clahe_${DateTime.now().millisecondsSinceEpoch}.png')
            ..writeAsBytesSync(img.encodePng(image));
      return out;
    } catch (e) {
      print('CLAHE error: $e');
      return imageFile;
    }
  }

  /// Contrast Limited Adaptive Histogram Equalisation
  img.Image _applyClahe(img.Image src,
      {int tileSize = 64, double clipLimit = 2.0}) {
    final w = src.width;
    final h = src.height;
    final out = src.clone();

    final cols = (w / tileSize).ceil();
    final rows = (h / tileSize).ceil();

    // Build a LUT for each tile
    final luts = List.generate(
        rows,
        (r) => List.generate(cols, (c) {
              final x0 = c * tileSize;
              final y0 = r * tileSize;
              final x1 = min(x0 + tileSize, w);
              final y1 = min(y0 + tileSize, h);

              // Build histogram for this tile
              final hist = List<int>.filled(256, 0);
              for (int y = y0; y < y1; y++) {
                for (int x = x0; x < x1; x++) {
                  hist[src.getPixel(x, y).r.toInt().clamp(0, 255)]++;
                }
              }

              // Clip histogram
              final tilePixels = (x1 - x0) * (y1 - y0);
              final clip =
                  (clipLimit * tilePixels / 256).round().clamp(1, tilePixels);
              int excess = 0;
              for (int i = 0; i < 256; i++) {
                if (hist[i] > clip) {
                  excess += hist[i] - clip;
                  hist[i] = clip;
                }
              }
              // Redistribute excess evenly
              final add = excess ~/ 256;
              for (int i = 0; i < 256; i++) {
                hist[i] += add;
              }

              // Build CDF → LUT
              final cdf = List<int>.filled(256, 0);
              cdf[0] = hist[0];
              for (int i = 1; i < 256; i++) {
                cdf[i] = cdf[i - 1] + hist[i];
              }
              final cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 1);
              final n = tilePixels;

              return List<int>.generate(256, (i) {
                if (n <= cdfMin) return i;
                return ((cdf[i] - cdfMin) / (n - cdfMin) * 255)
                    .round()
                    .clamp(0, 255);
              });
            }));

    // Apply bilinear interpolation between tile LUTs
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = src.getPixel(x, y).r.toInt().clamp(0, 255);

        // Find tile coordinates
        final tileX = x / tileSize - 0.5;
        final tileY = y / tileSize - 0.5;

        final tx0 = tileX.floor().clamp(0, cols - 1);
        final ty0 = tileY.floor().clamp(0, rows - 1);
        final tx1 = (tx0 + 1).clamp(0, cols - 1);
        final ty1 = (ty0 + 1).clamp(0, rows - 1);

        final fx = (tileX - tileX.floor()).clamp(0.0, 1.0);
        final fy = (tileY - tileY.floor()).clamp(0.0, 1.0);

        // Bilinear blend of 4 surrounding tile LUTs
        final v00 = luts[ty0][tx0][v].toDouble();
        final v10 = luts[ty0][tx1][v].toDouble();
        final v01 = luts[ty1][tx0][v].toDouble();
        final v11 = luts[ty1][tx1][v].toDouble();

        final blended = (v00 * (1 - fx) * (1 - fy) +
                v10 * fx * (1 - fy) +
                v01 * (1 - fx) * fy +
                v11 * fx * fy)
            .round()
            .clamp(0, 255);

        final p = out.getPixel(x, y);
        p.r = blended;
        p.g = blended;
        p.b = blended;
      }
    }

    return out;
  }

  img.Image _unsharpMask(img.Image original, img.Image blurred,
      {double amount = 0.5}) {
    final out = original.clone();
    final w = original.width;
    final h = original.height;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final oc = original.getPixel(x, y).r.toDouble();
        final bc = blurred.getPixel(x, y).r.toDouble();
        final v = (oc + amount * (oc - bc)).round().clamp(0, 255);
        final p = out.getPixel(x, y);
        p.r = v;
        p.g = v;
        p.b = v;
      }
    }
    return out;
  }
}

final claheServiceProvider = Provider<ClaheService>((ref) => ClaheService());
