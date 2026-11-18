import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmade/core/api_exception.dart';
import 'package:pawmade/features/pets/models/photo_upload.dart';
import 'package:pawmade/features/pets/models/update_living_request.dart';
import 'package:pawmade/features/pets/service/living_api.dart';

/// Faux "serveur" : Dio lui passe chaque requête au lieu de l'envoyer
/// sur le réseau. On enregistre les requêtes et on renvoie la réponse voulue.
class FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions request) handler;
  final requests = <RequestOptions>[];

  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// ProblemDetail renvoyé par le GlobalExceptionHandler du back.
ResponseBody problem(int status, String detail) =>
    jsonResponse({'status': status, 'detail': detail}, status);

const dogJson = {
  'id': 1,
  'name': 'Warm Waffle',
  'type': 'DOG',
  'avatarUrl': '/api/photos/a/content',
  'coverUrl': '/api/photos/c/content',
  'birthDate': '2025-06-15',
  'sex': 'MALE',
  'weight': 12.5,
  'breed': 'GOLDEN_RETRIEVER',
};

/// Crée une [LivingApi] branchée sur le faux serveur.
(LivingApi, FakeAdapter) apiWith(
  ResponseBody Function(RequestOptions request) handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return (LivingApi(dio: dio), adapter);
}

void main() {
  group('lecture', () {
    test('findAll : GET /api/living, lit "livings"', () async {
      final (api, server) = apiWith(
        (_) => jsonResponse({
          'livings': [
            {'id': 1, 'name': 'Warm Waffle', 'type': 'DOG'},
            {'id': 2, 'name': 'Albert', 'type': 'PLANT'},
          ],
        }),
      );

      final livings = await api.findAll();

      expect(server.requests.single.method, 'GET');
      expect(server.requests.single.path, '/api/living');
      expect(livings.map((l) => l.name), ['Warm Waffle', 'Albert']);
      expect(livings[1].isPlant, isTrue);
    });

    test('findAll : erreur propagée (l\'écran affiche "Réessayer")', () {
      final (api, _) = apiWith((_) => problem(500, 'boom'));
      expect(api.findAll(), throwsA(isA<DioException>()));
    });

    test('findById : GET /api/living/{id}, lit "living"', () async {
      final (api, server) = apiWith((_) => jsonResponse({'living': dogJson}));

      final detail = await api.findById(1);

      expect(server.requests.single.path, '/api/living/1');
      expect(detail.name, 'Warm Waffle');
      expect(detail.breed, 'GOLDEN_RETRIEVER');
    });
  });

  group('update', () {
    test('PUT /api/living/{id} avec le JSON de la requête', () async {
      final (api, server) = apiWith(
        (_) => jsonResponse({
          'living': {...dogJson, 'name': 'Buddy'},
        }),
      );

      final updated = await api.update(
        1,
        const UpdateDogRequest(name: 'Buddy', breed: 'GOLDEN_RETRIEVER'),
      );

      final req = server.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/living/1');
      expect(req.data, containsPair('type', 'DOG'));
      expect(req.data, containsPair('name', 'Buddy'));
      expect(updated.name, 'Buddy');
    });
  });

  group('erreurs -> ApiException avec un message affichable', () {
    Future<ApiException> errorFor(ResponseBody response) async {
      final (api, _) = apiWith((_) => response);
      try {
        await api.update(1, const UpdateDogRequest(name: 'x'));
        fail('une ApiException était attendue');
      } on ApiException catch (e) {
        return e;
      }
    }

    test('ProblemDetail : on affiche le "detail" du back', () async {
      final e = await errorFor(problem(400, 'Living 1 is a DOG'));
      expect(e.message, 'Living 1 is a DOG');
      expect(e.statusCode, 400);
    });

    test('sans "detail" : message selon le code HTTP', () async {
      expect(
        (await errorFor(jsonResponse({}, 400))).message,
        'Some fields are invalid.',
      );
      expect(
        (await errorFor(jsonResponse({}, 404))).message,
        'This pet no longer exists.',
      );
      expect(
        (await errorFor(jsonResponse({}, 413))).message,
        'Image too large (max 10 MB).',
      );
      expect(
        (await errorFor(jsonResponse({}, 503))).message,
        'Server error (503).',
      );
    });

    test('serveur injoignable', () async {
      final (api, _) = apiWith(
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'Connection refused',
        ),
      );
      await expectLater(
        api.update(1, const UpdateDogRequest(name: 'x')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Server unreachable. Check your connection.',
          ),
        ),
      );
    });
  });

  group('photos', () {
    final bytes = [0xFF, 0xD8, 0xFF, 0xE0];

    test('uploadPhoto : POST multipart, champ "file"', () async {
      final (api, server) = apiWith(
        (_) => jsonResponse({
          'id': 'p-1',
          'url': '/api/photos/p-1/content',
        }, 201),
      );

      final photo = await api.uploadPhoto(3, bytes: bytes, filename: 'dog.jpg');

      final req = server.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/living/3/photos');
      final form = req.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'dog.jpg');
      expect(form.files.single.value.length, bytes.length);
      expect(photo.id, 'p-1');
    });

    test('setPhoto : PUT /avatar ou /cover avec photoId', () async {
      final (api, server) = apiWith((_) => jsonResponse({'living': dogJson}));

      await api.setPhoto(3, PhotoSlot.cover, 'p-1');

      final req = server.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/living/3/cover');
      expect(req.data, {'photoId': 'p-1'});
    });

    test('changePhoto : upload PUIS set avec l\'id reçu', () async {
      final (api, server) = apiWith(
        (request) => request.method == 'POST'
            ? jsonResponse({'id': 'p-42'}, 201)
            : jsonResponse({
                'living': {...dogJson, 'avatarUrl': '/api/photos/p-42/content'},
              }),
      );

      final updated = await api.changePhoto(
        1,
        PhotoSlot.avatar,
        bytes: bytes,
        filename: 'dog.jpg',
      );

      expect(server.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/living/1/photos',
        'PUT /api/living/1/avatar',
      ]);
      expect(server.requests.last.data, {'photoId': 'p-42'});
      expect(updated.avatarUrl, '/api/photos/p-42/content');
    });

    test('changePhoto : upload refusé -> pas de set, message du back', () async {
      final (api, server) = apiWith(
        (_) => problem(400, 'Only JPEG, PNG or WEBP images are accepted'),
      );

      await expectLater(
        api.changePhoto(
          1,
          PhotoSlot.avatar,
          bytes: bytes,
          filename: 'a.txt',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Only JPEG, PNG or WEBP images are accepted',
          ),
        ),
      );
      expect(server.requests, hasLength(1)); // le PUT n'est jamais parti
    });
  });
}
