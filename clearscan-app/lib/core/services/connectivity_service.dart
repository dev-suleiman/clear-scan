import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';

class ConnectivityService extends AsyncNotifier<bool> {
  late final Dio _dio;

  @override
  Future<bool> build() async {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));

    Connectivity().onConnectivityChanged.listen((_) => refresh());

    return checkConnectivity();
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none) &&
          results.length == 1) {
        return false;
      }
      final response = await _dio
          .get(ApiEndpoints.baseUrl + ApiEndpoints.health);
      return response.statusCode == 200 &&
          response.data['status'] == 'online';
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(checkConnectivity);
  }
}

final connectivityProvider =
    AsyncNotifierProvider<ConnectivityService, bool>(
  ConnectivityService.new,
);
