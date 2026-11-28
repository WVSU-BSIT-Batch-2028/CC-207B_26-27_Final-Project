import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/services/auth_service.dart';

void main() {
  group('FirebaseAuthRestService', () {
    test(
      'signs in user against emulator endpoint and parses AuthUser',
      () async {
        String? requestedUrl;
        String? requestBody;

        final client = MockClient((request) async {
          requestedUrl = request.url.toString();
          requestBody = request.body;

          final responseJson = {
            'localId': 'user-123',
            'email': 'littlesteps@demo.com',
            'idToken': 'mock-id-token',
            'refreshToken': 'mock-refresh-token',
            'expiresIn': '3600',
          };
          return http.Response(jsonEncode(responseJson), 200);
        });

        final authService = FirebaseAuthRestService(
          emulatorHost: '10.0.2.2',
          emulatorPort: 9099,
          httpClient: client,
        );

        final user = await authService.signInWithEmailAndPassword(
          email: 'littlesteps@demo.com',
          password: 'password123',
        );

        expect(
          requestedUrl,
          contains(
            'http://10.0.2.2:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
          ),
        );
        expect(jsonDecode(requestBody!), {
          'email': 'littlesteps@demo.com',
          'password': 'password123',
          'returnSecureToken': true,
        });

        expect(user.id, 'user-123');
        expect(user.email, 'littlesteps@demo.com');
        expect(user.idToken, 'mock-id-token');
        expect(user.refreshToken, 'mock-refresh-token');
        expect(user.isExpired, isFalse);
      },
    );

    test(
      'maps invalid credential error to calm user-friendly error message',
      () async {
        final client = MockClient((request) async {
          final errorJson = {
            'error': {'code': 400, 'message': 'INVALID_LOGIN_CREDENTIALS'},
          };
          return http.Response(jsonEncode(errorJson), 400);
        });

        final authService = FirebaseAuthRestService(
          emulatorHost: 'localhost',
          httpClient: client,
        );

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'wrong@example.com',
            password: 'badpassword',
          ),
          throwsA(
            isA<AuthException>()
                .having((e) => e.code, 'code', 'auth/invalid-credential')
                .having(
                  (e) => e.message,
                  'message',
                  "That email and password don't match an account. Please check them and try again.",
                ),
          ),
        );
      },
    );

    test('refreshes ID token via securetoken endpoint', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          contains('http://localhost:9099/securetoken.googleapis.com/v1/token'),
        );
        expect(request.bodyFields['grant_type'], 'refresh_token');
        expect(request.bodyFields['refresh_token'], 'valid-refresh-token');

        final responseJson = {
          'user_id': 'user-123',
          'id_token': 'new-fresh-id-token',
          'refresh_token': 'renewed-refresh-token',
          'expires_in': '3600',
        };
        return http.Response(jsonEncode(responseJson), 200);
      });

      final authService = FirebaseAuthRestService(
        emulatorHost: 'localhost',
        httpClient: client,
      );

      final refreshed = await authService.refreshToken('valid-refresh-token');
      expect(refreshed.idToken, 'new-fresh-id-token');
      expect(refreshed.refreshToken, 'renewed-refresh-token');
    });

    test('signs up new caregiver with email and password', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), contains('accounts:signUp'));
        return http.Response(
          jsonEncode({
            'localId': 'new-user-456',
            'email': 'newcaregiver@example.com',
            'idToken': 'new-token',
            'refreshToken': 'new-refresh',
            'expiresIn': '3600',
          }),
          200,
        );
      });

      final authService = FirebaseAuthRestService(
        emulatorHost: 'localhost',
        httpClient: client,
      );

      final user = await authService.signUpWithEmailAndPassword(
        email: 'newcaregiver@example.com',
        password: 'securepassword123',
      );

      expect(user.id, 'new-user-456');
      expect(user.email, 'newcaregiver@example.com');
    });
  });
}
