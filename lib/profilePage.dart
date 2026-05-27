import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'backgroundMusic.dart';
import 'theme.dart';

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
      home: const ProfilePage(),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final bool isTab;
  const ProfilePage({super.key, this.isTab = false});

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
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _nome = 'Carregando...';
  String _username = '@carregando';
  int _streak = 0;
  bool _isCasual = false;
  String _avatarKey = 'psychology';
  bool _isGuest = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Carrega as informações em tempo real no banco do Supabase e valida a validade do streak
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _nome = 'Convidado';
        _username = '@convidado';
        _streak = 0;
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
          .select()
          .eq('id', user.id)
          .single();

      int streakFromDb = data['streak'] as int? ?? 0;
      final lastPlayDateStr = data['last_play_date'] as String?;

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      if (lastPlayDateStr == null || (lastPlayDateStr != todayStr && lastPlayDateStr != yesterdayStr)) {
        if (streakFromDb > 0) {
          streakFromDb = 0;
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({'streak': 0})
                .eq('id', user.id);
          } catch (e) {
            debugPrint('Erro ao resetar streak expirada: $e');
          }
        }
      }

      setState(() {
        _nome = data['name'] as String? ?? 'Usuário Sinapse';
        _username = '@${data['username'] as String? ?? 'usuario'}';
        _streak = streakFromDb;
        _isCasual = data['is_casual'] as bool? ?? false;
        _avatarKey = data['avatar'] as String? ?? 'psychology';
        _isGuest = false;
      });
    } catch (e) {
      debugPrint('Erro ao obter perfil na ProfilePage: $e');
      setState(() {
        _nome = 'Usuário Sinapse';
        _username = '@usuario';
        _isCasual = false;
        _avatarKey = 'psychology';
        _isGuest = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? const Color(0xFFD81B60) : const Color(0xFF2E7D32),
      ),
    );
  }

  // Alterna o modo Casual de jogo no banco
  Future<void> _toggleModoCasual() async {
    if (_isGuest) {
      _mostrarMensagem('Você precisa estar logado para ativar o modo casual.');
      return;
    }

    final novoValor = !_isCasual;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_casual': novoValor})
            .eq('id', user.id);

        setState(() {
          _isCasual = novoValor;
        });

        _mostrarMensagem(
          novoValor ? 'Modo casual ativado com sucesso!' : 'Modo competitivo ativado!',
          erro: false,
        );
      }
    } catch (e) {
      _mostrarMensagem('Erro ao atualizar modo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Abre a paleta de seleção de Avatares usando emotes/ícones do Flutter
  Future<void> _escolherAvatar() async {
    if (_isGuest) {
      _mostrarMensagem('Você precisa estar logado para alterar o avatar.');
      return;
    }

    const Color azulPrincipal = Color(0xFF1565C0);

    final String? avatarSelecionado = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Escolha seu Avatar',
            style: TextStyle(fontWeight: FontWeight.bold, color: azulPrincipal),
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: ProfilePage.avatarIcons.length,
              itemBuilder: (context, index) {
                final key = ProfilePage.avatarIcons.keys.elementAt(index);
                final icon = ProfilePage.avatarIcons[key]!;
                final isCurrent = key == _avatarKey;

                return InkWell(
                  onTap: () => Navigator.pop(context, key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? azulPrincipal.withAlpha(25) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? azulPrincipal : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isCurrent ? azulPrincipal : Colors.grey.shade700,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );

    if (avatarSelecionado != null && avatarSelecionado != _avatarKey) {
      setState(() => _isLoading = true);
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({'avatar': avatarSelecionado})
              .eq('id', user.id);

          setState(() {
            _avatarKey = avatarSelecionado;
          });

          _mostrarMensagem('Avatar atualizado com sucesso!', erro: false);
        }
      } catch (e) {
        _mostrarMensagem('Erro ao atualizar avatar: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Diálogo para editar Nome de Exibição e Username
  Future<void> _editarPerfil() async {
    if (_isGuest) {
      _mostrarMensagem('Você precisa estar logado para editar suas informações.');
      return;
    }

    final nomeController = TextEditingController(text: _nome);
    final usuarioController = TextEditingController(text: _username.replaceFirst('@', ''));

    final bool? confirmados = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Nome de Usuário (@)',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmados == true) {
      final novoNome = nomeController.text.trim();
      final novoUsuario = usuarioController.text.trim().replaceAll('@', '');

      if (novoNome.isEmpty || novoUsuario.isEmpty) {
        _mostrarMensagem('Os campos não podem ficar vazios.');
        return;
      }

      if (novoUsuario.length < 3) {
        _mostrarMensagem('O nome de usuário deve conter no mínimo 3 caracteres.');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({
                'name': novoNome,
                'username': novoUsuario,
              })
              .eq('id', user.id);

          setState(() {
            _nome = novoNome;
            _username = '@$novoUsuario';
          });

          _mostrarMensagem('Perfil atualizado com sucesso!', erro: false);
        }
      } on PostgrestException catch (e) {
        // Trata erro de violação de chave única (username duplicado)
        if (e.code == '23505') {
          _mostrarMensagem('Este nome de usuário já está sendo utilizado.');
        } else {
          _mostrarMensagem('Erro ao atualizar: ${e.message}');
        }
      } catch (e) {
        _mostrarMensagem('Erro inesperado: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Deleta a conta chamando a RPC segura e remove a sessão local
  Future<void> _excluirConta() async {
    if (_isGuest) {
      _mostrarMensagem('Modo Convidado. Não há conta para excluir.');
      return;
    }

    final bool? confirmados = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Conta permanentemente?'),
        content: const Text(
          'Tem certeza absoluta de que deseja excluir sua conta?\n\nEsta ação é irreversível. Todos os seus dados, pontuações e ofensivas serão apagados dos nossos servidores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sim, Excluir',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmados == true) {
      setState(() => _isLoading = true);

      try {
        // Executa a função do banco que exclui o usuário Auth e o Perfil (cascade)
        await Supabase.instance.client.rpc('delete_user_account');
        
        // Limpa a sessão local no app
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          _mostrarMensagem('Sua conta foi excluída com sucesso.', erro: false);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        _mostrarMensagem('Falha ao excluir conta: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

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
    const Color rosaBotao = Color(0xFFD81B60);
    const Color vermelhoTexto = Color(0xFFB71C1C);

    return Scaffold(
      backgroundColor: azulPrincipal, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        toolbarHeight: 90,
        leading: widget.isTab
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 40),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isDarkModeNotifier,
            builder: (context, isDark, child) {
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  isDarkModeNotifier.value = !isDark;
                },
              );
            },
          ),
          if (!_isCasual)
            Container(
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
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Círculo com ícone premium do Avatar do usuário (tappable)
              GestureDetector(
                onTap: _escolherAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        ProfilePage.avatarIcons[_avatarKey] ?? Icons.psychology,
                        size: 60,
                        color: azulPrincipal,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: rosaBotao,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Nome completo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Nome de usuário (@username)
              Text(
                _username,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 30),

              // Controle de Música de Fundo
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.music_note, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Música de Fundo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setStateMusic) {
                        final bgMusic = BackgroundMusic();
                        return Row(
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
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                await bgMusic.toggleMute();
                                setStateMusic(() {});
                              },
                            ),
                            Expanded(
                              child: Slider(
                                value: bgMusic.isMuted ? 0.0 : bgMusic.volume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                                onChanged: (value) async {
                                  if (bgMusic.isMuted) {
                                    await bgMusic.toggleMute();
                                  }
                                  await bgMusic.setVolume(value);
                                  setStateMusic(() {});
                                },
                              ),
                            ),
                            Text(
                              '${((bgMusic.isMuted ? 0.0 : bgMusic.volume) * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Lista de Botões de Ação
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  children: [
                    _buildButton(
                      text: _isCasual ? 'Desativar modo casual' : 'Ativar modo casual',
                      backgroundColor: _isCasual ? Colors.white30 : rosaBotao,
                      textColor: Colors.white,
                      onPressed: _toggleModoCasual,
                    ),
                    const SizedBox(height: 20),
                    _buildButton(
                      text: 'Editar Perfil',
                      backgroundColor: rosaBotao,
                      textColor: Colors.white,
                      onPressed: _editarPerfil,
                    ),
                    const SizedBox(height: 20),
                    _buildButton(
                      text: _isGuest ? 'Fazer Login' : 'Sair da Conta',
                      backgroundColor: _isGuest ? Colors.green : Colors.orangeAccent.shade700,
                      textColor: Colors.white,
                      onPressed: _logout,
                    ),
                    const SizedBox(height: 40),
                    _buildButton(
                      text: 'Excluir conta',
                      backgroundColor: Colors.white,
                      textColor: vermelhoTexto,
                      onPressed: _excluirConta,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para criar os botões premium
  Widget _buildButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        disabledBackgroundColor: backgroundColor.withAlpha((255 * 0.6).round()),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 3,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
