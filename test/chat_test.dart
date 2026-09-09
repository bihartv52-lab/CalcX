import 'package:calcx/app/app_theme.dart';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dynamic Theme Primary Color Resolution Tests', () {
    test('resolves preset_emerald color correctly to #00E676', () {
      final color = AppTheme.resolveThreadPrimaryColor(threadPreset: 'preset_emerald');
      expect(color, equals(const Color(0xFF00E676)));
    });

    test('resolves preset_crimson color correctly to #FF1744', () {
      final color = AppTheme.resolveThreadPrimaryColor(threadPreset: 'preset_crimson');
      expect(color, equals(const Color(0xFFFF1744)));
    });

    test('resolves preset_amoled color correctly to #00DBE9', () {
      final color = AppTheme.resolveThreadPrimaryColor(threadPreset: 'preset_amoled');
      expect(color, equals(const Color(0xFF00DBE9)));
    });

    test('resolves preset_sunset color correctly to #FF5722', () {
      final color = AppTheme.resolveThreadPrimaryColor(threadPreset: 'preset_sunset');
      expect(color, equals(const Color(0xFFFF5722)));
    });

    test('resolves shorthand theme names (emerald, crimson, amoled, sunset)', () {
      expect(AppTheme.resolveThreadPrimaryColor(threadPreset: 'emerald'), equals(const Color(0xFF00E676)));
      expect(AppTheme.resolveThreadPrimaryColor(threadPreset: 'crimson'), equals(const Color(0xFFFF1744)));
      expect(AppTheme.resolveThreadPrimaryColor(threadPreset: 'amoled'), equals(const Color(0xFF00DBE9)));
      expect(AppTheme.resolveThreadPrimaryColor(threadPreset: 'sunset'), equals(const Color(0xFFFF5722)));
    });

    test('falls back to themeData primary color when threadPreset is null', () {
      final customTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, primary: Colors.purple),
      );
      final color = AppTheme.resolveThreadPrimaryColor(threadPreset: null, themeData: customTheme);
      expect(color, equals(Colors.purple));
    });

    test('ThemeSettings helper method resolveThreadPresetColor', () {
      final settings = ThemeSettings(chatWallpapers: {'chat_123': 'preset_emerald'});
      final color = settings.resolveThreadPresetColor('chat_123');
      expect(color, equals(const Color(0xFF00E676)));
    });
  });

  group('Chat Search & Filtering Tests', () {
    final sampleMessages = [
      Message(
        id: 'msg_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        content: 'Hello, how are you doing today?',
        messageType: 'text',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Message(
        id: 'msg_2',
        senderId: 'user_b',
        receiverId: 'user_a',
        content: 'I am testing the search and history jump feature!',
        messageType: 'text',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      Message(
        id: 'msg_3',
        senderId: 'user_a',
        receiverId: 'user_b',
        content: 'Awesome, searching for "test" should match msg_2.',
        messageType: 'text',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ];

    test('filters loaded messages by query substring case-insensitively', () {
      const query = 'SEARCH';
      final matches = sampleMessages
          .where((m) => m.content.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(matches.length, equals(2));
      expect(matches.map((m) => m.id), containsAll(['msg_2', 'msg_3']));
    });

    test('returns empty list when search query does not match any message', () {
      const query = 'nonexistent_xyz';
      final matches = sampleMessages
          .where((m) => m.content.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(matches, isEmpty);
    });

    test('returns all messages when query is empty', () {
      const query = '';
      final matches = query.isEmpty
          ? sampleMessages
          : sampleMessages.where((m) => m.content.toLowerCase().contains(query.toLowerCase())).toList();

      expect(matches.length, equals(3));
    });
  });

  group('Message Forwarding Repository Logic Tests', () {
    test('ChatRepository instantiation without Supabase client handles empty forward calls gracefully', () async {
      final repository = ChatRepository(null);
      final msg = Message(
        id: 'fwd_1',
        senderId: 'user_1',
        receiverId: 'user_2',
        content: 'Forwarded announcement',
        createdAt: DateTime.now(),
      );

      await expectLater(
        repository.forwardMessages(
          messages: [msg],
          targetReceiverIds: ['user_3', 'user_4'],
          targetRoomIds: ['room_1'],
        ),
        completes,
      );
    });

    test('ChatRepository searchDirectMessages and searchRoomMessages return empty list when unconfigured', () async {
      final repository = ChatRepository(null);
      final dmResults = await repository.searchDirectMessages('user_other', 'test');
      final roomResults = await repository.searchRoomMessages('room_test', 'test');

      expect(dmResults, isEmpty);
      expect(roomResults, isEmpty);
    });
  });
}
