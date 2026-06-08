import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'soundEffects.dart';

class PuzzleGamePage extends StatefulWidget {
  final String difficulty;

  const PuzzleGamePage({super.key, this.difficulty = 'difícil'});

  @override
  State<PuzzleGamePage> createState() => _PuzzleGamePageState();
}

class DragPieceData {
  final int pieceIndex;
  final int? sourceGridIndex;

  DragPieceData({required this.pieceIndex, this.sourceGridIndex});
}

class _PuzzleGamePageState extends State<PuzzleGamePage> {
  // Estado do Perfil, Ofensivas e Recordes
  int? _recorde; // best_score_puzzle (movimentos, menor é melhor)
  int _streak = 0;
  String? _lastPlayDate;
  bool _isCasual = false;

  // Lógica do Quebra-cabeça
  late int _gridSize; // 3 no fácil, 4 no médio, 5 no difícil
  late int _totalPieces;
  late List<int?> _gridPieces; // Peças colocadas no tabuleiro
  late List<int> _poolPieces; // Lista de peças na área de escolha (embaralhada)
  late int _randomSeed; // Semente para carregar uma imagem aleatória a cada jogo
  
  int _moves = 0;
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _setupDifficulty();
    _loadProfileAndRecord();
    _iniciarCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setupDifficulty() {
    if (widget.difficulty == 'fácil') {
      _gridSize = 3; // 3x3 = 9 peças
    } else if (widget.difficulty == 'médio') {
      _gridSize = 4; // 4x4 = 16 peças
    } else {
      _gridSize = 5; // 5x5 = 25 peças
    }
    _totalPieces = _gridSize * _gridSize;
    _gridPieces = List.filled(_totalPieces, null);
    
    // As peças são identificadas de 0 a _totalPieces - 1
    final list = List.generate(_totalPieces, (index) => index);
    list.shuffle();
    _poolPieces = list;
    
    // Gera uma nova imagem aleatória
    _randomSeed = math.Random().nextInt(10000);
  }

  Future<void> _loadProfileAndRecord() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('best_score_puzzle, is_casual, streak, last_play_date')
          .eq('id', user.id)
          .single();

