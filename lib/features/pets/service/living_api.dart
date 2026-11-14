import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/living_detail.dart';
import '../models/living_summary.dart';

class LivingApi {
  static const String baseUrl = 'http://192.168.1.101:8080';

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
}
