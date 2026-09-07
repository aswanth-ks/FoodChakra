import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../domain/health_repository.dart';
import '../domain/health_status.dart';
import 'health_dto.dart';

/// Talks to the backend and returns domain entities.
///
/// `ErrorInterceptor` has already converted transport problems into a
/// [Failure]; this class only unwraps it so callers never handle Dio types.
class HealthRepositoryImpl implements HealthRepository {
  const HealthRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<HealthStatus> fetchHealth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/health');
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('The server returned an empty response.');
      }
      return HealthDto.fromJson(data).toDomain();
    } on DioException catch (e) {
      throw e.error is Failure ? e.error as Failure : const UnknownFailure();
    }
  }
}
