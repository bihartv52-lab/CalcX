import 'package:calcx/app/app_env.dart';
import 'package:calcx/app/calcx_app.dart';
import 'package:calcx/core/services/notification_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app.env file from assets
  try {
    await dotenv.load(fileName: 'assets/app.env');
  } catch (e) {
    // app.env file not found or error loading, continue without it
    debugPrint('Could not load assets/app.env file: $e');
  }

  final env = AppEnv.fromEnvironment();

  // Initialize Supabase only if configured — app works fully offline otherwise
  try {
    await SupabaseService.initialize(env);
  } catch (e) {
    debugPrint('Supabase init skipped: $e');
  }

  // Notifications are optional
  try {
    await NotificationService.maybeInitialize();
  } catch (e) {
    debugPrint('Notification init skipped: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        appEnvProvider.overrideWithValue(env),
      ],
      child: const CalcXApp(),
    ),
  );
}
