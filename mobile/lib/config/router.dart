import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/entities/entities_screen.dart';
import '../screens/entities/create_entity_screen.dart';
import '../screens/entities/edit_entity_screen.dart';
import '../screens/shift/start_shift_screen.dart';
import '../screens/shift/active_shift_screen.dart';
import '../screens/shift/end_shift_screen.dart';
import '../screens/shift/shift_summary_screen.dart';
import '../screens/shift/edit_commissions_screen.dart';
import '../screens/shift/pending_deliveries_screen.dart';
import '../screens/movements/movement_form_screen.dart';
import '../screens/movement_reasons/movement_reasons_screen.dart';
import '../screens/movement_reasons/create_reason_screen.dart';
import '../screens/movement_reasons/edit_reason_screen.dart';
import '../screens/operators/operators_screen.dart';
import '../screens/operators/create_operator_screen.dart';
import '../screens/operators/edit_operator_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/history/shift_detail_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../services/api_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  // Only trigger router refresh when the token actually changes (login/logout)
  String? lastToken;
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.token != lastToken) {
      lastToken = next.token;
      refreshNotifier.value++;
    }
  });

  // Listen for 401 errors (token expired) and force logout
  ApiClient.onUnauthorized.listen((_) {
    ref.read(authProvider.notifier).logout();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.token != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/entities',
        builder: (context, state) => const EntitiesScreen(),
      ),
      GoRoute(
        path: '/entities/create',
        builder: (context, state) => const CreateEntityScreen(),
      ),
      GoRoute(
        path: '/entities/:id/edit',
        builder: (context, state) => EditEntityScreen(
          entityId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/shift/start',
        builder: (context, state) => const StartShiftScreen(),
      ),
      GoRoute(
        path: '/shift/active',
        builder: (context, state) => const ActiveShiftScreen(),
      ),
      GoRoute(
        path: '/shift/end',
        builder: (context, state) => const EndShiftScreen(),
      ),
      GoRoute(
        path: '/shift/commissions',
        builder: (context, state) => const EditCommissionsScreen(),
      ),
      GoRoute(
        path: '/shift/pending-deliveries',
        builder: (context, state) => const PendingDeliveriesScreen(),
      ),
      GoRoute(
        path: '/shift/:id/summary',
        builder: (context, state) => ShiftSummaryScreen(
          shiftId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/shift/:id/movement',
        builder: (context, state) => MovementFormScreen(
          shiftId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/shift/:id/movement/:movementId',
        builder: (context, state) => MovementFormScreen(
          shiftId: state.pathParameters['id']!,
          movementId: state.pathParameters['movementId']!,
        ),
      ),
      GoRoute(
        path: '/movement-reasons',
        builder: (context, state) => const MovementReasonsScreen(),
      ),
      GoRoute(
        path: '/movement-reasons/create',
        builder: (context, state) => const CreateReasonScreen(),
      ),
      GoRoute(
        path: '/movement-reasons/:id/edit',
        builder: (context, state) => EditReasonScreen(
          reasonId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/operators',
        builder: (context, state) => const OperatorsScreen(),
      ),
      GoRoute(
        path: '/operators/create',
        builder: (context, state) => const CreateOperatorScreen(),
      ),
      GoRoute(
        path: '/operators/:id/edit',
        builder: (context, state) => EditOperatorScreen(
          operatorId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) => ShiftDetailScreen(
          shiftId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
