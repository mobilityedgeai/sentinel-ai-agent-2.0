import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';
import '../services/permission_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isFirebaseAvailable = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    // Verificar se Firebase está disponível
    _checkFirebaseAvailability();
  }
  
  void _checkFirebaseAvailability() {
    try {
      // Verificar se Firebase está realmente inicializado e funcionando
      if (Firebase.apps.isNotEmpty) {
        // Tentar acessar FirebaseAuth para confirmar que está funcionando
        FirebaseAuth.instance;
        setState(() {
          _isFirebaseAvailable = true;
        });
        debugPrint('Firebase disponível para autenticação');
      } else {
        setState(() {
          _isFirebaseAvailable = false;
        });
        debugPrint('Firebase não inicializado');
      }
    } catch (e) {
      setState(() {
        _isFirebaseAvailable = false;
      });
      debugPrint('Firebase não disponível: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final credential = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (credential?.user != null) {
        final user = credential!.user!;
        final isFirstLogin = await authService.isFirstLogin(user);
        
        if (isFirstLogin) {
          // Primeiro login - solicitar permissões
          await _requestPermissions();
        }
        // Navegação é automática via AuthWrapper
      }
    } on AuthException catch (e) {
      // Se Firebase não está disponível, ativar modo offline automaticamente
      if (e.message.contains('Firebase não está disponível')) {
        setState(() {
          _isFirebaseAvailable = false;
        });
        _showErrorSnackBar('Firebase indisponível. Use o botão "Entrar Offline" abaixo.');
      } else {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      _showErrorSnackBar('Erro inesperado. Tente novamente.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userCredential = await authService.signInWithGoogle();
      
      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        final isFirstLogin = await authService.isFirstLogin(user);
        
        if (isFirstLogin) {
          await _requestPermissions();
        }
        // Navegação é automática via AuthWrapper
      }
    } on AuthException catch (e) {
      // Se Firebase não está disponível, ativar modo offline automaticamente
      if (e.message.contains('Firebase não está disponível')) {
        setState(() {
          _isFirebaseAvailable = false;
        });
        _showErrorSnackBar('Firebase indisponível. Use o botão "Entrar Offline" abaixo.');
      } else {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao fazer login com Google. Tente novamente.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final permissionManager = Provider.of<PermissionManager>(context, listen: false);
      await permissionManager.requestAllPermissions();
    } catch (e) {
      // Continuar mesmo se as permissões falharem
      debugPrint('Erro ao solicitar permissões: $e');
    }
  }

  Future<void> _loginOffline() async {
    setState(() => _isLoading = true);
    
    try {
      // Simular um pequeno delay para UX
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Solicitar permissões se necessário
      await _requestPermissions();
      
      // Navegar para tela principal
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao entrar no modo offline. Tente novamente.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
              Colors.blue[500]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    elevation: 20,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo e título
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[800]!],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.security,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Text(
                            'Sentinel AI',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Telemática Inteligente',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Formulário
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Campo Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Digite seu email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Digite um email válido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Campo Senha
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Digite sua senha';
                                    }
                                    if (value.length < 6) {
                                      return 'Senha deve ter pelo menos 6 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Lembrar-me
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() => _rememberMe = value ?? false);
                                      },
                                    ),
                                    const Text('Lembrar-me'),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        // TODO: Implementar recuperação de senha
                                      },
                                      child: const Text('Esqueci a senha'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Botão Login
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _signInWithEmail,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 5,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Entrar',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Divisor
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey[400])),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'ou',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey[400])),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Botão Google
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : _signInWithGoogle,
                                    icon: Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.login, color: Colors.red);
                                      },
                                    ),
                                    label: const Text(
                                      'Continuar com Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Botão Entrar Offline (apenas se Firebase não disponível)
                                if (!_isFirebaseAvailable) ...[
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey[400])),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'ou',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey[400])),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _loginOffline,
                                      icon: const Icon(Icons.offline_bolt, size: 20),
                                      label: const Text(
                                        'Entrar Offline',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[600],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  Text(
                                    'Acesse todas as funcionalidades sem autenticação',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 24),
                                
                                // Link para registro
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Não tem uma conta? ',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Cadastre-se',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

