import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class BackgroundMusic with WidgetsBindingObserver {
  static final BackgroundMusic _instance = BackgroundMusic._internal();
  factory BackgroundMusic() => _instance;
  BackgroundMusic._internal();

  final AudioPlayer _player = AudioPlayer();
  double _volume = 0.5; // Volume inicial: 50%
  bool _isMuted = true; // Começa mutada por padrão
  bool _isPlaying = false;
  bool _wasPlayingBeforePause = false; // Controla pausa ao bloquear/minimizar

  double get volume => _volume;
  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    _player.setReleaseMode(ReleaseMode.loop);

    // Configura o contexto de áudio global para permitir a mixagem paralela sem interrupções
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // Não pega foco exclusivo
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));
    } catch (e) {
      debugPrint('Erro ao configurar contexto global de áudio: $e');
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isPlaying && _player.state == PlayerState.playing) {
        _wasPlayingBeforePause = true;
        _player.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _wasPlayingBeforePause = false;
        _player.resume();
      }
    }
  }

  Future<void> play() async {
    if (_player.state == PlayerState.playing) return;
    try {
      // Carrega e reproduz o arquivo configurado nos assets
      await _player.play(AssetSource('background_music.mp3'));
      await _player.setVolume(_isMuted ? 0 : _volume);
      _isPlaying = true;
    } catch (e) {
      debugPrint('Erro ao reproduzir música de fundo: $e');
    }
  }

  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    if (!_isMuted) {
      await _player.setVolume(_volume);
    }
    // Se o volume for maior que zero e o player não estiver tocando, tenta reproduzir
    if (_volume > 0.0 && _player.state != PlayerState.playing && !_isMuted) {
      await play();
    }
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _player.setVolume(_isMuted ? 0 : _volume);
    // Se desmutar e não estiver tocando, garante a reprodução
    if (!_isMuted && _volume > 0.0 && _player.state != PlayerState.playing) {
      await play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }
}
