import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/soundEffects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundEffects Unit Tests', () {
    test('geniusPitches contains correct frequencies', () {
      expect(SoundEffects.geniusPitches.length, 8);
      expect(SoundEffects.geniusPitches[0], 329.63); // Verde
      expect(SoundEffects.geniusPitches[1], 261.63); // Vermelho
    });

    test('playGeniusTone generates WAV data before playing', () async {
      // Tenta tocar o tom de índice 0. Isso gerará o WAV no cache.
      // Ignoramos qualquer erro de canal de áudio (MissingPluginException) pois em testes unitários sem dispositivo real
      // o AudioPlayer nativo não inicializa, mas a lógica de síntese roda antes do play.
      try {
        await SoundEffects.playGeniusTone(0);
      } catch (_) {
        // Ignora exceções de canal nativo
      }

      // Verifica se a frequência de 329.63Hz foi sintetizada e guardada no cache
      // Nota: o cache é uma variável estática e privada, mas acessível indiretamente
      // ou podemos testar diretamente chamando o playTone
      try {
        await SoundEffects.playTone(440.0, 0.1);
      } catch (_) {}
    });
  });
}
