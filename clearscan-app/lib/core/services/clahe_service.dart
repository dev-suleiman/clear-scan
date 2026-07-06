import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ClaheService {
  /// Offline enhancement pipeline:
  /// grayscale → histogram equalisation → gaussian blur → unsharp mask
  Future<File> enhanceImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      image = img.grayscale(image);
      image = _histogramEqualise(image);
      final blurred = img.gaussianBlur(image, radius: 1);
      image = _unsharpMask(image, blurred);

      final tmp = await getTemporaryDirectory();
      final out = File(
          '${tmp.path}/clahe_${DateTime.now().millisecondsSinceEpoch}.png')
        ..writeAsBytesSync(img.encodePng(image));
      return out;
    } catch (_) {
      return imageFile;
    }
  }

  img.Image _histogramEqualise(img.Image src) {
    final hist = List<int>.filled(256, 0);
    for (final pixel in src) {
      hist[pixel.r.toInt().clamp(0, 255)]++;
    }
    final cdf = List<int>.filled(256, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + hist[i];
    }
    final cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 1);
    final n = src.width * src.height;
    final lut = List<int>.generate(256, (i) {
      if (n <= cdfMin) return i;
      return ((cdf[i] - cdfMin) / (n - cdfMin) * 255).round().clamp(0, 255);
    });
    final out = src.clone();
    for (final pixel in out) {
      final eq = lut[pixel.r.toInt().clamp(0, 255)];
      pixel.r = eq;
      pixel.g = eq;
      pixel.b = eq;
    }
    return out;
  }

  img.Image _unsharpMask(img.Image original, img.Image blurred) {
    final out = original.clone();
    final w = original.width;
    final h = original.height;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final oc = original.getPixel(x, y);
        final bc = blurred.getPixel(x, y);
        final v = ((oc.r * 1.5) - (bc.r * 0.5)).round().clamp(0, 255);
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
