import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isFirebaseAvailable = false;

  // Inicializar Firebase Auth se disponível
  void _initializeAuth() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _isFirebaseAvailable = true;
      } else {
        _isFirebaseAvailable = false;
        _auth = null;
      }
    } catch (e) {
      _isFirebaseAvailable = false;
      _auth = null;
    }
  }

  // Stream para monitorar mudanças no estado de autenticação
  Stream<User?> get authStateChanges {
    _initializeAuth();
    if (_isFirebaseAvailable && _auth != null) {
      return _auth!.authStateChanges();
    }
    // Retornar stream vazio se Firebase não disponível
    return Stream.value(null);
  }

  // Usuário atual
  User? get currentUser {
    _initializeAuth();
    return _isFirebaseAvailable && _auth != null ? _auth!.currentUser : null;
  }

  // Verificar se o usuário está logado
  bool get isLoggedIn => currentUser != null;

  // Verificar se é o primeiro login do usuário
  Future<bool> isFirstLogin(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'first_login_${user.uid}';
      final isFirst = !prefs.containsKey(key);
      
      if (isFirst) {
        await prefs.setBool(key, false);
      }
      
      return isFirst;
    } catch (e) {
      // Se houver erro, considerar como primeiro login para garantir permissões
      return true;
    }
  }

  // Login com email e senha
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _initializeAuth();
    
    if (!_isFirebaseAvailable || _auth == null) {
      throw AuthException('Firebase não está disponível. Use o modo offline.');
    }
    
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro inesperado. Tente novamente.');
    }
  }

  // Cadastro com email e senha
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _initializeAuth();
    
    if (!_isFirebaseAvailable || _auth == null) {
      throw AuthException('Firebase não está disponível. Use o modo offline.');
    }
    
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Atualizar o nome do usuário
      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName.trim());
        await credential.user!.reload();
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro inesperado. Tente novamente.');
    }
  }

  // Login com Google
  Future<UserCredential?> signInWithGoogle() async {
    _initializeAuth();
    
    if (!_isFirebaseAvailable || _auth == null) {
      throw AuthException('Firebase não está disponível. Use o modo offline.');
    }
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Usuário cancelou o login
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      throw AuthException('Erro ao fazer login com Google. Tente novamente.');
    }
  }

  // Logout
  Future<void> signOut() async {
    _initializeAuth();
    
    try {
      List<Future> signOutTasks = [];
      
      if (_isFirebaseAvailable && _auth != null) {
        signOutTasks.add(_auth!.signOut());
      }
      
      signOutTasks.add(_googleSignIn.signOut());
      
      await Future.wait(signOutTasks);
    } catch (e) {
      throw AuthException('Erro ao fazer logout. Tente novamente.');
    }
  }

  // Enviar email de recuperação de senha
  Future<void> sendPasswordResetEmail(String email) async {
    _initializeAuth();
    
    if (!_isFirebaseAvailable || _auth == null) {
      throw AuthException('Firebase não está disponível. Use o modo offline.');
    }
    
    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro ao enviar email de recuperação.');
    }
  }

  // Atualizar perfil do usuário
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
        await user.reload();
      }
    } catch (e) {
      throw AuthException('Erro ao atualizar perfil.');
    }
  }

  // Verificar se o email foi verificado
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Enviar email de verificação
  Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
    } catch (e) {
      throw AuthException('Erro ao enviar email de verificação.');
    }
  }

  // Reautenticar usuário (necessário para operações sensíveis)
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = currentUser;
      if (user?.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro ao reautenticar.');
    }
  }

  // Alterar senha
  Future<void> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro ao alterar senha.');
    }
  }

  // Deletar conta
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Erro ao deletar conta.');
    }
  }

  // Obter token de ID do usuário
  Future<String?> getIdToken() async {
    try {
      return await currentUser?.getIdToken();
    } catch (e) {
      return null;
    }
  }

  // Converter códigos de erro para mensagens amigáveis
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado. Verifique o email.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente.';
      case 'invalid-email':
        return 'Email inválido. Verifique o formato.';
      case 'user-disabled':
        return 'Esta conta foi desabilitada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      case 'email-already-in-use':
        return 'Este email já está em uso. Tente fazer login.';
      case 'operation-not-allowed':
        return 'Operação não permitida. Contate o suporte.';
      case 'invalid-credential':
        return 'Credenciais inválidas. Verifique os dados.';
      case 'account-exists-with-different-credential':
        return 'Conta já existe com credencial diferente.';
      case 'requires-recent-login':
        return 'Esta operação requer login recente. Faça login novamente.';
      case 'provider-already-linked':
        return 'Provedor já está vinculado a esta conta.';
      case 'no-such-provider':
        return 'Provedor não encontrado para esta conta.';
      case 'invalid-user-token':
        return 'Token de usuário inválido. Faça login novamente.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      case 'user-token-expired':
        return 'Sessão expirada. Faça login novamente.';
      default:
        return 'Erro de autenticação. Tente novamente.';
    }
  }
}

// Classe para exceções de autenticação
class AuthException implements Exception {
  final String message;
  
  const AuthException(this.message);
  
  @override
  String toString() => message;
}

