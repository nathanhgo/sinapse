import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmptyGotrueAsyncStorage extends GotrueAsyncStorage {
  const EmptyGotrueAsyncStorage();

  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> removeItem({required String key}) async {}

  @override
  Future<void> setItem({required String key, required String value}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase Mock POC', () {
    test('Can initialize Supabase with MockClient', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/auth/v1/')) {
          return http.Response(
            jsonEncode({
              'access_token': 'mock-token',
              'user': {
                'id': 'mock-id',
                'email': 'test@example.com',
              }
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });

      // Se já estiver inicializado de outra execução de testes, ignoramos o erro
      try {
        await Supabase.initialize(
          url: 'https://mock-proj.supabase.co',
          anonKey: 'mock-anon-key',
          httpClient: mockHttpClient,
          authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            pkceAsyncStorage: EmptyGotrueAsyncStorage(),
          ),
        );
      } catch (e) {
        // Ignora "Supabase has already been initialized."
        print('Supabase já inicializado: $e');
      }

      final client = Supabase.instance.client;
      expect(client, isNotNull);

      // Executa uma query que passa pelo nosso MockClient
      final response = await client.from('profiles').select();
      expect(response, isEmpty); // O MockClient retorna '[]'
    });
  });
}


