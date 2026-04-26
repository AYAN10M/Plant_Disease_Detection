import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  // Convert any DioException into a friendly message
  factory ApiException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Connection timed out. Check your internet.');

      case DioExceptionType.connectionError:
        return const ApiException('Cannot reach server. Is Django running?');

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;

        // Try to extract Django's error message from response
        String msg = 'Something went wrong';
        if (data is Map) {
          // Django returns errors like {"email": ["This field is required"]}
          msg = data.values.expand((v) => v is List ? v : [v]).join(' ');
        }
        return ApiException(msg, statusCode: status);

      default:
        return const ApiException('Unexpected error. Please try again.');
    }
  }

  @override
  String toString() => message;
}
