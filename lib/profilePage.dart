import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color azulPrincipal = Color(0xFF1565C0);
    const Color rosaBotao = Color(0xFFD81B60);
    const Color vermelhoTexto = Color(0xFFB71C1C); 

    return Scaffold(
      backgroundColor: azulPrincipal, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        toolbarHeight: 90,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 40),
            onPressed: () {
              // Ação do menu
            },
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '53',
                  style: TextStyle(
                    color: azulPrincipal,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Círculo branco (Avatar do usuário)
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Nome de usuário
            const Text(
              '@nome_de_usuário',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 60), 
            
            // Lista de Botões
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  _buildButton(
                    text: 'Ativar modo casual',
                    backgroundColor: rosaBotao,
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    text: 'Editar nome de usuário',
                    backgroundColor: rosaBotao,
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 40),
                  _buildButton(
                    text: 'Excluir conta',
                    backgroundColor: Colors.white,
                    textColor: vermelhoTexto,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para criar os botões padronizados dessa tela
  Widget _buildButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        minimumSize: const Size(double.infinity, 50), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), 
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}