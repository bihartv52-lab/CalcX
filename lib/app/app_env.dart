import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.fromEnvironment());

class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.liveKitUrl,
    required this.liveKitTokenFunction,
  });

  factory AppEnv.fromEnvironment() {
    // Try to load from .env file first, then fall back to --dart-define
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 
                        const String.fromEnvironment('SUPABASE_URL');
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 
                            const String.fromEnvironment('SUPABASE_ANON_KEY');
    final liveKitUrl = dotenv.env['LIVEKIT_URL'] ?? 
                       const String.fromEnvironment('LIVEKIT_URL');
    final liveKitTokenFunction = dotenv.env['LIVEKIT_TOKEN_FUNCTION'] ?? 
                                 const String.fromEnvironment(
                                   'LIVEKIT_TOKEN_FUNCTION',
                                   defaultValue: 'livekit-token',
                                 );

    return AppEnv(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      liveKitUrl: liveKitUrl,
      liveKitTokenFunction: liveKitTokenFunction.isEmpty 
          ? 'livekit-token' 
          : liveKitTokenFunction,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String liveKitUrl;
  final String liveKitTokenFunction;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasLiveKitConfig => liveKitUrl.isNotEmpty;
}
