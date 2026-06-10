import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/features/auth/presentation/auth_page.dart';
import 'package:calcx/features/calculator/presentation/calculator_page.dart';
import 'package:calcx/features/chat/presentation/chat_page.dart';
import 'package:calcx/features/home/presentation/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final rootNavigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootKey = ref.watch(rootNavigatorKeyProvider);

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.calculator,
    routes: [
      GoRoute(
        path: AppRoutes.calculator,
        name: 'calculator',
        builder: (context, state) => const CalculatorPage(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/chat/:userId',
        name: 'chat',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ChatPage(otherUserId: userId);
        },
      ),
    ],
  );
});
