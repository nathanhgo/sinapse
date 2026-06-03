import 'package:flutter/material.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'soundEffects.dart';

class WordGamePage extends StatefulWidget {
  final String difficulty;

  const WordGamePage({super.key, this.difficulty = 'difícil'});

  @override
  State<WordGamePage> createState() => _WordGamePageState();
}

class _WordGamePageState extends State<WordGamePage> {
  // Estado do Perfil, Ofensivas e Recordes
  int? _recorde; // best_score_word (tentativas, menor é melhor)
  int _streak = 0;
  String? _lastPlayDate;
  bool _isGuest = true;

  // Palavras de 5 letras relacionadas ao contexto ou gerais
  final List<String> _wordList5 = [
    'MENTE', 'FOCOS', 'JOGOS', 'SAGAZ', 'TERMO', 'LETRA', 'IDEIA',
    'SABER', 'TESTE', 'PROVA', 'LIVRO', 'AULAS', 'VISAO', 'RAZAO',
    'CALMA', 'SENSO', 'GENIO', 'FOCAR', 'TEXTO', 'NOTAS', 'FRASE',
    'VERBO', 'VOGAL', 'LINHA', 'LENTE', 'LIGAR', 'OUVIR', 'FALAR',
    'TEMPO', 'MUNDO', 'FORTE', 'LUGAR', 'NOITE', 'JUSTO', 'CLARO',
    'PLANO', 'REGRA', 'PONTO', 'DADOS', 'COISA', 'NOBRE', 'CERTO',
    'VALOR', 'IDEAL', 'SORTE', 'FORMA', 'PARTE', 'FINAL', 'TERRA',
    'PODER', 'AUTOR', 'CAPAZ', 'VIVER', 'NOVA', 'LIDER', 'ATIVO'
  ];

  // Palavras de 7 letras
  final List<String> _wordList7 = [
    'CELEBRO', 'MEMORIA', 'DESAFIO', 'CEREBRO', 'ESTUDOS', 'ATENCAO', 'LOGICOS',
    'TALENTO', 'SUCESSO', 'VITORIA', 'RECORDE', 'JOGADAS', 'LEITURA', 'ESCRITA',
    'EMPATIA', 'CORAGEM', 'AMIZADE', 'PLANETA', 'PROJETO', 'CULTURA', 'CADERNO'
  ];

  // Palavras de 9 letras
  final List<String> _wordList9 = [
    'COGNITIVO', 'RACIOCINA', 'BRILHANTE', 'CONCENTRA', 'PERCEPCAO', 'SABEDORIA',
    'AGILIDADE', 'CONQUISTA', 'EVOLUCOES', 'DEDICACAO', 'INSPIRADO', 'ESTRATEGA',
    'DESAFIADO', 'PACIENCIA', 'AUTONOMIA', 'DESPERTAR', 'FACULDADE', 'EXCELENTE'
  ];

  late String _targetWord;
  final int _maxAttempts = 6;
  late final int _wordLength;
  
  final List<String> _guesses = [];
  String _currentGuess = "";
  
  // Mapeia o status das letras para o teclado virtual
  final Map<String, Color> _keyboardColors = {};

  @override
  void initState() {
    super.initState();
    if (widget.difficulty == 'fácil') {
      _wordLength = 5;
    } else if (widget.difficulty == 'médio') {
      _wordLength = 7;
    } else {
      _wordLength = 9;
    }
    _loadProfile();
    _startNewGame();
  }

