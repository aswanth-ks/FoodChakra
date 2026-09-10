import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../domain/food_listing.dart';
import '../domain/listing_repository.dart';
import 'listing_dto.dart';

/// Talks to `/api/v1/listings` and returns domain entities.
///
/// `ErrorInterceptor` has already turned transport problems into a [Failure];
/// this class only unwraps them, so callers never handle Dio types.
class ListingRepositoryImpl implements ListingRepository {
  const ListingRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes = const [],
    String? source,
    int limit = 20,
    int offset = 0,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/listings/nearby',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius_km': ?radiusKm,
          if (foodTypes.isNotEmpty) 'food_type': foodTypes,
          'source': ?source,
          'limit': limit,
          'offset': offset,
        },
      );
      return _pageOf(response.data);
    });
  }

  @override
  Future<FoodListing> byId(String id) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/listings/$id');
      return _one(response.data);
    });
  }

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/listings/mine',
        queryParameters: {if (statuses.isNotEmpty) 'status': statuses},
      );
      return _pageOf(response.data);
    });
  }

  @override
  Future<FoodListing> create(NewListing listing) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/listings',
        // Only the fields the server accepts. Ownership, lifecycle state and
        // timestamps are the server's to assign and are rejected if sent.
        data: {
          'food_name': listing.foodName,
          'food_type': listing.foodType,
          'quantity': listing.quantity,
          'unit': listing.unit,
          'safety_confirmed': listing.safetyConfirmed,
          if (listing.source != null) 'source': listing.source,
          if (listing.preparedWhen != null)
            'prepared_when': listing.preparedWhen,
          if (listing.description != null) 'description': listing.description,
          if (listing.tags.isNotEmpty) 'tags': listing.tags,
          if (listing.weightKg != null) 'weight_kg': listing.weightKg,
          'pickup_location': {
            'label': listing.pickupLabel,
            if (listing.pickupLocality != null)
              'locality': listing.pickupLocality,
            'latitude': listing.latitude,
            'longitude': listing.longitude,
          },
          'pickup_from': listing.pickupFrom.toUtc().toIso8601String(),
          'pickup_until': listing.pickupUntil.toUtc().toIso8601String(),
        },
      );
      return _one(response.data);
    });
  }

  @override
  Future<FoodListing> cancel(String id, {String? reason}) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/listings/$id/cancel',
        data: {'reason': ?reason},
      );
      return _one(response.data);
    });
  }

  List<FoodListing> _pageOf(Map<String, dynamic>? data) {
    final items = (data?['items'] as List?) ?? const [];
    return items
        .map(
          (item) => FoodListingDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);
  }

  FoodListing _one(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ServerFailure('The server returned an empty response.');
    }
    return FoodListingDto.fromJson(data).toDomain();
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is Failure ? e.error as Failure : const UnknownFailure();
    }
  }
}
