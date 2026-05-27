import 'package:flutter/material.dart';

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
