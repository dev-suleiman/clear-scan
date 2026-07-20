abstract class ApiEndpoints {
  // Update this to your actual backend deployment URL
  static const String baseUrl = 'http://13.49.30.153:8000';
  static const String health = '/api/v1/health';
  static const String assess = '/api/v1/assess';
  static const String enhanceClahe = '/api/v1/enhance/clahe';
  static const String enhanceCnn = '/api/v1/enhance/cnn';
  static const String compare = '/api/v1/compare';
}
