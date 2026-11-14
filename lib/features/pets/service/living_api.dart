import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../models/living_item.dart';

class LivingApi {
  static const String baseUrl = 'http://192.168.1.101:8080';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Future<List<LivingItem>> findAll() async {
    try {
      final response = await _dio.get('/api/living');

      debugPrint('REPONSE API : ${response.data}');

      final List<dynamic> data = response.data['livings'];

      final livings = data.map((json) {
        debugPrint('CONVERSION JSON : $json');
        return LivingItem.fromJson(json);
      }).toList();

      debugPrint('LIVINGS CONVERTIS : ${livings.length}');

      return livings;
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API : $e');
      debugPrint('STACK TRACE : $stackTrace');
      rethrow;
    }
  }
}
