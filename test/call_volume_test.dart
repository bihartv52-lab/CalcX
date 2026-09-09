import 'package:calcx/features/calls/domain/call_participant.dart';
import 'package:calcx/features/calls/presentation/widgets/sound_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Call Sound Control Panel Test Widget Component (R3)
class TestSoundControlPanel extends StatelessWidget {
  final List<CallParticipant> participants;
  final AudioOutputRoute currentRoute;
  final ValueChanged<AudioOutputRoute> onRouteChanged;
  final Function(String participantId, double volume) onVolumeChanged;
  final ValueChanged<String> onMuteToggled;

  const TestSoundControlPanel({
    super.key,
    required this.participants,
    required this.currentRoute,
    required this.onRouteChanged,
    required this.onVolumeChanged,
    required this.onMuteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Audio Output Route Switcher Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                key: const ValueKey('route_speaker'),
                icon: Icon(
                  Icons.volume_up,
                  color: currentRoute == AudioOutputRoute.deviceSpeaker ? Colors.cyanAccent : Colors.white54,
                ),
                onPressed: () => onRouteChanged(AudioOutputRoute.deviceSpeaker),
              ),
              IconButton(
                key: const ValueKey('route_earpiece'),
                icon: Icon(
                  Icons.phone_in_talk,
                  color: currentRoute == AudioOutputRoute.earSpeaker ? Colors.cyanAccent : Colors.white54,
                ),
                onPressed: () => onRouteChanged(AudioOutputRoute.earSpeaker),
              ),
              IconButton(
                key: const ValueKey('route_bluetooth'),
                icon: Icon(
                  Icons.bluetooth,
                  color: currentRoute == AudioOutputRoute.bluetoothHeadset ? Colors.cyanAccent : Colors.white54,
                ),
                onPressed: () => onRouteChanged(AudioOutputRoute.bluetoothHeadset),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          // Per-Participant Volume Controls
          ListView.builder(
            shrinkWrap: true,
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final p = participants[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      key: ValueKey('mute_btn_${p.id}'),
                      icon: Icon(
                        p.isMuted ? Icons.mic_off : Icons.mic,
                        color: p.isMuted ? Colors.redAccent : Colors.greenAccent,
                      ),
                      onPressed: () => onMuteToggled(p.id),
                    ),
                    Expanded(
                      child: Text(
                        p.displayName,
                        style: TextStyle(
                          color: p.isSpeaking ? Colors.greenAccent : Colors.white,
                          fontWeight: p.isSpeaking ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Slider(
                        key: ValueKey('volume_slider_${p.id}'),
                        value: p.volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => onVolumeChanged(p.id, val),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

void main() {
  group('Call Sound Controls (R3) - Per-Participant Volume Sliders', () {
    test('Initializes participant volume and clamps adjustments between 0.0 and 1.0', () {
      final manager = CallSoundControlManager();
      manager.addParticipant(const CallParticipant(id: 'user_1', displayName: 'Alice', volume: 0.8));

      expect(manager.participants['user_1']?.volume, equals(0.8));

      // Adjust volume within valid bounds
      manager.setParticipantVolume('user_1', 0.4);
      expect(manager.participants['user_1']?.volume, equals(0.4));

      // Over-clamp upper bound
      manager.setParticipantVolume('user_1', 1.5);
      expect(manager.participants['user_1']?.volume, equals(1.0));

      // Under-clamp lower bound
      manager.setParticipantVolume('user_1', -0.3);
      expect(manager.participants['user_1']?.volume, equals(0.0));
      expect(manager.participants['user_1']?.isMuted, isTrue, reason: '0.0 volume auto-mutes participant');
    });

    test('Isolated per-participant volume slider controls', () {
      final manager = CallSoundControlManager();
      manager.addParticipant(const CallParticipant(id: 'user_1', displayName: 'Alice', volume: 1.0));
      manager.addParticipant(const CallParticipant(id: 'user_2', displayName: 'Bob', volume: 0.5));

      // Change user_1 volume only
      manager.setParticipantVolume('user_1', 0.2);
      expect(manager.participants['user_1']?.volume, equals(0.2));
      expect(manager.participants['user_2']?.volume, equals(0.5), reason: 'user_2 volume must remain untouched');
    });

    test('Mute toggle sets volume to 0.0 and unmuting restores default/previous volume', () {
      final manager = CallSoundControlManager();
      manager.addParticipant(const CallParticipant(id: 'user_1', displayName: 'Alice', volume: 0.9));

      // Mute user_1
      manager.toggleParticipantMute('user_1');
      expect(manager.participants['user_1']?.isMuted, isTrue);
      expect(manager.participants['user_1']?.volume, equals(0.0));

      // Unmute user_1
      manager.toggleParticipantMute('user_1');
      expect(manager.participants['user_1']?.isMuted, isFalse);
      expect(manager.participants['user_1']?.volume, equals(0.8));
    });

    test('Detects active speaking state correctly based on audio level threshold', () {
      const quiet = CallParticipant(id: 'user_1', displayName: 'Alice', audioLevel: 0.05);
      const speaking = CallParticipant(id: 'user_2', displayName: 'Bob', audioLevel: 0.45);
      const mutedSpeaking = CallParticipant(id: 'user_3', displayName: 'Charlie', isMuted: true, audioLevel: 0.80);

      expect(quiet.isSpeaking, isFalse);
      expect(speaking.isSpeaking, isTrue);
      expect(mutedSpeaking.isSpeaking, isFalse, reason: 'Muted participant is not active speaker');
    });
  });

  group('Call Sound Controls (R3) - Audio Output Route Switcher', () {
    test('Switches audio routes between Device Speaker and Ear Speaker', () {
      final manager = CallSoundControlManager();
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.deviceSpeaker));

      manager.selectAudioRoute(AudioOutputRoute.earSpeaker);
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.earSpeaker));
    });

    test('Enables bluetooth headset route when bluetooth device is available', () {
      final manager = CallSoundControlManager();
      manager.setBluetoothAvailable(true);

      manager.selectAudioRoute(AudioOutputRoute.bluetoothHeadset);
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.bluetoothHeadset));
    });

    test('Falls back to device speaker when attempting bluetooth selection while unavailable', () {
      final manager = CallSoundControlManager();
      manager.setBluetoothAvailable(false);

      manager.selectAudioRoute(AudioOutputRoute.bluetoothHeadset);
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.deviceSpeaker));
    });

    test('Falls back to device speaker when active bluetooth disconnects', () {
      final manager = CallSoundControlManager();
      manager.setBluetoothAvailable(true);
      manager.selectAudioRoute(AudioOutputRoute.bluetoothHeadset);
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.bluetoothHeadset));

      // Disconnect bluetooth
      manager.setBluetoothAvailable(false);
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.deviceSpeaker));
    });

    test('Cycles sequentially through available audio routes', () {
      final manager = CallSoundControlManager();
      manager.setBluetoothAvailable(true);

      expect(manager.activeAudioRoute, equals(AudioOutputRoute.deviceSpeaker));

      manager.cycleAudioRoute();
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.earSpeaker));

      manager.cycleAudioRoute();
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.bluetoothHeadset));

      manager.cycleAudioRoute();
      expect(manager.activeAudioRoute, equals(AudioOutputRoute.deviceSpeaker));
    });
  });

  group('Call Sound Controls (R3) - Sound Control Panel Widget Driver', () {
    testWidgets('Renders sound control panel with audio route switcher and participant sliders', (tester) async {
      AudioOutputRoute selectedRoute = AudioOutputRoute.deviceSpeaker;
      final participants = [
        const CallParticipant(id: 'p1', displayName: 'Alice', volume: 0.8),
        const CallParticipant(id: 'p2', displayName: 'Bob', volume: 0.5, isMuted: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TestSoundControlPanel(
                  participants: participants,
                  currentRoute: selectedRoute,
                  onRouteChanged: (route) {
                    setState(() => selectedRoute = route);
                  },
                  onVolumeChanged: (id, vol) {},
                  onMuteToggled: (id) {},
                );
              },
            ),
          ),
        ),
      );

      // Verify route switcher buttons present
      expect(find.byKey(const ValueKey('route_speaker')), findsOneWidget);
      expect(find.byKey(const ValueKey('route_earpiece')), findsOneWidget);
      expect(find.byKey(const ValueKey('route_bluetooth')), findsOneWidget);

      // Verify participant list details
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byKey(const ValueKey('volume_slider_p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('volume_slider_p2')), findsOneWidget);

      // Tap earpiece route button
      await tester.tap(find.byKey(const ValueKey('route_earpiece')));
      await tester.pumpAndSettle();

      expect(selectedRoute, equals(AudioOutputRoute.earSpeaker));
    });

    testWidgets('Renders production SoundControlPanel widget with custom callbacks and Keys', (tester) async {
      AudioOutputRoute selectedRoute = AudioOutputRoute.deviceSpeaker;
      String? toggledMuteId;
      String? volumeChangedId;
      double? newVolumeVal;

      final participants = [
        const CallParticipant(id: 'p1', displayName: 'Alice', volume: 0.8, audioLevel: 0.3),
        const CallParticipant(id: 'p2', displayName: 'Bob', volume: 0.5, isMuted: true),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SoundControlPanel(
                    participants: participants,
                    currentRoute: selectedRoute,
                    onRouteChanged: (route) {
                      setState(() => selectedRoute = route);
                    },
                    onVolumeChanged: (id, vol) {
                      volumeChangedId = id;
                      newVolumeVal = vol;
                    },
                    onMuteToggled: (id) {
                      toggledMuteId = id;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify route switcher buttons present with exact ValueKeys
      expect(find.byKey(const ValueKey('route_speaker')), findsOneWidget);
      expect(find.byKey(const ValueKey('route_earpiece')), findsOneWidget);
      expect(find.byKey(const ValueKey('route_bluetooth')), findsOneWidget);

      // Verify participant list details and keys
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byKey(const ValueKey('mute_btn_p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mute_btn_p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('volume_slider_p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('volume_slider_p2')), findsOneWidget);

      // Tap route switcher button
      await tester.tap(find.byKey(const ValueKey('route_bluetooth')));
      await tester.pumpAndSettle();
      expect(selectedRoute, equals(AudioOutputRoute.bluetoothHeadset));

      // Tap mute button
      await tester.tap(find.byKey(const ValueKey('mute_btn_p1')));
      await tester.pumpAndSettle();
      expect(toggledMuteId, equals('p1'));
    });
  });
}