      setState(() {
        _recorde = data['best_score_puzzle'] as int?;
        _isCasual = data['is_casual'] as bool? ?? false;
        _streak = data['streak'] as int? ?? 0;
        _lastPlayDate = data['last_play_date'] as String?;
      });
    } catch (e) {
      debugPrint('Aviso: Coluna best_score_puzzle pode não existir ainda no banco: $e');
      try {
        final fallbackData = await Supabase.instance.client
            .from('profiles')
            .select('is_casual, streak, last_play_date')
            .eq('id', user.id)
            .single();
        setState(() {
          _isCasual = fallbackData['is_casual'] as bool? ?? false;
          _streak = fallbackData['streak'] as int? ?? 0;
          _lastPlayDate = fallbackData['last_play_date'] as String?;
        });
      } catch (ex) {
        debugPrint('Erro total ao buscar perfil no Puzzle: $ex');
      }
    }
  }

  void _iniciarCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          timer.cancel();
          _isCountingDown = false;
          _iniciarJogo();
        }
      });
    });
  }

  void _iniciarJogo() {
    setState(() {
      _moves = 0;
      _isPlaying = true;
    });
  }

  void _onPieceDropped({required int pieceIndex, int? sourceGridIndex, required int targetGridIndex}) {
    if (!_isPlaying || _isCountingDown) return;

    setState(() {
      final existingPiece = _gridPieces[targetGridIndex];

      // Coloca a nova peça no grid de destino
      _gridPieces[targetGridIndex] = pieceIndex;

      if (sourceGridIndex == null) {
        // Veio da bandeja de peças
        _poolPieces.remove(pieceIndex);
        if (existingPiece != null) {
          _poolPieces.add(existingPiece);
        }
      } else {
        // Movendo dentro do grid (permite troca/swap)
        _gridPieces[sourceGridIndex] = existingPiece;
      }

      _moves++;
    });

    SoundEffects.playKeyboardClick(); // Som de clique ao posicionar a peça

    // Verifica se completou na ordem correta
    bool won = true;
    for (int i = 0; i < _totalPieces; i++) {
      if (_gridPieces[i] != i) {
        won = false;
        break;
      }
    }

    if (won) {
      _finalizarJogo();
    }
  }

  void _onPieceReturnedToPool(int pieceIndex, int sourceGridIndex) {
    if (!_isPlaying || _isCountingDown) return;

    setState(() {
      _gridPieces[sourceGridIndex] = null;
      _poolPieces.add(pieceIndex);
      _moves++;
    });

    SoundEffects.playCardFlip(); // Som de vento ao retornar a peça
  }

  Future<void> _finalizarJogo() async {
    setState(() {
      _isPlaying = false;
    });

    final user = Supabase.instance.client.auth.currentUser;
    bool recordeBatido = false;

    if (widget.difficulty == 'difícil') {
      if (_recorde == null || _moves < _recorde!) {
        recordeBatido = true;
        _recorde = _moves;
      }
    }

    if (user != null && !_isCasual) {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      int? newStreak;
      
      if (_lastPlayDate == null) {
        newStreak = 1;
      } else {
        final lastPlay = DateTime.parse(_lastPlayDate!);
        final difference = DateTime.now().difference(lastPlay).inDays;
        
        if (difference == 1) {
          newStreak = _streak + 1;
        } else if (difference > 1) {
          newStreak = 1;
        }
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
        updates['best_score_puzzle'] = _moves;
      }

      if (updates.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update(updates)
              .eq('id', user.id);
        } catch (e) {
          debugPrint('Erro ao atualizar recorde/streak de puzzle: $e');
        }
      }

      try {
        await Supabase.instance.client
            .from('play_history')
            .upsert({'user_id': user.id, 'play_date': todayStr});
      } catch (e) {
        debugPrint('Erro ao salvar histórico de jogadas: $e');
      }
    }

    if (!mounted) return;
    _mostrarDialogoVitoria(recordeBatido);
  }

  void _mostrarDialogoVitoria(bool recordeBatido) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = isDarkModeNotifier.value;
        final dialogBg = isDark ? const Color(0xFF1B2A47) : Colors.white;
        final textColor = isDark ? Colors.white : AppColors.azulPrincipalClaro;
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
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Parabéns! Você ordenou todas as peças do quebra-cabeça.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtextColor, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Movimentos: $_moves',
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (recordeBatido) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text(
                    '🏆 Novo Recorde Batido!',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (widget.difficulty != 'difícil') ...[
                const SizedBox(height: 12),
                Text(
                  'Recordes são salvos apenas no modo Difícil (5x5).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rosaBotao,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context); // Fecha diálogo
                Navigator.pop(context); // Volta à home
              },
              child: const Text('Voltar ao Menu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _setupDifficulty();
                  _iniciarCountdown();
                });
              },
              child: Text(
                'Jogar Novamente',
                style: TextStyle(color: AppColors.azulPrincipalClaro, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Desenha cada célula individual do quebra-cabeça recortada da imagem completa
  Widget _buildPuzzleTile(int pieceIndex, {required double size}) {
    final int r = pieceIndex ~/ _gridSize;
    final int c = pieceIndex % _gridSize;
    final double fullSize = size * _gridSize;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: OverflowBox(
          minWidth: fullSize,
          maxWidth: fullSize,
          minHeight: fullSize,
          maxHeight: fullSize,
          alignment: Alignment(
            _gridSize == 1 ? 0.0 : -1.0 + (c / (_gridSize - 1)) * 2.0,
            _gridSize == 1 ? 0.0 : -1.0 + (r / (_gridSize - 1)) * 2.0,
          ),
          child: Image.network(
            'https://picsum.photos/500/500?random=$_randomSeed',
            width: fullSize,
            height: fullSize,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: fullSize,
                height: fullSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSVColor.fromAHSV(1.0, 195.0 + (r * 12.0) + (c * 12.0), 0.85, 0.85).toColor(),
                      HSVColor.fromAHSV(1.0, 260.0 + (r * 12.0) + (c * 12.0), 0.85, 0.80).toColor(),
                    ],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback com Gradiente + Ícone do Sinapse se estiver offline
              return Container(
                width: fullSize,
                height: fullSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSVColor.fromAHSV(1.0, 195.0 + (r * 12.0) + (c * 12.0), 0.85, 0.85).toColor(),
                      HSVColor.fromAHSV(1.0, 260.0 + (r * 12.0) + (c * 12.0), 0.85, 0.80).toColor(),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.psychology_rounded,
                    size: fullSize * 0.7,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    final azulPrincipal = AppColors.azulPrincipal;
    
    // Definição da largura disponível para o tabuleiro
    final double screenWidth = MediaQuery.of(context).size.width;
    final double boardSize = math.min(screenWidth - 48, 320.0);
    final double tileSize = boardSize / _gridSize;

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
          'Quebra-Cabeça (${widget.difficulty.toUpperCase()})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          // Background - Formas Geométricas Decorativas
          Positioned.fill(
            child: CustomPaint(
              painter: PuzzleBackgroundPainter(isDark: isDark),
            ),
          ),

          // Área do Jogo
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Dashboard de Jogo - Apenas Movimentos + Gabarito (Olho)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Movimentos: $_moves',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white24,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Ver Gabarito',
                              icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 22),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text(
                                      'Gabarito',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            'https://picsum.photos/500/500?random=$_randomSeed',
                                            width: 250,
                                            height: 250,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 250,
                                                height: 250,
                                                color: AppColors.azulPrincipalClaro,
                                                child: const Center(
                                                  child: Icon(Icons.psychology_rounded, size: 80, color: Colors.white),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'Voltar ao Jogo',
                                          style: TextStyle(
                                            color: AppColors.azulPrincipalClaro,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tabuleiro do Quebra-cabeça
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: boardSize + 16,
                        height: boardSize + 16,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _totalPieces,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridSize,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemBuilder: (context, index) {
                            final placedPieceIndex = _gridPieces[index];
                            
                            Widget cellContent;
                            if (placedPieceIndex != null) {
                              final tile = _buildPuzzleTile(placedPieceIndex, size: tileSize);
                              
                              cellContent = Draggable<DragPieceData>(
                                data: DragPieceData(pieceIndex: placedPieceIndex, sourceGridIndex: index),
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Transform.scale(
                                    scale: 1.15,
                                    child: tile,
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.25,
                                  child: tile,
                                ),
                                child: tile,
                              );
                            } else {
                              cellContent = Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            return DragTarget<DragPieceData>(
                              onWillAccept: (data) => data != null,
                              onAccept: (data) {
                                _onPieceDropped(
                                  pieceIndex: data.pieceIndex,
                                  sourceGridIndex: data.sourceGridIndex,
                                  targetGridIndex: index,
                                );
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isOver = candidateData.isNotEmpty;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isOver
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOver ? Colors.white : Colors.white24,
                                      width: isOver ? 2 : 1,
                                    ),
                                  ),
                                  child: cellContent,
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // Overlay de Contagem Regressiva
                      if (_isCountingDown)
                        Container(
                          width: boardSize + 16,
                          height: boardSize + 16,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: Text(
                                _countdownValue == 0 ? 'JÁ!' : '$_countdownValue',
                                key: ValueKey<int>(_countdownValue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 80,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Área de Peças Disponíveis (Bandeja)
                  Expanded(
                    child: DragTarget<DragPieceData>(
                      onWillAccept: (data) => data != null && data.sourceGridIndex != null,
                      onAccept: (data) {
                        _onPieceReturnedToPool(data.pieceIndex, data.sourceGridIndex!);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isOver = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isOver
                                ? Colors.white.withOpacity(0.15)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Suas peças (Arraste aqui para devolver):',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _poolPieces.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Todas as peças foram encaixadas! 👏',
                                          style: TextStyle(color: Colors.white60, fontSize: 16),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            children: _poolPieces.map((pieceIndex) {
                                              final tile = _buildPuzzleTile(pieceIndex, size: tileSize * 0.95);
                                              
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 12.0),
                                                child: Draggable<DragPieceData>(
                                                  data: DragPieceData(pieceIndex: pieceIndex, sourceGridIndex: null),
                                                  feedback: Material(
                                                    color: Colors.transparent,
                                                    child: Transform.scale(
                                                      scale: 1.15,
                                                      child: tile,
                                                    ),
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.25,
                                                    child: tile,
                                                  ),
                                                  child: tile,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor do Octógono Discreto no Background
class PuzzleBackgroundPainter extends CustomPainter {
  final bool isDark;

  PuzzleBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = isDark ? 0.02 : 0.05;
    final paint = Paint()
      ..color = Colors.white.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;

    final path = Path();
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width * 0.7;

    for (int i = 0; i < 8; i++) {
      final double angle = i * (2 * math.pi / 8);
      final double x = centerX + radius * math.cos(angle);
      final double y = centerY + radius * math.sin(angle);
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
