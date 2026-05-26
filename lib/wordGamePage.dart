import 'package:flutter/material.dart';
import 'dart:math';

class WordGamePage extends StatefulWidget {
  const WordGamePage({super.key});

  @override
  State<WordGamePage> createState() => _WordGamePageSta();
}

class _WordGamePageState extends State<WordGamePage> {
  // Palavras de 5 letras relacionadas ao contexto ou gerais
  final List<String> _wordList = [
    // Palavras Originais
    'MENTE', 'FOCOS', 'JOGOS', 'SAGAZ', 'TERMO', 'LETRA', 'IDEIA',
    
    // Temática: Cognição, Estudo e Cérebro
    'SABER', 'TESTE', 'PROVA', 'LIVRO', 'AULAS', 'VISAO', 'RAZAO',
    'CALMA', 'SENSO', 'GENIO', 'FOCAR', 'TEXTO', 'NOTAS', 'FRASE',
    'VERBO', 'VOGAL', 'LINHA', 'LENTE', 'LIGAR', 'OUVIR', 'FALAR',
    
    // Palavras Gerais Clássicas (Ótimas para Wordle/Termo)
    'TEMPO', 'MUNDO', 'FORTE', 'LUGAR', 'NOITE', 'JUSTO', 'CLARO',
    'PLANO', 'REGRA', 'PONTO', 'DADOS', 'COISA', 'NOBRE', 'CERTO',
    'VALOR', 'IDEAL', 'SORTE', 'FORMA', 'PARTE', 'FINAL', 'TERRA',
    'PODER', 'AUTOR', 'CAPAZ', 'VIVER', 'NOVA', 'LIDER', 'ATIVO'
  ];
  late String _targetWord;
  
  final int _maxAttempts = 6;
  final int _wordLength = 5;
  
  List<String> _guesses = [];
  String _currentGuess = "";
  
  // Mapeia o status das letras para o teclado virtual
  Map<String, Color> _keyboardColors = {};

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    final random = Random();
    _targetWord = _wordList[random.nextInt(_wordList.length)];
    _guesses.clear();
    _currentGuess = "";
    _keyboardColors.clear();
    setState(() {});
  }

  void _onKeyPress(String letter) {
    if (_guesses.length >= _maxAttempts) return;

    setState(() {
      if (letter == "ENTER") {
        if (_currentGuess.length == _wordLength) {
          _submitGuess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A palavra deve ter 5 letras!'), duration: Duration(seconds: 1)),
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
      
      if (_currentGuess == _targetWord) {
        _showGameOverDialog("Parabéns!", "Você acertou a palavra: $_targetWord");
      } else if (_guesses.length >= _maxAttempts) {
        _showGameOverDialog("Fim de Jogo", "A palavra correta era: $_targetWord");
      }
      
      _currentGuess = "";
    });
  }

  void _updateKeyboardColors(String guess) {
    for (int i = 0; i < guess.length; i++) {
      String char = guess[i];
      if (_targetWord[i] == char) {
        _keyboardColors[char] = Colors.green;
      } else if (_targetWord.contains(char) && _keyboardColors[char] != Colors.green) {
        _keyboardColors[char] = Colors.amber;
      } else if (!_targetWord.contains(char)) {
        _keyboardColors[char] = Colors.grey.shade800;
      }
    }
  }

  void _showGameOverDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A47),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text('Jogar Novamente', style: TextStyle(color: Colors.blueAccent)),
          )
        ],
      ),
    );
  }

  Color _getLetterColor(int attemptIndex, int letterIndex) {
    if (attemptIndex >= _guesses.length) return Colors.transparent;
    
    String guess = _guesses[attemptIndex];
    String char = guess[letterIndex];
    
    if (_targetWord[letterIndex] == char) {
      return Colors.green;
    } else if (_targetWord.contains(char)) {
      // Lógica simplificada de amarelo (não trata letras duplicadas perfeitamente, mas funciona para a base)
      return Colors.amber;
    }
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // Fundo azul profundo do Sinapse
      appBar: AppBar(
        title: const Text('Desafio Diário'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
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
                          color: bgColor == Colors.transparent ? Colors.grey.shade600 : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        letter,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    );
                  },
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
                  color: _keyboardColors[letter] ?? Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => _onKeyPress(letter),
                    child: Container(
                      height: 50,
                      width: letter == 'ENTER' || letter == 'DEL' ? 60 : 32,
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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