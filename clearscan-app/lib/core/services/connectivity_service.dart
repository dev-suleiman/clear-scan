import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import 'api_service.dart' show backendUrlProvider;

/// Debug-only "Force Offline Mode" switch in Settings.
final forceOfflineProvider = StateProvider<bool>((ref) => false);

class ConnectivityService extends AsyncNotifier<bool> {
  late final Dio _dio;
  @override
  Future<bool> build() async {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    Connectivity().onConnectivityChanged.listen((_) => refresh());
    return checkConnectivity(); }
  Future<bool> checkConnectivity() async {
    if (ref.read(forceOfflineProvider)) return false;
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none) &&
          results.length == 1) {
        return false;
      }
      final baseUrl = ref.read(backendUrlProvider);
      final response = await _dio
          .get(baseUrl + ApiEndpoints.health);
      return response.statusCode == 200 &&
          (response.data['status'] == 'ok' ||
              response.data['status'] == 'online');
    } catch (_) { return false;}}
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(checkConnectivity);
  }
}
final connectivityProvider =
    AsyncNotifierProvider<ConnectivityService, bool>(
  ConnectivityService.new,
);
