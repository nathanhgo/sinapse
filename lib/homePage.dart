import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profilePage.dart';
import 'avatarWidget.dart';
import 'memoryGamePage.dart';
import 'wordGamePage.dart';
import 'geniusGamePage.dart';
import 'puzzleGamePage.dart';
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
  int? _bestScoreGenius;
  int? _bestScorePuzzle;
  String? _lastPlayDate;
  bool _isLoading = true;

  // Sistema de Amizades, Notificações e Rankings
  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;
  String _rankingContext = 'global'; // 'global' ou 'amigos'
  String _rankingCriterion = 'streak'; // 'streak', 'memory', 'word', 'genius'
  List<Map<String, dynamic>> _rankingList = [];
  bool _isLoadingRanking = false;
  int _pendingRequestsCount = 0;

  // Sistema de Atualização via GitHub
  String? _latestVersionName;
  String? _latestVersionUrl;
  bool _hasUpdateAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkForUpdates();
  }

  // Compara se latest (do GitHub) é mais recente que current (do app)
  bool _isVersionNewer(String current, String latest) {
    // Limpa prefixos como 'v' ou 'V'
    String cleanCurrent = current.replaceAll(RegExp(r'^[vV]'), '');
    String cleanLatest = latest.replaceAll(RegExp(r'^[vV]'), '');

    // Divide a versão e o build number (ex: 1.0.0+2 -> ['1.0.0', '2'])
    List<String> currentParts = cleanCurrent.split('+');
    List<String> latestParts = cleanLatest.split('+');

    String currentSemver = currentParts[0];
    String latestSemver = latestParts[0];

    List<int> currentNums = currentSemver.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestNums = latestSemver.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Garante que ambos tenham pelo menos 3 partes (major, minor, patch)
    while (currentNums.length < 3) {
      currentNums.add(0);
    }
    while (latestNums.length < 3) {
      latestNums.add(0);
    }

    // Compara major, minor, patch
    for (int i = 0; i < 3; i++) {
      if (latestNums[i] > currentNums[i]) return true;
      if (latestNums[i] < currentNums[i]) return false;
    }

    // Se o semver for idêntico, compara o build number (se disponível)
    int currentBuild = currentParts.length > 1 ? (int.tryParse(currentParts[1]) ?? 0) : 0;
    int latestBuild = latestParts.length > 1 ? (int.tryParse(latestParts[1]) ?? 0) : 0;

    return latestBuild > currentBuild;
  }

  Future<void> _checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/nathanhgo/sinapse/releases/latest'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestVersion = json['tag_name'] as String;
        final htmlUrl = 'https://github.com/nathanhgo/sinapse/releases/tag/$latestVersion';

        if (_isVersionNewer(currentVersion, latestVersion)) {
          setState(() {
            _latestVersionName = latestVersion;
            _latestVersionUrl = htmlUrl;
            _hasUpdateAvailable = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar atualizações: $e');
    }
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
            .select(
              'streak, name, is_casual, avatar, best_score_memory, best_score_word, best_score_genius, best_score_puzzle, last_play_date',
            )
            .eq('id', user.id)
            .single();
      } catch (e) {
        debugPrint(
          'Aviso: Falha ao buscar best_score_word/genius/puzzle, tentando fallback com menos colunas: $e',
        );
        try {
          data = await Supabase.instance.client
              .from('profiles')
              .select(
                'streak, name, is_casual, avatar, best_score_memory, best_score_word, best_score_genius, last_play_date',
              )
              .eq('id', user.id)
              .single();
        } catch (ex) {
          data = await Supabase.instance.client
              .from('profiles')
              .select(
                'streak, name, is_casual, avatar, best_score_memory, last_play_date',
              )
              .eq('id', user.id)
              .single();
        }
      }

      int streakFromDb = data['streak'] as int? ?? 0;
      final lastPlayDateStr = data['last_play_date'] as String?;

      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      if (lastPlayDateStr == null ||
          (lastPlayDateStr != todayStr && lastPlayDateStr != yesterdayStr)) {
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
        _lastPlayDate = lastPlayDateStr;
        _isCasual = data['is_casual'] as bool? ?? false;
        _bestScoreMemory = data['best_score_memory'] as int?;
        _bestScoreWord = data.containsKey('best_score_word')
            ? data['best_score_word'] as int?
            : null;
        _bestScoreGenius = data.containsKey('best_score_genius')
            ? data['best_score_genius'] as int?
            : null;
        _bestScorePuzzle = data.containsKey('best_score_puzzle')
            ? data['best_score_puzzle'] as int?
            : null;
      });
      _loadRanking();
      _loadPendingRequestsCount();
    } catch (e) {
      debugPrint('Erro ao obter perfil na HomePage: $e');
      setState(() {
        _isCasual = false;
        _bestScoreMemory = null;
        _bestScoreWord = null;
        _bestScoreGenius = null;
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
        List<dynamic> data = [];
        try {
          var query = Supabase.instance.client
              .from('profiles')
              .select(
                'id, name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius, best_score_puzzle',
              );
          if (_rankingCriterion == 'streak') {
            data = await query.order('streak', ascending: false);
          } else if (_rankingCriterion == 'memory') {
            data = await query
                .not('best_score_memory', 'is', null)
                .order('best_score_memory', ascending: true);
          } else if (_rankingCriterion == 'word') {
            data = await query
                .not('best_score_word', 'is', null)
                .order('best_score_word', ascending: true);
          } else if (_rankingCriterion == 'genius') {
            data = await query
                .not('best_score_genius', 'is', null)
                .order('best_score_genius', ascending: false);
          } else if (_rankingCriterion == 'puzzle') {
            data = await query
                .not('best_score_puzzle', 'is', null)
                .order('best_score_puzzle', ascending: true);
          }
        } catch (e) {
          // Fallback se colunas extras não existirem
          try {
            var query = Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius',
                );
            if (_rankingCriterion == 'streak') {
              data = await query.order('streak', ascending: false);
            } else if (_rankingCriterion == 'memory') {
              data = await query
                  .not('best_score_memory', 'is', null)
                  .order('best_score_memory', ascending: true);
            } else if (_rankingCriterion == 'word') {
              data = await query
                  .not('best_score_word', 'is', null)
                  .order('best_score_word', ascending: true);
            } else if (_rankingCriterion == 'genius') {
              data = await query
                  .not('best_score_genius', 'is', null)
                  .order('best_score_genius', ascending: false);
            } else {
              data = await query.order('streak', ascending: false);
            }
          } catch (ex) {
            var query = Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, username, avatar, streak, best_score_memory, best_score_word',
                );
            if (_rankingCriterion == 'streak') {
              data = await query.order('streak', ascending: false);
            } else if (_rankingCriterion == 'memory') {
              data = await query
                  .not('best_score_memory', 'is', null)
                  .order('best_score_memory', ascending: true);
            } else {
              try {
                data = await query
                    .not('best_score_word', 'is', null)
                    .order('best_score_word', ascending: true);
              } catch (_) {
                var fallbackQuery = Supabase.instance.client
                    .from('profiles')
                    .select(
                      'id, name, username, avatar, streak, best_score_memory',
                    );
                if (_rankingCriterion == 'memory') {
                  data = await fallbackQuery
                      .not('best_score_memory', 'is', null)
                      .order('best_score_memory', ascending: true);
                } else {
                  data = await fallbackQuery.order('streak', ascending: false);
                }
              }
            }
          }
        }
        list = List<Map<String, dynamic>>.from(data);
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

        List<dynamic> data = [];
        try {
          var query = Supabase.instance.client
              .from('profiles')
              .select(
                'id, name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius, best_score_puzzle',
              )
              .inFilter('id', friendIds);

          if (_rankingCriterion == 'streak') {
            data = await query.order('streak', ascending: false);
          } else if (_rankingCriterion == 'memory') {
            data = await query
                .not('best_score_memory', 'is', null)
                .order('best_score_memory', ascending: true);
          } else if (_rankingCriterion == 'word') {
            data = await query
                .not('best_score_word', 'is', null)
                .order('best_score_word', ascending: true);
          } else if (_rankingCriterion == 'genius') {
            data = await query
                .not('best_score_genius', 'is', null)
                .order('best_score_genius', ascending: false);
          } else if (_rankingCriterion == 'puzzle') {
            data = await query
                .not('best_score_puzzle', 'is', null)
                .order('best_score_puzzle', ascending: true);
          }
        } catch (e) {
          try {
            var query = Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius',
                )
                .inFilter('id', friendIds);

            if (_rankingCriterion == 'streak') {
              data = await query.order('streak', ascending: false);
            } else if (_rankingCriterion == 'memory') {
              data = await query
                  .not('best_score_memory', 'is', null)
                  .order('best_score_memory', ascending: true);
            } else if (_rankingCriterion == 'word') {
              data = await query
                  .not('best_score_word', 'is', null)
                  .order('best_score_word', ascending: true);
            } else if (_rankingCriterion == 'genius') {
              data = await query
                  .not('best_score_genius', 'is', null)
                  .order('best_score_genius', ascending: false);
            } else {
              data = await query.order('streak', ascending: false);
            }
          } catch (ex) {
            var query = Supabase.instance.client
                .from('profiles')
                .select(
                  'id, name, username, avatar, streak, best_score_memory, best_score_word',
                )
                .inFilter('id', friendIds);

            if (_rankingCriterion == 'streak') {
              data = await query.order('streak', ascending: false);
            } else if (_rankingCriterion == 'memory') {
              data = await query
                  .not('best_score_memory', 'is', null)
                  .order('best_score_memory', ascending: true);
            } else {
              try {
                data = await query
                    .not('best_score_word', 'is', null)
                    .order('best_score_word', ascending: true);
              } catch (_) {
                var fallbackQuery = Supabase.instance.client
                    .from('profiles')
                    .select(
                      'id, name, username, avatar, streak, best_score_memory',
                    )
                    .inFilter('id', friendIds);
                if (_rankingCriterion == 'memory') {
                  data = await fallbackQuery
                      .not('best_score_memory', 'is', null)
                      .order('best_score_memory', ascending: true);
                } else {
                  data = await fallbackQuery.order('streak', ascending: false);
                }
              }
            }
          }
        }
        list = List<Map<String, dynamic>>.from(data);
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
        .or(
          'and(sender_id.eq.$userId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$userId)',
        )
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
        .or(
          'and(sender_id.eq.$userId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$userId)',
        );
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

    final senderIds = friendships
        .map<String>((f) => f['sender_id'] as String)
        .toList();

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
        .select(
          'id, name, username, avatar, streak, best_score_memory, best_score_word',
        )
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
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                Widget contentWidget;

                if (isLoading) {
                  contentWidget = const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  final listChildren = <Widget>[];

                  // 1. Mostrar card de atualização se houver
                  if (_hasUpdateAvailable && _latestVersionName != null) {
                    listChildren.add(
                      Card(
                        color: isDark ? const Color(0xFF1E2D4A) : Colors.blue.shade50,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.blue.shade800 : Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.system_update_alt_rounded,
                                    color: isDark ? Colors.cyanAccent : AppColors.azulPrincipal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Atualização Disponível!',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.azulPrincipal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nova versão ($_latestVersionName) encontrada no GitHub.',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rosaBotao,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: const Icon(Icons.download, size: 14),
                                  label: const Text(
                                    'Baixar APK',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (_latestVersionUrl != null) {
                                      final uri = Uri.parse(_latestVersionUrl!);
                                      try {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } catch (e) {
                                        debugPrint('Erro ao abrir URL de atualização: $e');
                                        // Fallback se falhar
                                        try {
                                          await launchUrl(
                                            uri,
                                            mode: LaunchMode.platformDefault,
                                          );
                                        } catch (err) {
                                          debugPrint('Falha total ao abrir URL: $err');
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // 2. Solicitações de amizade
                  if (requests.isNotEmpty) {
                    if (_hasUpdateAvailable) {
                      listChildren.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                          child: Text(
                            'Solicitações de Amizade',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }

                    listChildren.addAll(
                      requests.map((req) {
                        final avatarKey = req['avatar'] as String? ?? 'psychology';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            avatarKey: avatarKey,
                            size: 40,
                            color: isDark ? Colors.white : AppColors.azulPrincipal,
                            backgroundColor: isDark
                                ? const Color(0xFF1B2A47)
                                : Colors.blue.shade100,
                          ),
                          title: Text(
                            req['name'] ?? '',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '@${req['username'] ?? ""}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green, size: 20),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () async {
                                  await _acceptFriendRequest(req['id']);
                                  await _loadPendingRequestsCount();
                                  await _loadRanking();
                                  setDialogState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () async {
                                  await _removeFriendship(req['id']);
                                  await _loadPendingRequestsCount();
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  } else if (listChildren.isEmpty) {
                    listChildren.add(
                      const SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(
                            'Nenhuma notificação pendente.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  contentWidget = Container(
                    width: double.maxFinite,
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: listChildren,
                      ),
                    ),
                  );
                }

                return AlertDialog(
                  backgroundColor: dialogBg,
                  title: Text(
                    'Notificações',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.azulPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: contentWidget,
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
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
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
                            child: Text(
                              'Pesquise por nome de usuário.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final results = snapshot.data ?? [];
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;

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
                            child: Text(
                              'Nenhum usuário encontrado.',
                              style: TextStyle(color: Colors.grey),
                            ),
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
                            final avatarKey =
                                profile['avatar'] as String? ?? 'psychology';

                            return ListTile(
                              leading: AvatarWidget(
                                avatarKey: avatarKey,
                                size: 40,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.azulPrincipal,
                                backgroundColor: isDark
                                    ? const Color(0xFF1B2A47)
                                    : Colors.blue.shade100,
                              ),
                              title: Text(
                                profile['name'] ?? '',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '@${profile['username'] ?? ""}',
                                style: const TextStyle(color: Colors.grey),
                              ),
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

    Map<String, dynamic> profileData;
    try {
      profileData = await Supabase.instance.client
          .from('profiles')
          .select(
            'name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius, best_score_puzzle',
          )
          .eq('id', otherId)
          .single();
    } catch (e) {
      try {
        profileData = await Supabase.instance.client
            .from('profiles')
            .select(
              'name, username, avatar, streak, best_score_memory, best_score_word, best_score_genius',
            )
            .eq('id', otherId)
            .single();
      } catch (ex) {
        profileData = await Supabase.instance.client
            .from('profiles')
            .select(
              'name, username, avatar, streak, best_score_memory, best_score_word',
            )
            .eq('id', otherId)
            .single();
      }
    }

    final name = profileData['name'] ?? 'Usuário';
    final username = profileData['username'] ?? '';
    final avatarKey = profileData['avatar'] as String? ?? 'psychology';
    final streak = profileData['streak'] as int? ?? 0;
    final memoryScore = profileData['best_score_memory'] as int?;
    final wordScore = profileData.containsKey('best_score_word')
        ? profileData['best_score_word'] as int?
        : null;
    final geniusScore = profileData.containsKey('best_score_genius')
        ? profileData['best_score_genius'] as int?
        : null;
    final puzzleScore = profileData.containsKey('best_score_puzzle')
        ? profileData['best_score_puzzle'] as int?
        : null;

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
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                Widget actionButton;
                if (isLoading) {
                  actionButton = const CircularProgressIndicator();
                } else if (status == 'friends') {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                    ),
                    icon: const Icon(Icons.person_remove, color: Colors.white),
                    label: const Text(
                      'Remover Amigo',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      await _removeFriendship(otherId);
                      setModalState(() {});
                      _loadRanking();
                    },
                  );
                } else if (status == 'sent_pending') {
                  actionButton = OutlinedButton.icon(
                    icon: const Icon(Icons.hourglass_empty, color: Colors.grey),
                    label: const Text(
                      'Solicitação Pendente',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onPressed: () async {
                      await _removeFriendship(otherId);
                      setModalState(() {});
                    },
                  );
                } else if (status == 'received_pending') {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Aceitar Solicitação',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      await _acceptFriendRequest(otherId);
                      await _loadPendingRequestsCount();
                      setModalState(() {});
                      _loadRanking();
                    },
                  );
                } else {
                  actionButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rosaBotao,
                    ),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text(
                      'Adicionar Amigo',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      await _sendFriendRequest(otherId);
                      setModalState(() {});
                    },
                  );
                }

                return AlertDialog(
                  backgroundColor: dialogBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       AvatarWidget(
                        avatarKey: avatarKey,
                        size: 72,
                        color: isDark
                            ? Colors.white
                            : AppColors.azulPrincipal,
                        backgroundColor: isDark
                            ? const Color(0xFF1B2A47)
                            : Colors.blue.shade100,
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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Streak', '$streak 🔥', isDark),
                              _buildStatItem(
                                'Memória',
                                memoryScore != null ? '$memoryScore' : '-',
                                isDark,
                              ),
                              _buildStatItem(
                                'Palavras',
                                wordScore != null ? '$wordScore' : '-',
                                isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Genius',
                                geniusScore != null ? '$geniusScore' : '-',
                                isDark,
                              ),
                              _buildStatItem(
                                'Puzzle',
                                puzzleScore != null ? '$puzzleScore' : '-',
                                isDark,
                              ),
                            ],
                          ),
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
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
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
                  color: isDark
                      ? const Color(0xFF1B2A47)
                      : Colors.amber.shade100,
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
                    color: isDark
                        ? const Color(0xFF1B2A47)
                        : Colors.grey.shade200,
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
                                  ? (isDark
                                        ? const Color(0xFF0D1B2A)
                                        : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _rankingContext == 'global'
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Global',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.azulPrincipal,
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
                                  ? (isDark
                                        ? const Color(0xFF0D1B2A)
                                        : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _rankingContext == 'amigos'
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Amigos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.azulPrincipal,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
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
                        'Adicionar novos amigos',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16),
                _buildCriterionChip(
                  'streak',
                  'Ofensivas',
                  Icons.local_fire_department,
                ),
                const SizedBox(width: 8),
                _buildCriterionChip('memory', 'Memória', Icons.star),
                const SizedBox(width: 8),
                _buildCriterionChip('word', 'Palavras', Icons.sort_by_alpha),
                const SizedBox(width: 8),
                _buildCriterionChip(
                  'genius',
                  'Genius',
                  Icons.pie_chart_outline,
                ),
                const SizedBox(width: 8),
                _buildCriterionChip(
                  'puzzle',
                  'Quebra-cabeça',
                  Icons.extension_outlined,
                ),
                const SizedBox(width: 16),
              ],
            ),
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
                      return _buildRankingItem(
                        index,
                        _rankingList[index],
                        currentUserId,
                      );
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
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
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

  Widget _buildRankingItem(
    int index,
    Map<String, dynamic> profile,
    String currentUserId,
  ) {
    final isDark = isDarkModeNotifier.value;
    final rank = index + 1;
    final isSelf = profile['id'] == currentUserId;

    Widget rankWidget;
    if (rank == 1) {
      rankWidget = const Icon(
        Icons.emoji_events,
        color: Colors.amber,
        size: 28,
      );
    } else if (rank == 2) {
      rankWidget = const Icon(
        Icons.emoji_events,
        color: Color(0xFFC0C0C0),
        size: 28,
      );
    } else if (rank == 3) {
      rankWidget = const Icon(
        Icons.emoji_events,
        color: Color(0xFFCD7F32),
        size: 28,
      );
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
    } else if (_rankingCriterion == 'genius') {
      final score = profile['best_score_genius'] as int?;
      valueStr = score != null ? '$score rodadas' : '-';
    } else if (_rankingCriterion == 'puzzle') {
      final score = profile['best_score_puzzle'] as int?;
      valueStr = score != null ? '$score mov.' : '-';
    }

    final avatarKey = profile['avatar'] as String? ?? 'psychology';

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
            : BorderSide(
                color: isDark ? const Color(0xFF1B2A47) : Colors.grey.shade200,
              ),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            rankWidget,
            const SizedBox(width: 8),
            AvatarWidget(
              avatarKey: avatarKey,
              size: 40,
              color: isDark ? Colors.white : AppColors.azulPrincipal,
              backgroundColor: isDark
                  ? const Color(0xFF1B2A47)
                  : Colors.blue.shade100,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                descricao: jogo == 'memory'
                    ? 'Tabuleiro 4x4'
                    : jogo == 'word'
                    ? 'Palavras de 5 letras'
                    : jogo == 'puzzle'
                    ? 'Quebra-cabeça 3x3 (9 peças)'
                    : '4 cores | Adiciona 1 cor por rodada',
                cor: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const MemoryGamePage(difficulty: 'fácil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'word') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WordGamePage(difficulty: 'fácil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'puzzle') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PuzzleGamePage(difficulty: 'fácil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const GeniusGamePage(difficulty: 'fácil'),
                      ),
                    ).then((_) => _loadProfile());
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDificuldadeOption(
                context: context,
                label: 'Médio',
                descricao: jogo == 'memory'
                    ? 'Tabuleiro 5x5'
                    : jogo == 'word'
                    ? 'Palavras de 7 letras'
                    : jogo == 'puzzle'
                    ? 'Quebra-cabeça 4x4 (16 peças)'
                    : '6 cores | Adiciona 2 cores por rodada',
                cor: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const MemoryGamePage(difficulty: 'médio'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'word') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WordGamePage(difficulty: 'médio'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'puzzle') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PuzzleGamePage(difficulty: 'médio'),
                      ),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const GeniusGamePage(difficulty: 'médio'),
                      ),
                    ).then((_) => _loadProfile());
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDificuldadeOption(
                context: context,
                label: 'Difícil',
                descricao: jogo == 'memory'
                    ? 'Tabuleiro 6x6 (Recorde)'
                    : jogo == 'word'
                    ? 'Palavras de 9 letras (Recorde)'
                    : jogo == 'puzzle'
                    ? 'Quebra-cabeça 5x5 (25 peças, Recorde)'
                    : '8 cores | Adiciona 3 cores por rodada (Recorde)',
                cor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  if (jogo == 'memory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const MemoryGamePage(difficulty: 'difícil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'word') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const WordGamePage(difficulty: 'difícil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else if (jogo == 'puzzle') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PuzzleGamePage(difficulty: 'difícil'),
                      ),
                    ).then((_) => _loadProfile());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const GeniusGamePage(difficulty: 'difícil'),
                      ),
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
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
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
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
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
        final now = DateTime.now();
        final todayStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final playedToday = _lastPlayDate == todayStr;

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
                    color: isDark
                        ? Colors.amber.shade200
                        : Colors.amber.shade800,
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
                        recordeText: _bestScoreMemory != null
                            ? '$_bestScoreMemory jogadas'
                            : '--',
                        onTap: () {
                          _mostrarSelecaoDificuldade(context, 'memory');
                        },
                      ),
                      _buildGameCard(
                        titulo: 'Quebra-cabeça',
                        icone: Icons.extension_outlined,
                        corFundoIcone: rosaBotao,
                        corTextoBorda: azulBorda,
                        recordeText: _bestScorePuzzle != null
                            ? '$_bestScorePuzzle mov.'
                            : '--',
                        onTap: () {
                          _mostrarSelecaoDificuldade(context, 'puzzle');
                        },
                      ),
                      _buildGameCard(
                        titulo: 'Palavra Certa',
                        icone: Icons.edit_document,
                        corFundoIcone: rosaBotao,
                        corTextoBorda: azulBorda,
                        recordeText: _bestScoreWord != null
                            ? '$_bestScoreWord tent.'
                            : '--',
                        onTap: () {
                          _mostrarSelecaoDificuldade(context, 'word');
                        },
                      ),
                      _buildGameCard(
                        titulo: 'Genius',
                        icone: Icons.pie_chart_outline,
                        corFundoIcone: rosaBotao,
                        corTextoBorda: azulBorda,
                        recordeText: _bestScoreGenius != null
                            ? '$_bestScoreGenius rodadas'
                            : '--',
                        onTap: () {
                          _mostrarSelecaoDificuldade(context, 'genius');
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
                      if (_pendingRequestsCount > 0 || _hasUpdateAvailable)
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
                              _pendingRequestsCount > 0
                                  ? '$_pendingRequestsCount'
                                  : '!',
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    if (_currentIndex == 0 && !_isCasual)
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => const StreakCalendarDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          margin: const EdgeInsets.only(right: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                              Icon(
                                Icons.local_fire_department,
                                color: playedToday
                                    ? Colors.deepOrange
                                    : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              _isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.azulPrincipalClaro,
                                            ),
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
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13223F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((255 * 0.3).round())
                : Colors.grey.withAlpha((255 * 0.15).round()),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: corFundoIcone.withAlpha((255 * 0.15).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icone, color: corFundoIcone, size: 36),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B2A47),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recordeText,
                      style: TextStyle(
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
