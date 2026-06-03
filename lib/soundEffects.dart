import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundEffects {
  // Cache para evitar recriar os bytes do mesmo tom
  static final Map<double, Uint8List> _wavCache = {};

  // Frequências para as 8 cores do Genius
  static const List<double> geniusPitches = [
    329.63, // 0: Verde (E4)
    261.63, // 1: Vermelho (C4)
    220.00, // 2: Amarelo (A3)
    196.00, // 3: Ciano (G3)
    440.00, // 4: Roxo (A4)
    392.00, // 5: Laranja (G4)
    349.23, // 6: Rosa (F4)
    293.66, // 7: Índigo (D4)
  ];

  /// Toca uma frequência específica de tom por uma duração em segundos
  static Future<void> playTone(double frequency, double durationSeconds, {double volume = 0.3}) async {
    try {
      Uint8List? wavBytes = _wavCache[frequency];
      if (wavBytes == null) {
        wavBytes = _generateWav(frequency, durationSeconds, volume: volume);
        _wavCache[frequency] = wavBytes;
      }
      
      final tempPlayer = AudioPlayer();
      await tempPlayer.play(BytesSource(wavBytes));
      
      // Auto-dispensa do player temporário para liberar recursos após tocar
      Future.delayed(Duration(milliseconds: (durationSeconds * 1000 + 400).toInt()), () {
        tempPlayer.dispose();
      });
    } catch (e) {
      // Ignora falhas silenciosamente
    }
  }

  /// Toca um tom do Genius com base no índice da cor
  static Future<void> playGeniusTone(int colorIndex) async {
    if (colorIndex >= 0 && colorIndex < geniusPitches.length) {
      await playTone(geniusPitches[colorIndex], 0.25);
    }
  }

  // Cache para os sons especiais
  static Uint8List? _keyboardClickBytes;
  static Uint8List? _cardFlipBytes;

  /// Toca o som de clique de digitação sintetizado em memória (teclado mecânico)
  static Future<void> playKeyboardClick() async {
    try {
      _keyboardClickBytes ??= _generateKeyboardClickWav();
      final tempPlayer = AudioPlayer();
      await tempPlayer.play(BytesSource(_keyboardClickBytes!));
      Future.delayed(const Duration(milliseconds: 400), () {
        tempPlayer.dispose();
      });
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Toca o som de vuush (papel virando) sintetizado em memória para o Jogo da Memória
  static Future<void> playCardFlip() async {
    try {
      _cardFlipBytes ??= _generateCardFlipWav();
      final tempPlayer = AudioPlayer();
      await tempPlayer.play(BytesSource(_cardFlipBytes!));
      Future.delayed(const Duration(milliseconds: 500), () {
        tempPlayer.dispose();
      });
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Mantemos playClick para compatibilidade
  static void playClick() {
    playKeyboardClick();
  }
}

/// Gera um som de clique de teclado mecânico (ruído com decaimento rápido + grave curto)
Uint8List _generateKeyboardClickWav() {
  const int sampleRate = 22050;
  const double durationSeconds = 0.04;
  final int numSamples = (sampleRate * durationSeconds).toInt();
  final int dataSize = numSamples * 2;
  final int fileSize = 44 + dataSize;

  final Uint8List wavBytes = Uint8List(fileSize);
  final ByteData byteData = ByteData.sublistView(wavBytes);

  wavBytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  byteData.setUint32(4, fileSize - 8, Endian.little);
  wavBytes.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]);

  wavBytes.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]);
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, 1, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);

  wavBytes.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]);
  byteData.setUint32(40, dataSize, Endian.little);

  final math.Random random = math.Random();
  double phase = 0.0;
  const double volume = 0.12;

  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double env = math.exp(-120.0 * t); // Decaimento muito rápido
    
    // Frequência grave de fundo (thud)
    phase += 2.0 * math.pi * 120.0 / sampleRate;
    final double lowPart = math.sin(phase) * 0.35;
    
    // Ruído branco (estalido da tecla)
    final double noisePart = (random.nextDouble() * 2.0 - 1.0) * 0.65;
    
    final double sample = (lowPart + noisePart) * env * volume;
    final int intSample = (sample * 32767.0).clamp(-32768.0, 32767.0).toInt();
    byteData.setInt16(44 + i * 2, intSample, Endian.little);
  }

  return wavBytes;
}

/// Gera um som de vuush / papel virando (varredura de frequência crescente + ruído de vento)
Uint8List _generateCardFlipWav() {
  const int sampleRate = 22050;
  const double durationSeconds = 0.16;
  final int numSamples = (sampleRate * durationSeconds).toInt();
  final int dataSize = numSamples * 2;
  final int fileSize = 44 + dataSize;

  final Uint8List wavBytes = Uint8List(fileSize);
  final ByteData byteData = ByteData.sublistView(wavBytes);

  wavBytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  byteData.setUint32(4, fileSize - 8, Endian.little);
  wavBytes.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]);

  wavBytes.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]);
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, 1, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);

  wavBytes.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]);
  byteData.setUint32(40, dataSize, Endian.little);

  final math.Random random = math.Random();
  double phase = 0.0;
  const double volume = 0.22;

  for (int i = 0; i < numSamples; i++) {
    // Varredura de frequência de 140Hz até 320Hz para dar o efeito de movimento
    final double freq = 140.0 + 180.0 * (i / numSamples);
    phase += 2.0 * math.pi * freq / sampleRate;
    
    // Envelope em sino (suave no início e no fim)
    final double env = math.sin(math.pi * i / numSamples);
    
    // Varredura + ruído simulando o vento do papel virando
    final double lowPart = math.sin(phase) * 0.55;
    final double noisePart = (random.nextDouble() * 2.0 - 1.0) * 0.45;
    
    final double sample = (lowPart + noisePart) * env * volume;
    final int intSample = (sample * 32767.0).clamp(-32768.0, 32767.0).toInt();
    byteData.setInt16(44 + i * 2, intSample, Endian.little);
  }

  return wavBytes;
}

/// Gera um array de bytes no formato WAV contendo uma onda senoidal da frequência especificada.
Uint8List _generateWav(double frequency, double durationSeconds, {double volume = 0.3}) {
  const int sampleRate = 22050;
  final int numSamples = (sampleRate * durationSeconds).toInt();
  final int dataSize = numSamples * 2;
  final int fileSize = 44 + dataSize;

  final Uint8List wavBytes = Uint8List(fileSize);
  final ByteData byteData = ByteData.sublistView(wavBytes);

  // RIFF Chunk Descriptor
  wavBytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // "RIFF"
  byteData.setUint32(4, fileSize - 8, Endian.little);
  wavBytes.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // "WAVE"

  // "fmt " sub-chunk
  wavBytes.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]); // "fmt "
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // Linear PCM
  byteData.setUint16(22, 1, Endian.little); // 1 canal (Mono)
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate (sampleRate * blockAlign)
  byteData.setUint16(32, 2, Endian.little); // Block align (1 canal * 16 bits / 8)
  byteData.setUint16(34, 16, Endian.little); // 16 bits por amostra

  // "data" sub-chunk
  wavBytes.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // "data"
  byteData.setUint32(40, dataSize, Endian.little);

  // Geração das amostras senoidais
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double angle = 2.0 * math.pi * frequency * t;
    final double sample = math.sin(angle) * volume;
    final int intSample = (sample * 32767.0).clamp(-32768.0, 32767.0).toInt();
    byteData.setInt16(44 + i * 2, intSample, Endian.little);
  }

  return wavBytes;
}
