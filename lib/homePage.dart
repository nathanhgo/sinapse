import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Reutilizando as cores baseadas no seu tema
    const Color azulPrincipal = Color(0xFF1565C0);
    const Color azulBorda = Color(0xFF1E88E5);
    const Color rosaBotao = Color(0xFFD81B60);
    const Color fundoTela = Color(0xFFF3F0F6); // Fundo claro levemente arroxeado/cinza da imagem

    return Scaffold(
      backgroundColor: fundoTela,
      appBar: AppBar(
        backgroundColor: azulPrincipal,
        elevation: 0,
        toolbarHeight: 90, // Altura um pouco maior para bater com o design
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
          // "Pílula" de pontuação (Streak)
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
                  color: Colors.deepOrange, // Cor do foguinho
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Texto de Boas-vindas / Chamada
            const Text(
              'Faça seu treino diário e\naumente seu rank!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azulPrincipal,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.2,
                letterSpacing: 0.5,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Grid de opções de Jogos
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.85, // Deixa os cards ligeiramente mais altos do que largos
                children: [
                  _buildGameCard(
                    titulo: 'Jogo da Memória',
                    icone: Icons.psychology_outlined,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                  ),
                  _buildGameCard(
                    titulo: 'Quebra-cabeça',
                    icone: Icons.extension_outlined,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                  ),
                  _buildGameCard(
                    titulo: 'Palavra Certa',
                    icone: Icons.edit_document,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                  ),
                  _buildGameCard(
                    titulo: 'Genius',
                    icone: Icons.pie_chart_outline, // Representa o círculo colorido
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método auxiliar para criar os botões/cards dos jogos
  Widget _buildGameCard({
    required String titulo,
    required IconData icone,
    required Color corFundoIcone,
    required Color corTextoBorda,
  }) {
    return InkWell(
      onTap: () {
        // Ação ao clicar no card do jogo
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: corTextoBorda, // Borda azul fina igual da imagem
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Círculo rosa com o ícone dentro
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: corFundoIcone,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icone,
                  color: Colors.white, // Ícone branco no lugar do vetor complexo
                  size: 48,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Título do Card
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: corTextoBorda,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}