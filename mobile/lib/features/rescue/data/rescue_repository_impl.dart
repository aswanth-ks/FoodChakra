import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../domain/rescue.dart';
import '../domain/rescue_repository.dart';
import 'rescue_dto.dart';

/// Talks to `/api/v1/rescues` and returns domain entities.
class RescueRepositoryImpl implements RescueRepository {
  const RescueRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<Rescue> claim(String listingId) => _guard(() async {
    // Only the listing id is sent. Who is rescuing, when, and in what state
    // are all the server's to decide, and it rejects the request if any of
    // them is supplied.
    final response = await _dio.post<Map<String, dynamic>>(
      '/rescues',
      data: {'listing_id': listingId},
    );
    return _one(response.data);
  });

  @override
  Future<Rescue> byId(String rescueId) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/rescues/$rescueId');
    return _one(response.data);
  });

  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/rescues/mine',
      queryParameters: {if (activeOnly) 'active': true},
    );
    final items = (response.data?['items'] as List?) ?? const [];
    return items
        .map(
          (item) =>
              RescueDto.fromJson((item as Map).cast<String, dynamic>()).toDomain(),
        )
        .toList(growable: false);
  });

  @override
  Future<Rescue> startTravel(String rescueId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rescues/$rescueId/on-the-way',
    );
    return _one(response.data);
  });

  @override
  Future<Rescue> activeForListing(String listingId) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/rescues/for-listing/$listingId',
    );
    return _one(response.data);
  });

  @override
  Future<Rescue> markArrived(String rescueId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rescues/$rescueId/arrived',
    );
    return _one(response.data);
  });

  @override
  Future<Rescue> verifyHandover(String rescueId, {required String code}) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/rescues/$rescueId/verify',
          data: {'code': code},
        );
        return _one(response.data);
      });

  @override
  Future<Rescue> markCollected(String rescueId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rescues/$rescueId/collected',
    );
    return _one(response.data);
  });

  @override
  Future<Rescue> cancel(String rescueId, {String? reason}) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rescues/$rescueId/cancel',
      data: {'reason': ?reason},
    );
    return _one(response.data);
  });

  Rescue _one(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ServerFailure('The server returned an empty response.');
    }
    return RescueDto.fromJson(data).toDomain();
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is Failure ? e.error as Failure : const UnknownFailure();
    }
  }
}
