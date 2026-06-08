import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'soundEffects.dart';

class MemoryGamePage extends StatefulWidget {
  final String difficulty;

  const MemoryGamePage({super.key, this.difficulty = 'difícil'});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  // Emojis para o tabuleiro (suporta até 18 pares = 36 cartas no modo 6x6)
  static const List<String> _baseEmojis = [
    '☀️', '🌙', '💡', '🏆', '🚀', '🧩', '⚡', '❤️',
    '🎨', '🎬', '🎯', '⚽', '🎒', '🐱', '🐶', '🦄',
    '🍉', '🍕', '🔑', '✈️', '🎮', '🚗', '🍿', '🌍'
  ];

  // Estado do Perfil e Recordes
  int? _recorde;
  bool _isCasual = false;
  int _streak = 0;
  String? _lastPlayDate;
  bool _isGuest = true;

  // Estado do Jogo da Memória
  List<MemoryCard> _cards = [];
  int _selectedCardIndex1 = -1;
  int _selectedCardIndex2 = -1;
  int _moves = 0;
  bool _isChecking = false;

  // Estado da Contagem Regressiva
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Estado da Memorização Inicial
  bool _isMemorizing = false;
  Timer? _memorizeTimer;

  @override
  void initState() {
    super.initState();
    _loadProfileAndRecord();
    _iniciarMemorizacao();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _memorizeTimer?.cancel();
    super.dispose();
  }

  // Carrega informações do perfil e o recorde atual do usuário (se estiver na dificuldade difícil)
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
          .select('best_score_memory, is_casual, streak, last_play_date')
          .eq('id', user.id)
          .single();

