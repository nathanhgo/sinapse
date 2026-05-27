import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profilePage.dart';
import 'memoryGamePage.dart';
import 'wordGamePage.dart';
import 'theme.dart';

void main() {
  runApp(const SinapseApp());
}

class SinapseApp extends StatelessWidget {
  const SinapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sinapse',
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1565C0),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF3F0F6),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D1B2A),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF050B14),
            useMaterial3: true,
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _streak = 0;
  bool _isCasual = false;
  int? _bestScoreMemory;
  int? _bestScoreWord;
  bool _isLoading = true;

  // Sistema de Amizades, Notificações e Rankings
  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;
  String _rankingContext = 'global'; // 'global' ou 'amigos'
  String _rankingCriterion = 'streak'; // 'streak', 'memory', 'word'
  List<Map<String, dynamic>> _rankingList = [];
  bool _isLoadingRanking = false;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Busca as informações em tempo real no banco do Supabase e valida a validade do streak
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _streak = 0;
        _isCasual = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> data;
      try {
        data = await Supabase.instance.client
            .from('profiles')
            .select('streak, name, is_casual, avatar, best_score_memory, best_score_word, last_play_date')
            .eq('id', user.id)
            .single();
      } catch (e) {
        debugPrint('Aviso: Falha ao buscar best_score_word, tentando sem a coluna: $e');
        data = await Supabase.instance.client
            .from('profiles')
            .select('streak, name, is_casual, avatar, best_score_memory, last_play_date')
            .eq('id', user.id)
            .single();
      }

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
            debugPrint('Erro ao resetar streak expirada na HomePage: $e');
          }
        }
      }

      setState(() {
        _streak = streakFromDb;
        _isCasual = data['is_casual'] as bool? ?? false;
        _bestScoreMemory = data['best_score_memory'] as int?;
        _bestScoreWord = data.containsKey('best_score_word') ? data['best_score_word'] as int? : null;
      });
      _loadRanking();
      _loadPendingRequestsCount();
    } catch (e) {
      debugPrint('Erro ao obter perfil na HomePage: $e');
      setState(() {
        _isCasual = false;
        _bestScoreMemory = null;
        _bestScoreWord = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- MÉTODOS DE CONTROLE DO SISTEMA DE AMIGOS E RANKINGS ---

  Future<void> _loadPendingRequestsCount() async {
    if (_isGuest) return;
    try {
      final count = await _getPendingRequestsCount();
      setState(() {
        _pendingRequestsCount = count;
      });
    } catch (e) {
      debugPrint('Erro ao obter contagem de notificações: $e');
    }
  }

  Future<int> _getPendingRequestsCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;
    final data = await Supabase.instance.client
        .from('friendships')
        .select('id')
        .eq('receiver_id', userId)
        .eq('status', 'pending');
    return data.length;
  }

  Future<void> _loadRanking() async {
    if (_isGuest) return;
    setState(() => _isLoadingRanking = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      List<Map<String, dynamic>> list = [];

      if (_rankingContext == 'global') {
        var query = Supabase.instance.client.from('profiles').select('id, name, username, avatar, streak, best_score_memory, best_score_word');
        if (_rankingCriterion == 'streak') {
          final data = await query.order('streak', ascending: false);
          list = List<Map<String, dynamic>>.from(data);
        } else if (_rankingCriterion == 'memory') {
          final data = await query.not('best_score_memory', 'is', null).order('best_score_memory', ascending: true);
          list = List<Map<String, dynamic>>.from(data);
        } else if (_rankingCriterion == 'word') {
          try {
            final data = await query.not('best_score_word', 'is', null).order('best_score_word', ascending: true);
            list = List<Map<String, dynamic>>.from(data);
          } catch (e) {
            list = [];
          }
        }
      } else {
        // Amigos
        final friendshipsData = await Supabase.instance.client
            .from('friendships')
            .select('sender_id, receiver_id')
            .eq('status', 'accepted')
            .or('sender_id.eq.$userId,receiver_id.eq.$userId');

        final friendIds = friendshipsData.map<String>((row) {
          final s = row['sender_id'] as String;
          final r = row['receiver_id'] as String;
          return s == userId ? r : s;
        }).toList();

        friendIds.add(userId);

        var query = Supabase.instance.client
            .from('profiles')
            .select('id, name, username, avatar, streak, best_score_memory, best_score_word')
            .inFilter('id', friendIds);

        if (_rankingCriterion == 'streak') {
          final data = await query.order('streak', ascending: false);
          list = List<Map<String, dynamic>>.from(data);
        } else if (_rankingCriterion == 'memory') {
          final data = await query.not('best_score_memory', 'is', null).order('best_score_memory', ascending: true);
          list = List<Map<String, dynamic>>.from(data);
        } else if (_rankingCriterion == 'word') {
          try {
            final data = await query.not('best_score_word', 'is', null).order('best_score_word', ascending: true);
            list = List<Map<String, dynamic>>.from(data);
          } catch (e) {
            list = [];
          }
        }
      }

      setState(() {
        _rankingList = list;
      });
    } catch (e) {
      debugPrint('Erro ao carregar ranking: $e');
    } finally {
      setState(() => _isLoadingRanking = false);
    }
  }

  Future<String?> _getFriendshipStatus(String otherId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await Supabase.instance.client
        .from('friendships')
        .select('sender_id, receiver_id, status')
        .or('and(sender_id.eq.$userId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$userId)')
        .maybeSingle();

    if (data == null) return null;

    final status = data['status'] as String;
    if (status == 'accepted') return 'friends';

    final senderId = data['sender_id'] as String;
    return senderId == userId ? 'sent_pending' : 'received_pending';
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('friendships').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<void> _acceptFriendRequest(String senderId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('sender_id', senderId)
        .eq('receiver_id', userId);
  }

  Future<void> _removeFriendship(String otherId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client
        .from('friendships')
        .delete()
        .or('and(sender_id.eq.$userId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$userId)');
  }

  Future<List<Map<String, dynamic>>> _getPendingRequests() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final friendships = await Supabase.instance.client
        .from('friendships')
        .select('sender_id')
        .eq('receiver_id', userId)
        .eq('status', 'pending');

    if (friendships.isEmpty) return [];

    final senderIds = friendships.map<String>((f) => f['sender_id'] as String).toList();

    final senders = await Supabase.instance.client
        .from('profiles')
        .select('id, name, username, avatar')
        .inFilter('id', senderIds);

    return List<Map<String, dynamic>>.from(senders);
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String queryText) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || queryText.trim().isEmpty) return [];

    final data = await Supabase.instance.client
        .from('profiles')
        .select('id, name, username, avatar, streak, best_score_memory, best_score_word')
        .ilike('username', '%$queryText%')
        .neq('id', userId)
        .limit(15);

    return List<Map<String, dynamic>>.from(data);
  }

  // --- DIÁLOGOS E PÁGINAS DO SISTEMA SOCIAL ---

  Future<void> _abrirPainelNotificacoes() async {
    final isDark = isDarkModeNotifier.value;
    final dialogBg = isDark ? const Color(0xFF0D1B2A) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getPendingRequests(),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? [];
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                return AlertDialog(
                  backgroundColor: dialogBg,
                  title: Text(
                    'Solicitações de Amizade',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.azulPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: isLoading
                      ? const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : requests.isEmpty
                          ? const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text(
                                  'Nenhuma solicitação pendente.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.maxFinite,
                              height: 250,
                              child: ListView.builder(
                                itemCount: requests.length,
                                itemBuilder: (context, index) {
                                  final req = requests[index];
                                  final avatarKey = req['avatar'] as String? ?? 'psychology';
                                  final avatarIcon = ProfilePage.avatarIcons[avatarKey] ?? Icons.psychology;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.blue.shade100,
                                      child: Icon(avatarIcon, color: isDark ? Colors.white : AppColors.azulPrincipal),
                                    ),
                                    title: Text(req['name'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                    subtitle: Text('@${req['username'] ?? ""}', style: const TextStyle(color: Colors.grey)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check, color: Colors.green),
                                          onPressed: () async {
                                            await _acceptFriendRequest(req['id']);
                                            await _loadPendingRequestsCount();
                                            await _loadRanking();
                                            setDialogState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          onPressed: () async {
                                            await _removeFriendship(req['id']);
                                            await _loadPendingRequestsCount();
                                            setDialogState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                  actions: [
                    TextButton(
                      child: const Text('Fechar'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _abrirPainelPesquisa() async {
    final isDark = isDarkModeNotifier.value;
    final dialogBg = isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                'Pesquisar Usuários',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.azulPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Digite o nome de usuário...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          setDialogState(() {});
                        },
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    onSubmitted: (val) {
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _searchUsers(controller.text),
                    builder: (context, snapshot) {
                      if (controller.text.trim().isEmpty) {
                        return const SizedBox(
                          height: 150,
                          child: Center(
                            child: Text('Pesquise por nome de usuário.', style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      }

                      final results = snapshot.data ?? [];
                      final isLoading = snapshot.connectionState == ConnectionState.waiting;

                      if (isLoading) {
                        return const SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (results.isEmpty) {
                        return const SizedBox(
                          height: 150,
                          child: Center(
                            child: Text('Nenhum usuário encontrado.', style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      }

                      return SizedBox(
                        width: double.maxFinite,
                        height: 200,
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final profile = results[index];
                            final avatarKey = profile['avatar'] as String? ?? 'psychology';
                            final avatarIcon = ProfilePage.avatarIcons[avatarKey] ?? Icons.psychology;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.blue.shade100,
                                child: Icon(avatarIcon, color: isDark ? Colors.white : AppColors.azulPrincipal),
                              ),
                              title: Text(profile['name'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              subtitle: Text('@${profile['username'] ?? ""}', style: const TextStyle(color: Colors.grey)),
                              onTap: () {
                                Navigator.pop(context);
                                _mostrarDetalhePerfil(profile['id']);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Fechar'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarDetalhePerfil(String otherId) async {
    final isDark = isDarkModeNotifier.value;
    final dialogBg = isDark ? const Color(0xFF0D1B2A) : Colors.white;

    final profileData = await Supabase.instance.client
        .from('profiles')
        .select('name, username, avatar, streak, best_score_memory, best_score_word')
        .eq('id', otherId)
        .single();

    final name = profileData['name'] ?? 'Usuário';
    final username = profileData['username'] ?? '';
    final avatarKey = profileData['avatar'] as String? ?? 'psychology';
    final avatarIcon = ProfilePage.avatarIcons[avatarKey] ?? Icons.psychology;
    final streak = profileData['streak'] as int? ?? 0;
    final memoryScore = profileData['best_score_memory'] as int?;
    final wordScore = profileData.containsKey('best_score_word') ? profileData['best_score_word'] as int? : null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<String?>(
              future: _getFriendshipStatus(otherId),
              builder: (context, snapshot) {
                final status = snapshot.data;
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                Widget actionButton;
                if (isLoading) {
                  actionButton = const CircularProgressIndicator();
                } else if (status == 'friends') {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                    icon: const Icon(Icons.person_remove, color: Colors.white),
                    label: const Text('Remover Amigo', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      await _removeFriendship(otherId);
                      setModalState(() {});
                      _loadRanking();
                    },
                  );
                } else if (status == 'sent_pending') {
                  actionButton = OutlinedButton.icon(
                    icon: const Icon(Icons.hourglass_empty, color: Colors.grey),
                    label: const Text('Solicitação Pendente', style: TextStyle(color: Colors.grey)),
                    onPressed: () async {
                      await _removeFriendship(otherId);
                      setModalState(() {});
                    },
                  );
                } else if (status == 'received_pending') {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Aceitar Solicitação', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      await _acceptFriendRequest(otherId);
                      await _loadPendingRequestsCount();
                      setModalState(() {});
                      _loadRanking();
                    },
                  );
                } else {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.rosaBotao),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Adicionar Amigo', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      await _sendFriendRequest(otherId);
                      setModalState(() {});
                    },
                  );
                }

                return AlertDialog(
                  backgroundColor: dialogBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.blue.shade100,
                        child: Icon(avatarIcon, size: 40, color: isDark ? Colors.white : AppColors.azulPrincipal),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Streak', '$streak 🔥', isDark),
                          _buildStatItem('Memória', memoryScore != null ? '$memoryScore' : '-', isDark),
                          _buildStatItem('Palavras', wordScore != null ? '$wordScore' : '-', isDark),
                        ],
                      ),
                      const SizedBox(height: 20),
                      actionButton,
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Fechar'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String title, String val, bool isDark) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildRankingTab() {
    final isDark = isDarkModeNotifier.value;
    final azulPrincipal = AppColors.azulPrincipal;

    if (_isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2A47) : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Acesse sua Conta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : azulPrincipal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Para competir no Ranking, adicionar amigos e salvar seus recordes, crie uma conta ou faça login!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white60 : Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2A47) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _rankingContext = 'global';
                            });
                            _loadRanking();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _rankingContext == 'global'
                                  ? (isDark ? const Color(0xFF0D1B2A) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _rankingContext == 'global'
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Global',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.azulPrincipal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _rankingContext = 'amigos';
                            });
                            _loadRanking();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _rankingContext == 'amigos'
                                  ? (isDark ? const Color(0xFF0D1B2A) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _rankingContext == 'amigos'
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Amigos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.azulPrincipal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                    : [AppColors.azulPrincipal, const Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _abrirPainelPesquisa,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.person_add_alt_1_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Encontrar novos amigos no Sinapse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCriterionChip('streak', 'Ofensivas', Icons.local_fire_department),
              _buildCriterionChip('memory', 'Memória', Icons.star),
              _buildCriterionChip('word', 'Palavras', Icons.sort_by_alpha),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingRanking
                ? const Center(child: CircularProgressIndicator())
                : _rankingList.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum usuário no ranking.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rankingList.length,
                        itemBuilder: (context, index) {
                          return _buildRankingItem(index, _rankingList[index], currentUserId);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionChip(String key, String label, IconData icon) {
    final isDark = isDarkModeNotifier.value;
    final isSelected = _rankingCriterion == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black54),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.rosaBotao,
      backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.grey.shade200,
      onSelected: (val) {
        if (val) {
          setState(() {
            _rankingCriterion = key;
          });
          _loadRanking();
        }
      },
    );
  }

  Widget _buildRankingItem(int index, Map<String, dynamic> profile, String currentUserId) {
    final isDark = isDarkModeNotifier.value;
    final rank = index + 1;
    final isSelf = profile['id'] == currentUserId;

    Widget rankWidget;
    if (rank == 1) {
      rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 28);
    } else if (rank == 2) {
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 28);
    } else if (rank == 3) {
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 28);
    } else {
      rankWidget = Container(
        width: 28,
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    String valueStr = '';
    if (_rankingCriterion == 'streak') {
      final s = profile['streak'] as int? ?? 0;
      valueStr = '$s ${s == 1 ? "dia" : "dias"}';
    } else if (_rankingCriterion == 'memory') {
      final score = profile['best_score_memory'] as int?;
      valueStr = score != null ? '$score jogadas' : '-';
    } else if (_rankingCriterion == 'word') {
      final score = profile['best_score_word'] as int?;
      valueStr = score != null ? '$score tent.' : '-';
    }

    final avatarKey = profile['avatar'] as String? ?? 'psychology';
    final avatarIcon = ProfilePage.avatarIcons[avatarKey] ?? Icons.psychology;

    return Card(
      color: isSelf
          ? (isDark ? const Color(0xFF1F355C) : Colors.blue.shade50)
          : (isDark ? const Color(0xFF0D1B2A) : Colors.white),
      elevation: isSelf ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelf
            ? BorderSide(color: AppColors.rosaBotao, width: 2)
            : BorderSide(color: isDark ? const Color(0xFF1B2A47) : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            rankWidget,
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF1B2A47) : Colors.blue.shade100,
              child: Icon(avatarIcon, color: isDark ? Colors.white : AppColors.azulPrincipal),
            ),
          ],
        ),
        title: Text(
          profile['name'] ?? '',
          style: TextStyle(
            fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '@${profile['username'] ?? ""}',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
        trailing: Text(
          valueStr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.rosaBotao,
          ),
        ),
        onTap: () => _mostrarDetalhePerfil(profile['id']),
      ),
    );
  }

  void _mostrarSelecaoDificuldade(BuildContext context, String jogo) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = isDarkModeNotifier.value;
        final dialogBg = isDark ? const Color(0xFF1B2A47) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF1565C0);

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Escolha a Dificuldade',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: titleColor,
              fontSize: 22,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aviso: Os recordes são salvos apenas no modo Difícil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildDificuldadeOption(
                context: context,
                label: 'Fácil',
                descricao: jogo == 'memory' ? 'Tabuleiro 4x4' : 'Palavras de 5 letras',
                cor: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MemoryGamePage(difficulty: 'fácil')),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WordGamePage(difficulty: 'fácil')),
                    ).then((_) => _loadProfile());
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDificuldadeOption(
                context: context,
                label: 'Médio',
                descricao: jogo == 'memory' ? 'Tabuleiro 5x5' : 'Palavras de 7 letras',
                cor: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MemoryGamePage(difficulty: 'médio')),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WordGamePage(difficulty: 'médio')),
                    ).then((_) => _loadProfile());
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDificuldadeOption(
                context: context,
                label: 'Difícil',
                descricao: jogo == 'memory' ? 'Tabuleiro 6x6 (Recorde)' : 'Palavras de 9 letras (Recorde)',
                cor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MemoryGamePage(difficulty: 'difícil')),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WordGamePage(difficulty: 'difícil')),
                    ).then((_) => _loadProfile());
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDificuldadeOption({
    required BuildContext context,
    required String label,
    required String descricao,
    required Color cor,
    required VoidCallback onTap,
  }) {
    final isDark = isDarkModeNotifier.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1B2A) : Colors.grey.shade100,
          border: Border.all(color: cor.withOpacity(0.5), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? Colors.white60 : Colors.black54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final azulPrincipal = AppColors.azulPrincipal;
        final azulBorda = AppColors.azulBorda;
        final rosaBotao = AppColors.rosaBotao;
        final fundoTela = AppColors.fundoTela;

        // Lista de telas/widgets das abas
        final List<Widget> abas = [
          // Aba 0: Lista de Jogos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                Text(
                  'Faça seu treino diário e\naumente seu rank!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : azulPrincipal,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '⚠️ Os recordes são salvos apenas na dificuldade Difícil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
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
                          _mostrarSelecaoDificuldade(context, 'memory');
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
                        recordeText: _bestScoreWord != null ? '$_bestScoreWord tent.' : '--',
                        onTap: () {
                          _mostrarSelecaoDificuldade(context, 'wordGame');
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

          // Aba 1: Ranking
          _buildRankingTab(),

          // Aba 2: Perfil
          const ProfilePage(isTab: true),
        ];

        return Scaffold(
          backgroundColor: _currentIndex == 2 ? azulPrincipal : fundoTela,
          appBar: _currentIndex == 2
              ? null
              : AppBar(
                  backgroundColor: azulPrincipal,
                  elevation: 0,
                  toolbarHeight: 90,
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _abrirPainelNotificacoes,
                      ),
                      if (_pendingRequestsCount > 0)
                        Positioned(
                          right: 12,
                          top: 18,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$_pendingRequestsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    _currentIndex == 0 ? 'Sinapse' : 'Ranking',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  centerTitle: true,
                  actions: [
                    if (_currentIndex == 0 && !_isCasual)
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
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.azulPrincipalClaro),
                                      ),
                                    )
                                  : Text(
                                      _streak.toString(),
                                      style: const TextStyle(
                                        color: AppColors.azulPrincipalClaro,
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
          body: abas[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index == 0) {
                _loadProfile();
              }
            },
            selectedItemColor: isDark ? Colors.white : azulPrincipal,
            unselectedItemColor: isDark ? Colors.white60 : Colors.grey,
            backgroundColor: AppColors.cardFundo,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard),
                label: 'Ranking',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
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
    final isDark = isDarkModeNotifier.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardFundo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? corTextoBorda.withOpacity(0.5) : corTextoBorda, width: 1.5),
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
                color: isDark ? Colors.white : corTextoBorda,
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
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
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
