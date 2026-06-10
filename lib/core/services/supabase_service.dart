import 'package:calcx/app/app_env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return SupabaseService.clientOrNull;
});

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static Future<void> initialize(AppEnv env) async {
    if (!env.hasSupabaseConfig || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient? get clientOrNull {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }
}
