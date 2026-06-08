import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'homePage.dart';
import 'backgroundMusic.dart';
import 'notificationService.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa notificações locais
  await NotificationService().init();

  // Inicializa a música de fundo
  final bgMusic = BackgroundMusic();
  await bgMusic.init();

  // Inicialização segura das variáveis de ambiente e Supabase
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "Aviso: Arquivo .env não encontrado. Certifique-se de criá-lo na raiz.",
    );
  }

  final supabaseUrl =
      dotenv.env['SUPABASE_URL'] ?? 'https://SEU_PROJECT_ID.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'ANON_KEY';

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

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
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackgroundMusic().play();
    });

    // Aguarda 3 segundos e verifica a sessão ativa do Supabase
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // Usuário logado -> vai direto para HomePage
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          // Usuário deslogado -> vai para a tela de Login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF42A5F5),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.psychology_rounded, size: 100, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Sinapse',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Jogue, aprenda, compartilhe!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// Login Page (Atualizada com Cadastro e Supabase Auth)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();

  bool _senhaVisivel = false;
  bool _isCadastro = false; // Alterna entre login e cadastro
  bool _isLoading = false; // Indicador de carregamento

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    _usuarioController.dispose();
    super.dispose();
  }

  void _mostrarMensagem(String mensagem, {bool erro = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro
            ? const Color(0xFFD81B60)
            : const Color(0xFF2E7D32),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Método para autenticar usuário
  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _mostrarMensagem('Por favor, preencha todos os campos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      if (mounted) {
        _mostrarMensagem('Bem-vindo de volta ao Sinapse!', erro: false);
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } on AuthException catch (e) {
      _mostrarMensagem(e.message);
    } catch (e) {
      _mostrarMensagem('Ocorreu um erro inesperado: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Método para criar nova conta
  Future<void> _fazerCadastro() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();
    final nome = _nomeController.text.trim();
    final usuario = _usuarioController.text.trim();

    if (email.isEmpty || senha.isEmpty || nome.isEmpty || usuario.isEmpty) {
      _mostrarMensagem('Por favor, preencha todos os campos do cadastro.');
      return;
    }

    if (senha.length < 6) {
      _mostrarMensagem('A senha deve conter no mínimo 6 caracteres.');
      return;
    }

    if (usuario.length < 3) {
      _mostrarMensagem('O nome de usuário deve conter no mínimo 3 caracteres.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cria a conta de autenticação passando nome e username como metadata
      // O trigger do banco fará o resto inserindo automaticamente em public.profiles
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: senha,
        data: {
          'name': nome,
          'username': usuario.replaceAll(
            '@',
            '',
          ),
        },
      );

      if (mounted) {
        _mostrarMensagem(
          'Cadastro realizado com sucesso! Faça login.',
          erro: false,
        );
        setState(() {
          _isCadastro = false;
          _senhaController.clear();
        });
      }
    } on AuthException catch (e) {
      _mostrarMensagem(e.message);
    } catch (e) {
      _mostrarMensagem('Ocorreu um erro inesperado: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color botaoColor = Color(0xFFD81B60);
    const Color bordaColor = Color(0xFF1E88E5);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isCadastro ? 'Criar Conta' : 'Login',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Sobre o Sinapse',
            onPressed: () {
              _mostrarMensagem(
                'Sinapse — Desenvolva sua memória jogando!',
                erro: false,
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF42A5F5),
              Color(0xFF0D47A1),
            ],
          ),
        ),

        child: SingleChildScrollView(
          child: Column(
            children: [
              // Cabeçalho branco com logo curva premium
              Container(
                width: double.infinity,
                height: 250,
                padding: const EdgeInsets.only(bottom: 24, top: 70),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(200),
                    bottomRight: Radius.circular(200),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.psychology_rounded,
                      size: 48,
                      color: Color(0xFF1565C0),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sinapse',
                      style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Jogue, aprenda, compartilhe!',
                      style: TextStyle(color: Color(0xFF1E88E5), fontSize: 16),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // Campos adicionais exclusivos de CADASTRO
                    if (_isCadastro) ...[
                      const Text(
                        'Nome Completo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nomeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          hint: 'Como deseja ser chamado',
                          icon: Icons.person_outline,
                          bordaColor: bordaColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Nome de Usuário (@)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usuarioController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          hint: 'ex: joao_silva',
                          icon: Icons.alternate_email_outlined,
                          bordaColor: bordaColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'E-mail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration(
                        hint: 'exemplo@email.com',
                        icon: Icons.email_outlined,
                        bordaColor: bordaColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Senha',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _senhaController,
                      obscureText: !_senhaVisivel,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        bordaColor: bordaColor,
                        suffix: IconButton(
                          icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _senhaVisivel = !_senhaVisivel;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botão Principal (Entrar / Cadastrar) com Loader
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_isCadastro ? _fazerCadastro : _fazerLogin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: botaoColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _isCadastro ? 'Registrar Conta' : 'Entrar',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Alternador Login <-> Cadastro
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isCadastro = !_isCadastro;
                              });
                            },
                      child: Text(
                        _isCadastro
                            ? 'Já possui uma conta? Entre aqui'
                            : 'Não tem uma conta? Cadastre-se gratuitamente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white38, thickness: 1),
                    const SizedBox(height: 16),

                    // Botão Entrar como convidado (Modo offline com sessão nula)
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _mostrarMensagem(
                                'Acessando como convidado. Seu progresso não será salvo online.',
                                erro: false,
                              );
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomePage(),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: const BorderSide(
                          color: Colors.white30,
                          width: 1.5,
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Entrar como convidado',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar de design para os campos de input
  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required Color bordaColor,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bordaColor, width: 1.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      filled: true,
      fillColor: Colors.white12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
