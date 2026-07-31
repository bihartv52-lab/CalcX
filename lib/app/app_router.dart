import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/features/auth/presentation/auth_page.dart';
import 'package:calcx/features/calculator/presentation/calculator_page.dart';
import 'package:calcx/features/chat/presentation/chat_page.dart';
import 'package:calcx/features/home/presentation/home_shell.dart';
import 'package:calcx/features/rooms/presentation/room_detail_page.dart';
import 'package:calcx/features/rooms/presentation/room_game_zone_page.dart';
import 'package:calcx/features/rooms/presentation/room_watch_party_page.dart';
import 'package:calcx/features/rooms/presentation/room_chat_page.dart';
import 'package:calcx/features/rooms/presentation/room_voice_call_page.dart';
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
      GoRoute(
        path: '/room/:roomId',
        name: 'room_detail',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return RoomDetailPage(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/room/:roomId/game',
        name: 'room_game',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'] ?? 'Game Zone';
          return RoomGameZonePage(roomId: roomId, roomName: roomName);
        },
      ),
      GoRoute(
        path: '/room/:roomId/watch',
        name: 'room_watch',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'] ?? 'Watch Party';
          return RoomWatchPartyPage(roomId: roomId, roomName: roomName);
        },
      ),
      GoRoute(
        path: '/room/:roomId/chat',
        name: 'room_chat',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'] ?? 'Room Chat';
          return RoomChatPage(roomId: roomId, roomName: roomName);
        },
      ),
      GoRoute(
        path: '/room/:roomId/voice',
        name: 'room_voice',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final roomName = state.uri.queryParameters['name'] ?? 'Voice Call';
          return RoomVoiceCallPage(roomId: roomId, roomName: roomName);
        },
      ),
    ],
  );
});
