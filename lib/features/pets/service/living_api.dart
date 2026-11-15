import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api_config.dart';
import '../../../core/api_exception.dart';
import '../models/living_detail.dart';
import '../models/living_summary.dart';
import '../models/update_living_request.dart';

class LivingApi {
  static const String baseUrl = ApiConfig.baseUrl;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// `GET /api/living` -> liste légère pour les cercles.
  Future<List<LivingSummary>> findAll() async {
    try {
      final response = await _dio.get('/api/living');
      final List<dynamic> data = response.data['livings'];
      return data
          .map((json) => LivingSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API findAll : $e\n$stackTrace');
      rethrow;
    }
  }

  /// `GET /api/living/{id}` -> détail complet pour la carte.
  Future<LivingDetail> findById(int id) async {
    try {
      final response = await _dio.get('/api/living/$id');
      return LivingDetail.fromJson(
        response.data['living'] as Map<String, dynamic>,
      );
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API findById($id) : $e\n$stackTrace');
      rethrow;
    }
  }

  /// `PUT /api/living/{id}` -> renvoie le détail à jour.
  /// Toute erreur est convertie en [ApiException] avec un message affichable.
  Future<LivingDetail> update(int id, UpdateLivingRequest request) async {
    try {
      final response = await _dio.put(
        '/api/living/$id',
        data: request.toJson(),
      );
      return LivingDetail.fromJson(
        response.data['living'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('ERREUR LIVING API update($id) : $e');
      throw _toApiException(e);
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API update($id) : $e\n$stackTrace');
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  static ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // ProblemDetail du back : { "detail": "...", "status": 400, ... }
    if (data is Map && data['detail'] is String) {
      return ApiException(data['detail'] as String, statusCode: status);
    }
    return switch (status) {
      400 => ApiException('Some fields are invalid.', statusCode: status),
      404 => ApiException('This pet no longer exists.', statusCode: status),
      null => const ApiException('Server unreachable. Check your connection.'),
      _ => ApiException('Server error ($status).', statusCode: status),
    };
  }
}
