import 'package:dio/dio.dart';
import 'api_exception.dart';

abstract class BaseService {
  final Dio dio;
  BaseService(this.dio);

  // Wrap any API call — catches DioException → throws ApiException
  Future<T> handleRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
