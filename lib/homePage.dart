import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profilePage.dart';
import 'main.dart'; // Para redirecionamento no logout
import 'backgroundMusic.dart';
import 'memoryGamePage.dart';

void main() {
  runApp(const SinapseApp());
}

class SinapseApp extends StatelessWidget {
  const SinapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sinapse',
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _streak = 0;
  String _nome = 'Carregando...';
  String _email = '';
  bool _isCasual = false;
  String _avatarKey = 'psychology';
  int? _bestScoreMemory;
  bool _isGuest = true;
  bool _isLoading = true;

  static const Map<String, IconData> avatarIcons = {
    'psychology': Icons.psychology,
    'star': Icons.star,
    'extension': Icons.extension,
    'satisfied': Icons.sentiment_very_satisfied,
    'lightbulb': Icons.lightbulb,
    'trophy': Icons.emoji_events,
    'rocket': Icons.rocket_launch,
    'gaming': Icons.sports_esports,
    'book': Icons.menu_book,
    'flash': Icons.flash_on,
    'favorite': Icons.favorite,
    'pets': Icons.pets,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Busca as informações em tempo real no banco do Supabase
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _streak = 0;
        _nome = 'Convidado';
        _email = 'Modo de visualização';
        _isCasual = false;
        _avatarKey = 'psychology';
        _isGuest = true;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('streak, name, is_casual, avatar, best_score_memory')
          .eq('id', user.id)
          .single();

      setState(() {
        _streak = data['streak'] as int? ?? 0;
        _nome = data['name'] as String? ?? 'Usuário Sinapse';
        _email = user.email ?? '';
        _isCasual = data['is_casual'] as bool? ?? false;
        _avatarKey = data['avatar'] as String? ?? 'psychology';
        _bestScoreMemory = data['best_score_memory'] as int?;
        _isGuest = false;
      });
    } catch (e) {
      debugPrint('Erro ao obter perfil na HomePage: $e');
      setState(() {
        _nome = 'Usuário Sinapse';
        _email = user.email ?? '';
        _isCasual = false;
        _avatarKey = 'psychology';
        _bestScoreMemory = null;
        _isGuest = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Faz o logout limpo e direciona de volta à tela de login
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color azulPrincipal = Color(0xFF1565C0);
    const Color azulBorda = Color(0xFF1E88E5);
    const Color rosaBotao = Color(0xFFD81B60);
    const Color fundoTela = Color(0xFFF3F0F6);

    return Scaffold(
      backgroundColor: fundoTela,
      appBar: AppBar(
        backgroundColor: azulPrincipal,
        elevation: 0,
        toolbarHeight: 90,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 40),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        actions: [
          // Exibe o contador real de ofensivas (streak) apenas se NÃO for casual
          if (!_isCasual)
            InkWell(
              onTap: _loadProfile, // Permite clicar para recarregar
              borderRadius: BorderRadius.circular(24),
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
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
                    _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(azulPrincipal),
                            ),
                          )
                        : Text(
                            _streak.toString(),
                            style: const TextStyle(
                              color: azulPrincipal,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Menu lateral interativo premium
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [azulPrincipal, Color(0xFF0D47A1)],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  _isGuest
                      ? Icons.person_outline
                      : (avatarIcons[_avatarKey] ?? Icons.psychology),
                  size: 40,
                  color: azulPrincipal,
                ),
              ),
              accountName: Text(
                _nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(_email),
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined, color: azulPrincipal),
              title: const Text('Treino Diário (Jogos)', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: azulPrincipal),
              title: const Text('Configurações do Perfil', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.of(context).pop(); // fecha drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ).then((_) {
                  // Quando voltar da ProfilePage, recarrega o streak atualizado!
                  _loadProfile();
                });
              },
            ),
            const Spacer(),
            const Divider(),
            
            // Controle de música de fundo interativo no Drawer
            StatefulBuilder(
              builder: (context, setDrawerState) {
                final bgMusic = BackgroundMusic();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.music_note, color: azulPrincipal, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Música de Fundo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: azulPrincipal,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              bgMusic.isMuted
                                  ? Icons.volume_off
                                  : (bgMusic.volume == 0.0
                                      ? Icons.volume_mute
                                      : (bgMusic.volume < 0.5
                                          ? Icons.volume_down
                                          : Icons.volume_up)),
                              color: azulPrincipal,
                            ),
                            onPressed: () async {
                              await bgMusic.toggleMute();
                              setDrawerState(() {});
                            },
                          ),
                          Expanded(
                            child: Slider(
                              value: bgMusic.isMuted ? 0.0 : bgMusic.volume,
                              min: 0.0,
                              max: 1.0,
                              activeColor: azulPrincipal,
                              inactiveColor: azulPrincipal.withAlpha((255 * 0.2).round()),
                              onChanged: (value) async {
                                if (bgMusic.isMuted) {
                                  await bgMusic.toggleMute();
                                }
                                await bgMusic.setVolume(value);
                                setDrawerState(() {});
                              },
                            ),
                          ),
                          Text(
                            '${((bgMusic.isMuted ? 0.0 : bgMusic.volume) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),

            ListTile(
              leading: Icon(
                _isGuest ? Icons.login : Icons.logout,
                color: _isGuest ? Colors.green : Colors.redAccent,
              ),
              title: Text(
                _isGuest ? 'Fazer Login' : 'Sair da Conta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isGuest ? Colors.green : Colors.redAccent,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Faça seu treino diário e\naumente seu rank!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azulPrincipal,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 35),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.88,
                children: [
                  _buildGameCard(
                    titulo: 'Jogo da Memória',
                    icone: Icons.psychology_outlined,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                    recordeText: _bestScoreMemory != null ? '$_bestScoreMemory jogadas' : '--',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MemoryGamePage()),
                      ).then((_) {
                        _loadProfile();
                      });
                    },
                  ),
                  _buildGameCard(
                    titulo: 'Quebra-cabeça',
                    icone: Icons.extension_outlined,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                    recordeText: '--',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve: Jogo de Quebra-cabeça!')),
                      );
                    },
                  ),
                  _buildGameCard(
                    titulo: 'Palavra Certa',
                    icone: Icons.edit_document,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                    recordeText: '--',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve: Jogo de Palavra Certa!')),
                      );
                    },
                  ),
                  _buildGameCard(
                    titulo: 'Genius',
                    icone: Icons.pie_chart_outline,
                    corFundoIcone: rosaBotao,
                    corTextoBorda: azulBorda,
                    recordeText: '--',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve: Jogo Genius!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required String titulo,
    required IconData icone,
    required Color corFundoIcone,
    required Color corTextoBorda,
    required String recordeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: corTextoBorda, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                color: corFundoIcone,
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icone, color: Colors.white, size: 40)),
            ),
            const SizedBox(height: 10),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: corTextoBorda,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Recorde: $recordeText',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
