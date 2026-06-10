import 'package:calcx/app/app_router.dart';
import 'package:calcx/app/app_theme.dart';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/widgets/incoming_call_listener.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalcXApp extends ConsumerStatefulWidget {
  const CalcXApp({super.key});

  @override
  ConsumerState<CalcXApp> createState() => _CalcXAppState();
}

class _CalcXAppState extends ConsumerState<CalcXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Try setting status online on boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePresence(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _updatePresence(false);
    }
  }

  Future<void> _updatePresence(bool isOnline) async {
    try {
      final supabase = SupabaseService.clientOrNull;
      if (supabase == null) return;
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      await supabase.from('profiles').update({
        'status': isOnline ? 'online' : 'offline',
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', myId);
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeSettings = ref.watch(themeServiceProvider);

    // Watch for global session logout/expiry
    ref.listen<AsyncValue<AuthState?>>(authChangesProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      if (state.event == AuthChangeEvent.signedOut) {
        final rootKey = ref.read(rootNavigatorKeyProvider);
        final rootContext = rootKey.currentContext;
        if (rootContext != null) {
          GoRouter.of(rootContext).go(AppRoutes.auth);
        }
      } else if (state.event == AuthChangeEvent.signedIn) {
        _updatePresence(true);
      }
    });

    return MaterialApp.router(
      title: 'CalcX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeForSettings(themeSettings),
      routerConfig: router,
      builder: (context, child) {
        return IncomingCallListener(child: child!);
      },
    );
  }
}
