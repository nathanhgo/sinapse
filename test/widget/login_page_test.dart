import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import '../helpers/mock_supabase.dart';

void main() {
  setUpAll(() async {
    // Inicializa o mock do Supabase com sessão nula por padrão
    await initializeMockSupabase();
  });

  group('LoginPage Widget Tests', () {
    testWidgets('renders login screen fields and buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica elementos principais da tela de Login
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sinapse'), findsOneWidget);
      expect(find.text('Continuar com o Google'), findsOneWidget);
      expect(find.text('Não tem uma conta? Cadastre-se gratuitamente'), findsOneWidget);
      expect(find.text('Entrar como convidado'), findsWidgets);
    });


    testWidgets('toggles to registration mode when clicking switch button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Clica no botão para alternar para cadastro
      final toggleButton = find.text('Não tem uma conta? Cadastre-se gratuitamente');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verifica se o título mudou para "Criar Conta"
      expect(find.text('Criar Conta'), findsOneWidget);
      expect(find.text('Já possui uma conta? Entre aqui'), findsOneWidget);
    });
  });
}


