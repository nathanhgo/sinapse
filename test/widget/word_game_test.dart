import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/wordGamePage.dart';
import '../helpers/mock_supabase.dart';

void main() {
  setUpAll(() async {
    // Inicializa o mock do Supabase com dados simulados de perfil e ofensiva
    await initializeMockSupabase(
      queryResponseJson: '{"streak": 5, "last_play_date": "2026-06-20", "best_score_word": 3}',
    );
  });

  group('WordGamePage Widget Tests', () {
    testWidgets('renders game grid and virtual keyboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WordGamePage(difficulty: 'fácil'),
        ),
      );

      // Permite que os futuros e timers do initState completem
      await tester.pumpAndSettle();

      // Verifica se a tela do Wordle foi renderizada
      expect(find.byType(WordGamePage), findsOneWidget);
      
      // Verifica se o teclado virtual possui as teclas ENTER e DEL
      expect(find.text('ENTER'), findsOneWidget);
      expect(find.text('DEL'), findsOneWidget);
    });
  });
}
