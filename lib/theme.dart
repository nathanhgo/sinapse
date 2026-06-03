import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Notificador global para controlar o estado do Modo Escuro
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

class AppColors {
  // --- PALETA MODO CLARO (Original) ---
  static const Color azulPrincipalClaro = Color(0xFF1565C0);
  static const Color azulBordaClaro = Color(0xFF1E88E5);
  static const Color rosaBotaoClaro = Color(0xFFD81B60);
  static const Color fundoTelaClaro = Color(0xFFF3F0F6);
  static const Color cardFundoClaro = Colors.white;
  static const Color textoClaro = Colors.black87;
  static const Color textoSecundarioClaro = Colors.black54;

  // --- PALETA MODO ESCURO (Estilo Word Game) ---
  static const Color azulPrincipalEscuro = Color(0xFF0D1B2A);
  static const Color azulBordaEscuro = Color(0xFF1B2A47);
  static const Color rosaBotaoEscuro = Color(0xFFD81B60); // Mantém o rosa para contraste
  static const Color fundoTelaEscuro = Color(0xFF050B14); // Mais escuro que o card
  static const Color cardFundoEscuro = Color(0xFF0D1B2A); // Card no azul profundo
  static const Color textoEscuro = Colors.white;
  static const Color textoSecundarioEscuro = Colors.white70;

  // --- GETTERS DINÂMICOS (Reagem ao tema ativo) ---
  static Color get azulPrincipal => isDarkModeNotifier.value ? azulPrincipalEscuro : azulPrincipalClaro;
  static Color get azulBorda => isDarkModeNotifier.value ? azulBordaEscuro : azulBordaClaro;
  static Color get rosaBotao => isDarkModeNotifier.value ? rosaBotaoEscuro : rosaBotaoClaro;
  static Color get fundoTela => isDarkModeNotifier.value ? fundoTelaEscuro : fundoTelaClaro;
  static Color get cardFundo => isDarkModeNotifier.value ? cardFundoEscuro : cardFundoClaro;
  static Color get texto => isDarkModeNotifier.value ? textoEscuro : textoClaro;
  static Color get textoSecundario => isDarkModeNotifier.value ? textoSecundarioEscuro : textoSecundarioClaro;

  // Cores específicas para o Word Game (Palavra Certa) em ambos os modos
  static Color get wordGameBg => isDarkModeNotifier.value ? const Color(0xFF050B14) : fundoTelaClaro;
  static Color get wordGameEmptyTileBorder => isDarkModeNotifier.value ? Colors.grey.shade700 : Colors.grey.shade400;
  static Color get wordGameEmptyTileText => isDarkModeNotifier.value ? Colors.white : Colors.black87;
  static Color get wordGameKeyboardKeyBg => isDarkModeNotifier.value ? Colors.grey.shade800 : Colors.grey.shade300;
  static Color get wordGameKeyboardKeyText => isDarkModeNotifier.value ? Colors.white : Colors.black87;
  static Color get wordGameDialogBg => isDarkModeNotifier.value ? const Color(0xFF0D1B2A) : Colors.white;
  static Color get wordGameDialogText => isDarkModeNotifier.value ? Colors.white : Colors.black87;
}

class StreakCalendarDialog extends StatefulWidget {
  const StreakCalendarDialog({super.key});

  @override
  State<StreakCalendarDialog> createState() => _StreakCalendarDialogState();
}

class _StreakCalendarDialogState extends State<StreakCalendarDialog> {
  DateTime _selectedMonth = DateTime.now();
  List<String> _playedDates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('play_history')
          .select('play_date')
          .eq('user_id', user.id);

      final dates = (data as List).map((row) => row['play_date'] as String).toList();
      setState(() {
        _playedDates = dates;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar historico: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    final dialogBg = isDark ? const Color(0xFF1B2A47) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.azulPrincipalClaro;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Dias do mês
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final firstDayOffset = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final monthName = monthNames[_selectedMonth.month - 1];

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: titleColor),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
            },
          ),
          Text(
            '$monthName ${_selectedMonth.year}',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: titleColor),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              });
            },
          ),
        ],
      ),
      content: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Expanded(child: Text('D', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('S', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('T', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('Q', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('Q', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('S', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(child: Text('S', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: daysInMonth + firstDayOffset,
                    itemBuilder: (context, index) {
                      if (index < firstDayOffset) {
                        return const SizedBox();
                      }
                      final day = index - firstDayOffset + 1;
                      final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final hasPlayed = _playedDates.contains(dateStr);

                      return Container(
                        decoration: BoxDecoration(
                          color: hasPlayed
                              ? AppColors.rosaBotao
                              : (isDark ? Colors.white.withAlpha(20) : Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: hasPlayed
                                  ? Colors.white
                                  : textColor,
                              fontWeight: hasPlayed ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
