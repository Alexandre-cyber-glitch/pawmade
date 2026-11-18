import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api_config.dart';
import '../../../core/api_exception.dart';
import '../models/living_detail.dart';
import '../models/living_summary.dart';
import '../models/photo_upload.dart';
import '../models/update_living_request.dart';

class LivingApi {
  static const String baseUrl = ApiConfig.baseUrl;

  final Dio _dio;

  /// [dio] est optionnel : les tests en passent un avec un faux adaptateur
  /// HTTP pour simuler les réponses du back sans serveur.
  LivingApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
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

  /// Change l'avatar ou la cover en une seule action côté UI :
  /// 1. `POST /api/living/{id}/photos` (upload du fichier)
  /// 2. `PUT  /api/living/{id}/avatar|cover` avec l'id de la photo créée.
  /// Renvoie le détail à jour (avec la nouvelle URL).
  Future<LivingDetail> changePhoto(
    int livingId,
    PhotoSlot slot, {
    required List<int> bytes,
    required String filename,
  }) async {
    final photo = await uploadPhoto(livingId, bytes: bytes, filename: filename);
    return setPhoto(livingId, slot, photo.id);
  }

  /// `POST /api/living/{id}/photos` (multipart, champ `file`).
  Future<PhotoUpload> uploadPhoto(
    int livingId, {
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '/api/living/$livingId/photos',
        data: form,
        // Un upload prend plus de temps qu'un simple GET.
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return PhotoUpload.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('ERREUR LIVING API uploadPhoto($livingId) : $e');
      throw _toApiException(e);
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API uploadPhoto($livingId) : $e\n$stackTrace');
      throw const ApiException('Upload failed. Please try again.');
    }
  }

  /// `PUT /api/living/{id}/avatar|cover` `{ "photoId": "…" }`.
  Future<LivingDetail> setPhoto(
    int livingId,
    PhotoSlot slot,
    String photoId,
  ) async {
    try {
      final response = await _dio.put(
        '/api/living/$livingId/${slot.path}',
        data: {'photoId': photoId},
      );
      return LivingDetail.fromJson(
        response.data['living'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('ERREUR LIVING API setPhoto($livingId, ${slot.path}) : $e');
      throw _toApiException(e);
    } catch (e, stackTrace) {
      debugPrint('ERREUR LIVING API setPhoto : $e\n$stackTrace');
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
      413 => ApiException('Image too large (max 10 MB).', statusCode: status),
      null => const ApiException('Server unreachable. Check your connection.'),
      _ => ApiException('Server error ($status).', statusCode: status),
    };
  }
}
