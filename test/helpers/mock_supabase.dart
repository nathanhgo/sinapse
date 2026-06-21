import 'dart:convert';
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

/// Inicializa o Supabase com um MockClient HTTP que retorna respostas customizadas.
/// Limpa a instância anterior automaticamente se ela já estiver configurada.
Future<void> initializeMockSupabase({
  Map<String, dynamic>? authResponse,
  String queryResponseJson = '[]',
  Future<http.Response> Function(http.Request request)? customHandler,
}) async {
  final mockHttpClient = MockClient((request) async {
    if (customHandler != null) {
      return await customHandler(request);
    }

    if (request.url.path.contains('/auth/v1/')) {
      final defaultAuth = authResponse ?? {
        'access_token': 'mock-token',
        'user': {
          'id': 'mock-id-12345',
          'email': 'mock_user@example.com',
          'user_metadata': {
            'name': 'Mock User',
            'avatar_url': 'https://lh3.googleusercontent.com/mock-avatar.png'
          }
        }
      };
      return http.Response(
        jsonEncode(defaultAuth),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }

    // Retorno padrão para requisições de banco de dados
    return http.Response(
      queryResponseJson,
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  });

  // Se já estiver inicializado, limpa a instância anterior para aplicar o novo mock
  try {
    final instance = Supabase.instance;
    if (instance.isInitialized) {
      await instance.dispose();
    }
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://mock-project-id.supabase.co',
    anonKey: 'mock-anon-key',
    httpClient: mockHttpClient,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      pkceAsyncStorage: EmptyGotrueAsyncStorage(),
    ),
  );
}
