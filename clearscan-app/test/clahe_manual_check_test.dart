import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:image/image.dart' as img;
import 'package:clearscan_app/core/services/clahe_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _FakePathProvider(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;
}

double _mean(List<int> vals) => vals.reduce((a, b) => a + b) / vals.length;

double _variance(List<int> vals) {
  final m = _mean(vals);
  final sq = vals.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b);
  return sq / vals.length;
}

/// Sharpness proxy: variance of the discrete Laplacian.
double _laplacianVariance(img.Image image) {
  final w = image.width, h = image.height;
  final lap = <int>[];
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final c = image.getPixel(x, y).r.toInt();
      final up = image.getPixel(x, y - 1).r.toInt();
      final down = image.getPixel(x, y + 1).r.toInt();
      final left = image.getPixel(x - 1, y).r.toInt();
      final right = image.getPixel(x + 1, y).r.toInt();
      lap.add(4 * c - up - down - left - right);
    }
  }
  return _variance(lap);
}

img.Image _buildSyntheticXray() {
  final rng = Random(42);
  final base = img.Image(width: 512, height: 512, numChannels: 1);
  for (int y = 0; y < 512; y++) {
    for (int x = 0; x < 512; x++) {
      final dx1 = x - 180, dy1 = y - 280;
      final dx2 = x - 330, dy2 = y - 280;
      final inLung1 = (dx1 * dx1) / (110 * 110) + (dy1 * dy1) / (180 * 180) <= 1;
      final inLung2 = (dx2 * dx2) / (110 * 110) + (dy2 * dy2) / (180 * 180) <= 1;
      final inSpine = x > 230 && x < 280 && y > 100 && y < 460;
      double v = 0.35;
      if (inLung1 || inLung2) v += 0.55;
      if (inSpine) v = 0.75 + 0.35;
      final px = (v * 255).clamp(0, 255).toInt();
      base.setPixelRgb(x, y, px, px, px);
    }
  }
  // Blur first (soft-focus scan), then add per-pixel noise on top so it
  // stays genuinely high-frequency.
  final blurred = img.gaussianBlur(base, radius: 3);
  for (int y = 0; y < 512; y++) {
    for (int x = 0; x < 512; x++) {
      final v = blurred.getPixel(x, y).r.toInt();
      final noise = rng.nextDouble() * 16 - 8;
      final px = (v + noise).clamp(0, 255).toInt();
      blurred.setPixelRgb(x, y, px, px, px);
    }
  }
  return blurred;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('clahe_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
      'ClaheService.enhanceImage produces a valid, genuinely sharpened '
      'output (regression: image.gaussianBlur mutates its argument in '
      'place, which previously made the unsharp-mask step a no-op)',
      () async {
    final input = _buildSyntheticXray();
    final inputBytes = img.encodePng(input);
    final inputFile = File('${tempDir.path}/input.png')
      ..writeAsBytesSync(inputBytes);

    final beforeLap = _laplacianVariance(img.grayscale(input));

    final outFile = await ClaheService().enhanceImage(inputFile);
    expect(outFile.existsSync(), isTrue);

    final after = img.decodeImage(outFile.readAsBytesSync());
    expect(after, isNotNull);
    expect(after!.width, equals(input.width));
    expect(after.height, equals(input.height));

    final afterLap = _laplacianVariance(after);

    // CLAHE + a working unsharp mask should sharpen the image substantially.
    // Before the fix (blurring an aliased reference instead of a clone),
    // this came out *below* 1.0 — the pipeline net-blurred the image.
    expect(afterLap / beforeLap, greaterThan(2.0),
        reason: 'expected the enhancement pipeline to sharpen the image, '
            'but it came out flatter than the input (before=$beforeLap, '
            'after=$afterLap) — the unsharp-mask step may be a no-op again');
  });
}