  // Carrega informações de perfil, streak e recorde
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isGuest = true;
      });
      return;
    }

    try {
      Map<String, dynamic> data;
      try {
        data = await Supabase.instance.client
            .from('profiles')
            .select('streak, last_play_date, best_score_word')
            .eq('id', user.id)
            .single();
      } catch (e) {
        debugPrint('Aviso: Falha ao buscar best_score_word, tentando sem a coluna: $e');
        data = await Supabase.instance.client
            .from('profiles')
            .select('streak, last_play_date')
            .eq('id', user.id)
            .single();
      }

      setState(() {
        _streak = data['streak'] as int? ?? 0;
        _lastPlayDate = data['last_play_date'] as String?;
        _recorde = data.containsKey('best_score_word') ? data['best_score_word'] as int? : null;
        _isGuest = false;
      });
    } catch (e) {
      debugPrint('Erro ao obter perfil no WordGame: $e');
      setState(() {
        _isGuest = false;
      });
    }
  }

  Future<void> _atualizarOfensiva(bool recordeBatido) async {
    if (_isGuest) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

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
    if (widget.difficulty == 'difícil' && recordeBatido && _recorde != null) {
      updates['best_score_word'] = _recorde;
    }

    if (updates.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update(updates)
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Erro ao atualizar streak/recorde no WordGame: $e');
      }
    }

    try {
      await Supabase.instance.client
          .from('play_history')
          .upsert({'user_id': user.id, 'play_date': todayStr});
    } catch (e) {
      debugPrint('Erro ao atualizar historico de jogadas no WordGame: $e');
    }
  }

  void _startNewGame() {
    final random = Random();
    List<String> list;
    if (widget.difficulty == 'fácil') {
      list = _wordList5;
    } else if (widget.difficulty == 'médio') {
      list = _wordList7;
    } else {
      list = _wordList9;
    }
    _targetWord = list[random.nextInt(list.length)];
    _guesses.clear();
    _currentGuess = "";
    _keyboardColors.clear();
    setState(() {});
  }

  void _onKeyPress(String letter) {
    if (_guesses.length >= _maxAttempts) return;

    SoundEffects.playKeyboardClick();

    setState(() {
      if (letter == "ENTER") {
        if (_currentGuess.length == _wordLength) {
          _submitGuess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A palavra deve ter $_wordLength letras!'), duration: const Duration(seconds: 1)),
          );
        }
      } else if (letter == "DEL") {
        if (_currentGuess.isNotEmpty) {
          _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        }
      } else {
        if (_currentGuess.length < _wordLength) {
          _currentGuess += letter;
        }
      }
    });
  }

  void _submitGuess() {
    setState(() {
      _guesses.add(_currentGuess);
      _updateKeyboardColors(_currentGuess);
      
      final won = _currentGuess == _targetWord;
      bool recordeBatido = false;

      if (won || _guesses.length >= _maxAttempts) {
        if (won && widget.difficulty == 'difícil') {
          int score = _guesses.length;
          if (_recorde == null || score < _recorde!) {
            recordeBatido = true;
            _recorde = score;
          }
        }
        _atualizarOfensiva(recordeBatido);
        if (won) {
          _showGameOverDialog("Parabéns!", "Você acertou a palavra: $_targetWord", recordeBatido);
        } else {
          _showGameOverDialog("Fim de Jogo", "A palavra correta era: $_targetWord", recordeBatido);
        }
      }
      
      _currentGuess = "";
    });
  }

  void _updateKeyboardColors(String guess) {
    final isDark = isDarkModeNotifier.value;
    for (int i = 0; i < guess.length; i++) {
      String char = guess[i];
      if (_targetWord[i] == char) {
        _keyboardColors[char] = Colors.green;
      } else if (_targetWord.contains(char) && _keyboardColors[char] != Colors.green) {
        _keyboardColors[char] = Colors.amber;
      } else if (!_targetWord.contains(char)) {
        _keyboardColors[char] = isDark ? const Color(0xFF151D26) : Colors.grey.shade400;
      }
    }
  }

  Color _getKeyBgColor(String letter) {
    return _keyboardColors[letter] ?? AppColors.wordGameKeyboardKeyBg;
  }

  Color _getKeyTextColor(String letter) {
    final isDark = isDarkModeNotifier.value;
    if (_keyboardColors.containsKey(letter)) {
      final color = _keyboardColors[letter]!;
      if (color == Colors.green || color == Colors.amber) {
        return Colors.white;
      }
      return isDark ? Colors.white30 : Colors.black26;
    }
    return AppColors.wordGameKeyboardKeyText;
  }

  void _showGameOverDialog(String title, String message, bool recordeBatido) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = isDarkModeNotifier.value;
        return AlertDialog(
          backgroundColor: AppColors.wordGameDialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: TextStyle(color: AppColors.wordGameDialogText, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.difficulty != 'difícil')
                Text(
                  'Recordes são salvos apenas no modo Difícil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
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
                  'Recorde Atual: $_recorde tentativas',
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
                _startNewGame(); // reinicia
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

  Color _getLetterColor(int attemptIndex, int letterIndex) {
    if (attemptIndex >= _guesses.length) return Colors.transparent;
    
    String guess = _guesses[attemptIndex];
    String char = guess[letterIndex];
    
    if (_targetWord[letterIndex] == char) {
      return Colors.green;
    } else if (_targetWord.contains(char)) {
      return Colors.amber;
    }
    return isDarkModeNotifier.value ? Colors.grey.shade700 : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    final appBarColor = isDark ? Colors.transparent : AppColors.azulPrincipal;
    final appBarTitleColor = isDark ? Colors.white : Colors.white;

    // Configuração responsiva do grid baseada no tamanho da palavra
    final double maxBoxWidth = _wordLength == 5
        ? 350
        : _wordLength == 7
            ? 370
            : 390;

    final double gridSpacing = _wordLength == 5
        ? 8
        : _wordLength == 7
            ? 6
            : 4;

    final double gridFontSize = _wordLength == 5
        ? 28
        : _wordLength == 7
            ? 22
            : 18;

    return Scaffold(
      backgroundColor: AppColors.wordGameBg,
      appBar: AppBar(
        title: Text(
          'Palavra Certa (${widget.difficulty.toUpperCase()})',
          style: TextStyle(color: appBarTitleColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBoxWidth),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _wordLength,
                      mainAxisSpacing: gridSpacing,
                      crossAxisSpacing: gridSpacing,
                    ),
                    itemCount: _maxAttempts * _wordLength,
                    itemBuilder: (context, index) {
                      int attemptIndex = index ~/ _wordLength;
                      int letterIndex = index % _wordLength;
                      
                      String letter = "";
                      Color bgColor = Colors.transparent;
                      
                      if (attemptIndex < _guesses.length) {
                        letter = _guesses[attemptIndex][letterIndex];
                        bgColor = _getLetterColor(attemptIndex, letterIndex);
                      } else if (attemptIndex == _guesses.length && letterIndex < _currentGuess.length) {
                        letter = _currentGuess[letterIndex];
                      }

                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: bgColor == Colors.transparent
                                ? AppColors.wordGameEmptyTileBorder
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: gridFontSize,
                            fontWeight: FontWeight.bold,
                            color: bgColor == Colors.transparent
                                ? AppColors.wordGameEmptyTileText
                                : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          _buildKeyboard(),
        ],
      ),
    );
  }

  Widget _buildKeyboard() {
    final keys = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'DEL']
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 8.0, right: 8.0),
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((letter) {
              return Padding(
                padding: const EdgeInsets.all(3.0),
                child: Material(
                  color: _getKeyBgColor(letter),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => _onKeyPress(letter),
                    child: Container(
                      height: 50,
                      width: letter == 'ENTER' || letter == 'DEL' ? 60 : 32,
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: _getKeyTextColor(letter),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}