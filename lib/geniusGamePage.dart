import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'soundEffects.dart';

class GeniusGamePage extends StatefulWidget {
  final String difficulty;

  const GeniusGamePage({super.key, this.difficulty = 'difícil'});

  @override
  State<GeniusGamePage> createState() => _GeniusGamePageState();
}

class _GeniusGamePageState extends State<GeniusGamePage> {
  // Estado do Perfil e Recordes
  int? _recorde;
  bool _isCasual = false;
  int _streak = 0;
  String? _lastPlayDate;
  bool _isGuest = true;

  // Estado do Genius
  final List<int> _sequence = [];
  final List<int> _userSequence = [];
  int _round = 1;
  bool _isShowingSequence = false;
  int _activeColorIndex = -1;
  final math.Random _random = math.Random();

  // Estado da Contagem Regressiva
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Temporizadores de animação de toque do usuário
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _loadProfileAndRecord();
    _iniciarCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // Carrega informações do perfil e o recorde atual do usuário
  Future<void> _loadProfileAndRecord() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isGuest = true;
      });
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('best_score_genius, is_casual, streak, last_play_date')
          .eq('id', user.id)
          .single();

      setState(() {
        _recorde = data['best_score_genius'] as int?;
        _isCasual = data['is_casual'] as bool? ?? false;
        _streak = data['streak'] as int? ?? 0;
        _lastPlayDate = data['last_play_date'] as String?;
        _isGuest = false;
      });
    } catch (e) {
      debugPrint('Aviso: Coluna best_score_genius pode não existir ainda no banco. Buscando perfil simplificado: $e');
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('is_casual, streak, last_play_date')
            .eq('id', user.id)
            .single();

        setState(() {
          _isCasual = data['is_casual'] as bool? ?? false;
          _streak = data['streak'] as int? ?? 0;
          _lastPlayDate = data['last_play_date'] as String?;
          _isGuest = false;
        });
      } catch (ex) {
        debugPrint('Erro ao obter perfil no Genius: $ex');
        setState(() {
          _isGuest = false;
        });
      }
    }
  }

  // Inicia a contagem regressiva de 3 segundos
  void _iniciarCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else if (_countdownValue == 1) {
          _countdownValue = 0; // Exibe "JÁ!"
        } else {
          _countdownTimer?.cancel();
          _isCountingDown = false;
          _iniciarJogo();
        }
      });
    });
  }

  int get _numPads {
    if (widget.difficulty == 'fácil') return 4;
    if (widget.difficulty == 'médio') return 6;
    return 8;
  }

  // Inicia a sequência de jogo
  void _iniciarJogo() {
    _sequence.clear();
    _userSequence.clear();
    _round = 1;

    // Define o tamanho inicial da sequência com base na dificuldade
    int initialSize = 1;
    if (widget.difficulty == 'médio') {
      initialSize = 2;
    } else if (widget.difficulty == 'difícil') {
      initialSize = 3;
    }

    for (int i = 0; i < initialSize; i++) {
      _sequence.add(_random.nextInt(_numPads));
    }

    _mostrarSequencia();
  }

  // Mostra a sequência piscando os pads de cores
  Future<void> _mostrarSequencia() async {
    if (!mounted) return;
    setState(() {
      _isShowingSequence = true;
      _activeColorIndex = -1;
      _userSequence.clear();
    });

    await Future.delayed(const Duration(milliseconds: 600));

    // Determina a velocidade com base no tamanho da sequência para não ficar entediante
    int flashDuration = 450;
    int pauseDuration = 200;

    if (_sequence.length > 8) {
      flashDuration = 350;
      pauseDuration = 150;
    }
    if (_sequence.length > 15) {
      flashDuration = 250;
      pauseDuration = 100;
    }

    for (int color in _sequence) {
      if (!mounted) return;
      SoundEffects.playGeniusTone(color);
      setState(() {
        _activeColorIndex = color;
      });

      await Future.delayed(Duration(milliseconds: flashDuration));

      if (!mounted) return;
      setState(() {
        _activeColorIndex = -1;
      });

      await Future.delayed(Duration(milliseconds: pauseDuration));
    }

    if (!mounted) return;
    setState(() {
      _isShowingSequence = false;
    });
  }

  // Lógica de toque do jogador em uma cor
  void _onPadTap(int colorIndex) {
    if (_isCountingDown || _isShowingSequence) return;

    // Pisca a cor tocada brevemente
    _flashTimer?.cancel();
    SoundEffects.playGeniusTone(colorIndex);
    setState(() {
      _activeColorIndex = colorIndex;
    });
    _flashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _activeColorIndex = -1;
        });
      }
    });

    _userSequence.add(colorIndex);

    // Valida o toque contra a sequência correspondente
    if (colorIndex != _sequence[_userSequence.length - 1]) {
      // Errou! Fim de jogo
      _gameOver();
      return;
    }

    // Se acertou a sequência inteira, avança de rodada
    if (_userSequence.length == _sequence.length) {
      _avancarRodada();
    }
  }

  // Avança para a próxima rodada
  void _avancarRodada() {
    setState(() {
      _round++;
    });

    // Quantidade de cores adicionadas por vez depende da dificuldade
    int addCount = 1;
    if (widget.difficulty == 'médio') {
      addCount = 2;
    } else if (widget.difficulty == 'difícil') {
      addCount = 3;
    }

    for (int i = 0; i < addCount; i++) {
      _sequence.add(_random.nextInt(_numPads));
    }

    // Espera um momento antes de piscar a nova sequência
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _mostrarSequencia();
      }
    });
  }

  // Lógica de Fim de Jogo
  void _gameOver() {
    // A pontuação é o número de rodadas concluídas com sucesso (round atual - 1)
    final score = _round - 1;
    bool recordeBatido = false;

    if (_recorde == null || score > _recorde!) {
      recordeBatido = true;
      setState(() {
        _recorde = score;
      });
    }

    if (!_isGuest) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

        int? newStreak;
        if (_lastPlayDate == null) {
          newStreak = _streak + 1;
        } else if (_lastPlayDate == yesterdayStr) {
          newStreak = _streak + 1;
        } else if (_lastPlayDate != todayStr) {
          newStreak = 1;
        }

        if (newStreak != null) {
          setState(() {
            _streak = newStreak!;
            _lastPlayDate = todayStr;
          });
        }

        final updates = <String, dynamic>{};
        if (newStreak != null) {
          updates['streak'] = newStreak;
          updates['last_play_date'] = todayStr;
        }
        if (widget.difficulty == 'difícil' && recordeBatido) {
          updates['best_score_genius'] = score;
        }

        if (updates.isNotEmpty) {
          Supabase.instance.client
              .from('profiles')
              .update(updates)
              .eq('id', user.id)
              .then((_) => null)
              .catchError((e) {
                debugPrint('Erro ao salvar recorde/ofensiva do Genius no banco: $e');
              });
        }
        
        // Registra histórico de jogada
        Supabase.instance.client
            .from('play_history')
            .upsert({'user_id': user.id, 'play_date': todayStr})
            .then((_) => null)
            .catchError((e) {
              debugPrint('Erro ao registrar histórico no Genius: $e');
            });
      }
    }

    if (!mounted) return;

    // Mostra popup de derrota
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = isDarkModeNotifier.value;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(
            child: Text(
              'Fim de Jogo!',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.azulPrincipal,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sentiment_very_dissatisfied,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Você errou a sequência!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Rodadas Concluídas: $score',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.difficulty == 'difícil')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      recordeBatido ? 'Novo Recorde!' : 'Recorde: $_recorde rodadas',
                      style: TextStyle(
                        color: recordeBatido ? AppColors.rosaBotao : Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '(Recordes salvos apenas na dificuldade difícil)',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.azulPrincipal,
                side: BorderSide(color: isDark ? Colors.white30 : AppColors.azulPrincipal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context); // fecha dialog
                Navigator.pop(context); // volta para a home
              },
              child: const Text('Menu Inicial'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rosaBotao,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context); // fecha dialog
                setState(() {
                  _isCountingDown = true;
                  _countdownValue = 3;
                });
                _iniciarCountdown();
              },
              child: const Text('Jogar de Novo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    final azulPrincipal = AppColors.azulPrincipal;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final playedToday = _lastPlayDate == todayStr;

    return Scaffold(
      backgroundColor: azulPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Genius (${widget.difficulty.toUpperCase()})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (!_isCasual)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const StreakCalendarDialog(),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((255 * 0.15).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: playedToday ? Colors.deepOrange : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _streak.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background - Estrela Gigante Discreta
          Positioned.fill(
            child: CustomPaint(
              painter: StarPainter(isDark: isDark),
            ),
          ),

          // Área do Jogo
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const Spacer(),

                    // Se estiver contando, mostra contagem regressiva
                    if (_isCountingDown)
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: Text(
                            _countdownValue == 0 ? 'JÁ!' : '$_countdownValue',
                            key: ValueKey<int>(_countdownValue),
                            style: const TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Informações de rodada e recorde
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Rodada: $_round',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (widget.difficulty == 'difícil')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Recorde: ${_recorde ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Grid do Genius
                      AspectRatio(
                        aspectRatio: widget.difficulty == 'fácil'
                            ? 1.0
                            : widget.difficulty == 'médio'
                                ? 0.75
                                : 0.6,
                        child: Column(
                          children: [
                            // Linha 0 (Sempre visível)
                            Expanded(
                              child: Row(
                                children: [
                                  _buildPadItem(0, Colors.green.shade800, Colors.greenAccent.shade400),
                                  _buildPadItem(1, Colors.red.shade800, Colors.redAccent.shade400),
                                ],
                              ),
                            ),
                            // Linha 1 (Sempre visível)
                            Expanded(
                              child: Row(
                                children: [
                                  _buildPadItem(2, Colors.amber.shade800, Colors.yellowAccent.shade400),
                                  _buildPadItem(3, Colors.cyan.shade700, Colors.cyanAccent.shade200),
                                ],
                              ),
                            ),
                            // Linha 2 (Apenas no Médio e Difícil)
                            if (widget.difficulty == 'médio' || widget.difficulty == 'difícil')
                              Expanded(
                                child: Row(
                                  children: [
                                    _buildPadItem(4, Colors.purple.shade700, Colors.purpleAccent.shade200),
                                    _buildPadItem(5, Colors.orange.shade800, Colors.orangeAccent.shade200),
                                  ],
                                ),
                              ),
                            // Linha 3 (Apenas no Difícil)
                            if (widget.difficulty == 'difícil')
                              Expanded(
                                child: Row(
                                  children: [
                                    _buildPadItem(6, Colors.pink.shade700, Colors.pinkAccent.shade200),
                                    _buildPadItem(7, Colors.indigo.shade800, Colors.indigoAccent.shade200),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status do Jogo
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isShowingSequence
                              ? 'Observe a sequência...'
                              : 'Sua vez! Repita a sequência (${_userSequence.length}/${_sequence.length})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadItem(int index, Color color, Color activeColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GeniusPad(
          color: color,
          activeColor: activeColor,
          isActive: _activeColorIndex == index,
          onTap: () => _onPadTap(index),
        ),
      ),
    );
  }
}

class GeniusPad extends StatelessWidget {
  final Color color;
  final Color activeColor;
  final bool isActive;
  final VoidCallback onTap;

  const GeniusPad({
    super.key,
    required this.color,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    return AnimatedScale(
      scale: isActive ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? activeColor : (isDark ? color.withOpacity(0.4) : color.withOpacity(0.85)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ]
                : [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    )
                  ],
          ),
        ),
      ),
    );
  }
}

class StarPainter extends CustomPainter {
  final bool isDark;

  StarPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = isDark ? 0.02 : 0.05;
    final paint = Paint()
      ..color = Colors.white.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;

    final path = Path();
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width * 0.8;
    final double innerRadius = radius / 2.5;

    const double angle = -90 * (3.1415926535 / 180);
    const double step = 360 / 10 * (3.1415926535 / 180);

    for (int i = 0; i < 10; i++) {
      final r = i % 2 == 0 ? radius : innerRadius;
      final double currAngle = angle + i * step;
      final double x = centerX + r * math.cos(currAngle);
      final double y = centerY + r * math.sin(currAngle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
