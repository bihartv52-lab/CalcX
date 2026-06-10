import 'package:calcx/app/app_env.dart';
import 'package:calcx/app/calcx_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('CalcX opens to calculator gate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(
            const AppEnv(
              supabaseUrl: '',
              supabaseAnonKey: '',
              liveKitUrl: '',
              liveKitTokenFunction: 'livekit-token',
            ),
          ),
        ],
        child: const CalcXApp(),
      ),
    );

    expect(find.text('CalcX'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('='), findsOneWidget);
  });
}
