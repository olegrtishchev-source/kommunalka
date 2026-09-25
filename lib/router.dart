import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/payment/payment_screen.dart';
import 'screens/reading_entry/reading_entry_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/shell/main_shell_screen.dart';
import 'screens/supplier_form/supplier_form_screen.dart';
import 'screens/suppliers_list/suppliers_list_screen.dart';

/// Маршруты go_router (полная схема — ТЗ, Этап 2.5 плана). С Этапа 4, п. 4.9
/// — нижняя навигация на 4 раздела (StatefulShellRoute.indexedStack):
/// Поставщики / История / Отчёты / Настройки, каждый со своим стеком и
/// сохраняемым состоянием при переключении вкладок (см. MainShellScreen).
/// Ветка «История»/«Отчёты»/«Настройки» пока ведёт на экран-заглушку —
/// содержимое появится на соответствующих пунктах плана (4.6/4.7, 4.10,
/// 4.8). Внутри ветки «Поставщики» вложены формы (new/reading/payment) —
/// у них общий с корнем стек навигации, поэтому нижняя панель остаётся
/// видимой и на них (минимальный вариант, без отдельного полноэкранного
/// ShellRoute — пересмотрим, если на практике будет визуально мешать).
/// /register, /suppliers/:id (карточка поставщика), .../edit,
/// /suppliers/:id/history — остальные пункты Этапа 4 (4.1, 4.2, 4.6).
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/suppliers',
                builder: (context, state) => const SuppliersListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const SupplierFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/reading',
                    builder: (context, state) => ReadingEntryScreen(
                      supplierId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/payment/:paymentId',
                    builder: (context, state) => PaymentScreen(
                      supplierId: state.pathParameters['id']!,
                      paymentId: state.pathParameters['paymentId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
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
