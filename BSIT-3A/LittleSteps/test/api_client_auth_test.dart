import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/services/api_client.dart';

void main() {
  group('ApiClient Authentication & Token Interceptor', () {
    test('attaches Bearer token to protected API requests', () async {
      final headersSeen = <String, String>{};

      final client = MockClient((request) async {
        headersSeen.addAll(request.headers);
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test-api',
        httpClient: client,
      );
      apiClient.setAuthToken('valid-auth-token-123');

      await apiClient.get('/api/v1/children');

      expect(headersSeen['Authorization'], 'Bearer valid-auth-token-123');
      expect(headersSeen['Accept'], 'application/json');
    });

    test('retries request once upon 401 if refresh succeeds', () async {
      int requestCount = 0;
      int refreshCount = 0;
      final tokensUsed = <String?>[];

      final client = MockClient((request) async {
        requestCount++;
        tokensUsed.add(request.headers['Authorization']);
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'},
            }),
            401,
          );
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test-api',
        httpClient: client,
        onRefreshToken: () async {
          refreshCount++;
          return 'freshly-minted-token-456';
        },
      );
      apiClient.setAuthToken('initial-expired-token');

      final result =
          await apiClient.get('/api/v1/children') as Map<String, dynamic>;

      expect(requestCount, 2);
      expect(refreshCount, 1);
      expect(tokensUsed[0], 'Bearer initial-expired-token');
      expect(tokensUsed[1], 'Bearer freshly-minted-token-456');
      expect(result['status'], 'success');
      expect(apiClient.authToken, 'freshly-minted-token-456');
    });

    test(
      'calls onSessionExpired and throws ApiException when 401 retry fails',
      () async {
        int requestCount = 0;
        bool sessionExpiredCalled = false;

        final client = MockClient((request) async {
          requestCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'Session expired',
              },
            }),
            401,
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'http://test-api',
          httpClient: client,
          onRefreshToken: () async => 'second-bad-token',
          onSessionExpired: () {
            sessionExpiredCalled = true;
          },
        );
        apiClient.setAuthToken('first-bad-token');

        await expectLater(
          () => apiClient.get('/api/v1/children'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.code, 'code', 'UNAUTHENTICATED'),
          ),
        );

        // Verify that after the retry failure, onSessionExpired was called
        expect(sessionExpiredCalled, isTrue);
        expect(requestCount, 2);
      },
    );

    test(
      'isProtectedPath correctly distinguishes protected from public endpoints',
      () {
        expect(ApiClient.isProtectedPath('/api/v1/children'), isTrue);
        expect(ApiClient.isProtectedPath('/api/v1/children/c1/plans'), isTrue);
        expect(
          ApiClient.isProtectedPath('/api/v1/children/c1/milestones'),
          isTrue,
        );
        expect(
          ApiClient.isProtectedPath('/api/v1/children/c1/journal'),
          isTrue,
        );
        expect(ApiClient.isProtectedPath('/api/v1/catalog/books'), isFalse);
        expect(
          ApiClient.isProtectedPath('/api/v1/catalog/books/search'),
          isFalse,
        );

        expect(
          ApiClient.isProtectedPath('/api/v1/catalog/activities'),
          isFalse,
        );
        expect(ApiClient.isProtectedPath('/api/v1/catalog/weather'), isFalse);
        expect(ApiClient.isProtectedPath('/health'), isFalse);
      },
    );
  });
}
