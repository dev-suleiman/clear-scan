import 'package:clearscan_app/core/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local TFLite model loads from bundled app assets', () async {
    final service = TFLiteService();

    final loaded = await service.ensureLoaded();

    expect(loaded, isTrue,
        reason:
            'The bundled quality classifier model should load successfully from app assets.');
    expect(service.isAvailable, isTrue,
        reason: 'The interpreter should be available for offline inference.');

    service.dispose();
  });
}
