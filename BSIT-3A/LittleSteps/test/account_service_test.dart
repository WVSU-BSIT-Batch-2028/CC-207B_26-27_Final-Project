import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/services/account_service.dart';
import 'package:littlesteps/services/api_client.dart';

void main() {
  test(
    'AccountService exports and deletes through account API routes',
    () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer synthetic-token');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'profile': {'email': 'test@example.com'},
            }),
            200,
          );
        }
        return http.Response('', 204);
      });
      final apiClient = ApiClient(
        baseUrl: 'http://local.test',
        httpClient: client,
      )..setAuthToken('synthetic-token');
      final service = AccountService(apiClient: apiClient);

      final data = await service.exportData();
      await service.deleteAccount();

      expect(data['profile'], {'email': 'test@example.com'});
      expect(calls, ['GET /api/v1/me/export', 'DELETE /api/v1/me']);
    },
  );
}
