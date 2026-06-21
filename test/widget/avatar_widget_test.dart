import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/avatarWidget.dart';

void main() {
  group('AvatarWidget Widget Tests', () {
    testWidgets('renders local icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              avatarKey: 'rocket',
              size: 100,
            ),
          ),
        ),
      );

      // Verifica se o AvatarWidget foi construído
      expect(find.byType(AvatarWidget), findsOneWidget);
      
      // Deve renderizar um widget do tipo Icon
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders network URL and falls back to person icon in test environment', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              avatarKey: 'https://lh3.googleusercontent.com/a/ACg8ocL',
              size: 100,
            ),
          ),
        ),
      );

      // Aguarda as frames do errorBuilder da rede no ambiente de teste
      await tester.pumpAndSettle();

      // Como o carregamento de rede lança exceção por padrão no ambiente de teste headless do Flutter,
      // ele deve acionar o errorBuilder e renderizar o ícone de pessoa.
      expect(find.byType(AvatarWidget), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });
  });
}