      setState(() {
        _recorde = data['best_score_memory'] as int?;
        _isCasual = data['is_casual'] as bool? ?? false;
        _streak = data['streak'] as int? ?? 0;
        _lastPlayDate = data['last_play_date'] as String?;
        _isGuest = false;
      });
    } catch (e) {
      debugPrint('Erro ao obter perfil no Jogo da Memória: $e');
      setState(() {
        _isGuest = false;
      });
    }
  }

  // Inicia a memorização: mostra cartas viradas por 2 segundos
  void _iniciarMemorizacao() {
    _inicializarTabuleiro();
    
    // Revela todas as cartas para a memorização
    for (var card in _cards) {
      card.isFaceUp = true;
    }

    setState(() {
      _isMemorizing = true;
      _isCountingDown = false;
      _moves = 0;
      _selectedCardIndex1 = -1;
      _selectedCardIndex2 = -1;
      _isChecking = false;
    });

    _memorizeTimer?.cancel();
    _memorizeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      setState(() {
        // Oculta todas as cartas de volta, exceto o Coringa (se modo médio)
        for (int i = 0; i < _cards.length; i++) {
          if (widget.difficulty == 'médio' && i == 12) {
            continue;
          }
          _cards[i].isFaceUp = false;
        }
        _isMemorizing = false;
      });
      
      // Inicia a contagem regressiva de 3s
      _iniciarCountdown();
    });
  }

  // Controla o cronômetro da contagem regressiva
  void _iniciarCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else if (_countdownValue == 1) {
          _countdownValue = 0; // Exibe "Já!"
        } else {
          timer.cancel();
          _isCountingDown = false;
        }
      });
    });
  }

  // Inicializa e embaralha o tabuleiro
  void _inicializarTabuleiro() {
    int numPairs;
    if (widget.difficulty == 'fácil') {
      numPairs = 8;
    } else if (widget.difficulty == 'médio') {
      numPairs = 12; // 12 pares + 1 coringa = 25 cartas
    } else {
      numPairs = 18; // 18 pares = 36 cartas
    }

    final selectedEmojis = _baseEmojis.sublist(0, numPairs);
    final doubleEmojis = [...selectedEmojis, ...selectedEmojis];
    doubleEmojis.shuffle();

    if (widget.difficulty == 'médio') {
      _cards = doubleEmojis.map((emoji) => MemoryCard(content: emoji)).toList();
      // O Coringa fica no centro geométrico (índice 12 de um grid de 25)
      _cards.insert(
        12,
        MemoryCard(
          content: '⭐',
          isFaceUp: true,
          isMatched: true,
        ),
      );
    } else {
      _cards = doubleEmojis.map((emoji) => MemoryCard(content: emoji)).toList();
    }
  }

  // Lógica ao selecionar um card
  void _onCardTap(int index) {
    if (_isCountingDown || _isChecking || _isMemorizing) return;
    
    final selectedCard = _cards[index];
    if (selectedCard.isFaceUp || selectedCard.isMatched) return;

    SoundEffects.playCardFlip();

    setState(() {
      selectedCard.isFaceUp = true;
    });

    if (_selectedCardIndex1 == -1) {
      _selectedCardIndex1 = index;
    } else {
      _selectedCardIndex2 = index;
      _moves++;
      _isChecking = true;

      // Verifica se formam um par
      if (_cards[_selectedCardIndex1].content == _cards[_selectedCardIndex2].content) {
        _cards[_selectedCardIndex1].isMatched = true;
        _cards[_selectedCardIndex2].isMatched = true;
        _selectedCardIndex1 = -1;
        _selectedCardIndex2 = -1;
        _isChecking = false;

        // Verifica vitória
        if (_cards.every((card) => card.isMatched)) {
          _finalizarJogo();
        }
      } else {
        // Desvira após curto intervalo se errou
        Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _cards[_selectedCardIndex1].isFaceUp = false;
            _cards[_selectedCardIndex2].isFaceUp = false;
            _selectedCardIndex1 = -1;
            _selectedCardIndex2 = -1;
            _isChecking = false;
          });
        });
      }
    }
  }

  // Finaliza o jogo e envia o recorde se estiver na dificuldade difícil
  Future<void> _finalizarJogo() async {
    bool recordeBatido = false;
    final antigoRecorde = _recorde;

    // Apenas registra o recorde na dificuldade difícil!
    if (widget.difficulty == 'difícil') {
      if (antigoRecorde == null || _moves < antigoRecorde) {
        recordeBatido = true;
        setState(() => _recorde = _moves);
      }
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
          updates['best_score_memory'] = _moves;
        }

        if (updates.isNotEmpty) {
          try {
             await Supabase.instance.client
                .from('profiles')
                .update(updates)
                .eq('id', user.id);
          } catch (e) {
            debugPrint('Erro ao atualizar recorde/streak no banco: $e');
          }
        }

        try {
          await Supabase.instance.client
              .from('play_history')
              .upsert({'user_id': user.id, 'play_date': todayStr});
        } catch (e) {
          debugPrint('Erro ao atualizar historico de jogadas no banco: $e');
        }
      }
    }

    if (!mounted) return;

    // Mostra tela de finalização premium
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = isDarkModeNotifier.value;
        final dialogBg = isDark ? const Color(0xFF1B2A47) : Colors.white;
        final textColor = isDark ? Colors.white : AppColors.azulPrincipal;
        final subtextColor = isDark ? Colors.white70 : Colors.black87;

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Vitória!',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Parabéns, você combinou todos os pares!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: subtextColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Sua Pontuação: $_moves jogadas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.rosaBotao),
              ),
              const SizedBox(height: 8),
              if (widget.difficulty != 'difícil')
                Text(
                  'Recordes são salvos apenas no modo Difícil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.amber.shade200 : Colors.amber.shade800, fontSize: 13, fontWeight: FontWeight.bold),
                )
              else if (recordeBatido)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🏆 NOVO RECORDE!',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                  ),
                )
              else if (_recorde != null)
                Text(
                  'Recorde Atual: $_recorde jogadas',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                )
              else
                const Text(
                  'Cadastre-se para salvar seus recordes!',
                  style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // fecha dialog
                Navigator.pop(context); // volta para home
              },
              icon: const Icon(Icons.home, color: Colors.white),
              label: const Text('Home', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // fecha dialog
                _iniciarMemorizacao(); // reinicia
              },
              icon: const Icon(Icons.replay, color: Colors.white),
              label: const Text('Jogar Novo', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rosaBotao,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
    
    // Determina a quantidade de colunas e espaçamento com base na dificuldade
    final int crossCount = widget.difficulty == 'fácil'
        ? 4
        : widget.difficulty == 'médio'
            ? 5
            : 6;

    final double spacing = widget.difficulty == 'fácil'
        ? 12
        : widget.difficulty == 'médio'
            ? 8
            : 6;

    // Determina o tamanho da fonte dos emojis
    final double emojiFontSize = widget.difficulty == 'fácil'
        ? 42
        : widget.difficulty == 'médio'
            ? 34
            : 28;
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
          'Jogo da Memória (${widget.difficulty.toUpperCase()})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
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
                    
                    // Tabuleiro de Memória ou Tela de Contagem Regressiva
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
                    else
                      // Tabuleiro de Memória Adaptado
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _cards.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            return MemoryCardWidget(
                              content: card.content,
                              isFaceUp: card.isFaceUp,
                              isMatched: card.isMatched,
                              fontSize: emojiFontSize,
                              onTap: () => _onCardTap(index),
                            );
                          },
                        ),
                      ),

                    const Spacer(),

                    // Pontuação/Jogadas na parte inferior
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Text(
                        _isMemorizing ? 'Memorize as cartas!' : 'Pontuação: $_moves',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Carta de Memória
class MemoryCard {
  final String content;
  bool isFaceUp;
  bool isMatched;

  MemoryCard({
    required this.content,
    this.isFaceUp = false,
    this.isMatched = false,
  });
}

// Pintor da Estrela Discreta no Background
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

// Widget de Carta de Memória com Animação de Giro 3D
class MemoryCardWidget extends StatefulWidget {
  final String content;
  final bool isFaceUp;
  final bool isMatched;
  final double fontSize;
  final VoidCallback onTap;

  const MemoryCardWidget({
    super.key,
    required this.content,
    required this.isFaceUp,
    required this.isMatched,
    required this.fontSize,
    required this.onTap,
  });

  @override
  State<MemoryCardWidget> createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<MemoryCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isFaceUp || widget.isMatched) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MemoryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldBeFaceUp = widget.isFaceUp || widget.isMatched;
    if (shouldBeFaceUp) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final isBack = angle >= math.pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Efeito de perspectiva 3D
            ..rotateY(angle),
          alignment: Alignment.center,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isBack
                    ? (isDark ? const Color(0xFF1B2A47) : Colors.white)
                    : (isDark ? const Color(0xFF0D1B2A) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: isDark 
                    ? Border.all(color: Colors.white12, width: 1.5)
                    : Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isBack
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(math.pi), // Desfaz o espelhamento da rotação 3D
                        alignment: Alignment.center,
                        child: Text(
                          widget.content,
                          style: TextStyle(fontSize: widget.fontSize),
                        ),
                      )
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white30 : Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
