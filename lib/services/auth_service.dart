import 'package:supabase_flutter/supabase_flutter.dart';

/// Обёртка над Supabase Auth — вход, регистрация, выход (ТЗ §3, §4.8).
///
/// Хранение и восстановление сессии обеспечивает сам supabase_flutter
/// (локально на устройстве, под капотом): после `await Supabase.initialize(...)`
/// в main.dart сессия уже восстановлена, если она была — повторный вход
/// после перезапуска приложения не нужен, пока сессия жива.
///
/// Ошибки (неверный пароль, почта уже занята и т.п.) не перехватываются
/// здесь и здесь не переводятся на русский — это намеренная граница:
/// AuthService — честная тонкая обёртка, разбор и показ ошибок пользователю
/// сделает экран входа/регистрации на Этапе 4.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Текущий пользователь, null — если не авторизован.
  User? get currentUser => _client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Поток изменений состояния авторизации — используется в go_router
  /// redirect-логике (см. Этап 2.5 плана: нет сессии → /login, есть → /suppliers).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
