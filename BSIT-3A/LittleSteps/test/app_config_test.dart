import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:littlesteps/config/app_config.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';

void main() {
  group('AppConfig and environment routing', () {
    test('defaults to local Firebase emulator mode when unset', () {
      expect(AppConfig.useFirebaseEmulator, isTrue);
      expect(
        ApiClient.defaultBaseUrl(host: 'localhost'),
        'http://localhost:5001/demo-littlesteps/asia-southeast1/api',
      );
    });

    test(
      'FirebaseAuthRestService targets local emulator when enabled',
      () async {
        Uri? capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'localId': 'u-1',
              'email': 'caregiver@example.com',
              'idToken': 'token-123',
              'refreshToken': 'refresh-123',
              'expiresIn': '3600',
            }),
            200,
          );
        });

        final auth = FirebaseAuthRestService(
          useEmulator: true,
          emulatorHost: 'localhost',
          emulatorPort: 9099,
          apiKey: 'demo-key',
          httpClient: client,
        );
        await auth.signInWithEmailAndPassword(
          email: 'caregiver@example.com',
          password: 'Password123!',
        );

        expect(capturedUri, isNotNull);
        expect(capturedUri!.scheme, 'http');
        expect(capturedUri!.host, 'localhost');
        expect(capturedUri!.port, 9099);
        expect(
          capturedUri!.path,
          '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
        );
      },
    );

    test('FirebaseAuthRestService targets HTTPS Google endpoints in production mode', () async {
      final capturedUris = <Uri>[];
      final client = MockClient((request) async {
        capturedUris.add(request.url);
        if (request.url.host == 'securetoken.googleapis.com') {
          return http.Response(
            jsonEncode({
              'user_id': 'u-1',
              'id_token': 'token-456',
              'refresh_token': 'refresh-456',
              'expires_in': '3600',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'localId': 'u-1',
            'email': 'caregiver@example.com',
            'idToken': 'token-123',
            'refreshToken': 'refresh-123',
            'expiresIn': '3600',
          }),
          200,
        );
      });

      final auth = FirebaseAuthRestService(
        useEmulator: false,
        apiKey: 'prod-web-key',
        httpClient: client,
      );
      await auth.signInWithEmailAndPassword(
        email: 'caregiver@example.com',
        password: 'Password123!',
      );
      await auth.refreshToken('refresh-123');

      expect(capturedUris, hasLength(2));
      expect(
        capturedUris[0].toString(),
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=prod-web-key',
      );
      expect(
        capturedUris[1].toString(),
        'https://securetoken.googleapis.com/v1/token?key=prod-web-key',
      );
    });
  });
}
