import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/payment/payment_screen.dart';
import 'screens/reading_entry/reading_entry_screen.dart';
import 'screens/supplier_form/supplier_form_screen.dart';
import 'screens/suppliers_list/suppliers_list_screen.dart';

/// Маршруты go_router (полная схема — ТЗ, Этап 2.5 плана). Пока подключена
/// только тончайшая сквозная связка Этапа 3.5 (MVP): /login, /suppliers,
/// /suppliers/new, /suppliers/:id/reading, /suppliers/:id/payment/:paymentId.
/// Остальные маршруты из схемы 2.5 — /register, /suppliers/:id (карточка),
/// .../edit, /suppliers/:id/history, /history, /reports, /settings, а
/// вместе с ними нижняя навигация (StatefulShellRoute на 4 раздела) —
/// Этап 4: сейчас за ними стояли бы экраны-заглушки, а не функциональность.
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/suppliers',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final loggedIn = authService.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/suppliers';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersListScreen(),
      ),
      GoRoute(
        path: '/suppliers/new',
        builder: (context, state) => const SupplierFormScreen(),
      ),
      GoRoute(
        path: '/suppliers/:id/reading',
        builder: (context, state) => ReadingEntryScreen(
          supplierId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/suppliers/:id/payment/:paymentId',
        builder: (context, state) => PaymentScreen(
          supplierId: state.pathParameters['id']!,
          paymentId: state.pathParameters['paymentId']!,
        ),
      ),
    ],
  );
});

/// Мост между Stream (Supabase authStateChanges) и Listenable, которого
/// просит go_router для повторного вычисления redirect при входе/выходе —
/// стандартный приём из документации go_router.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
