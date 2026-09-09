import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:calcx/features/calls/domain/call_participant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound Control Panel Widget (R3)
/// Displays active call participants, mute status badges, live audio level indicators,
/// audio output route switcher, and per-participant volume sliders.
class SoundControlPanel extends ConsumerWidget {
  final List<CallParticipant>? participants;
  final AudioOutputRoute? currentRoute;
  final ValueChanged<AudioOutputRoute>? onRouteChanged;
  final Function(String participantId, double volume)? onVolumeChanged;
  final ValueChanged<String>? onMuteToggled;

  const SoundControlPanel({
    super.key,
    this.participants,
    this.currentRoute,
    this.onRouteChanged,
    this.onVolumeChanged,
    this.onMuteToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeCallSessionProvider);

    final effectiveParticipants = participants ?? session?.participants ?? [];
    final effectiveRoute = currentRoute ?? session?.activeAudioRoute ?? AudioOutputRoute.deviceSpeaker;

    void handleRouteChanged(AudioOutputRoute route) {
      if (onRouteChanged != null) {
        onRouteChanged!(route);
      } else {
        ref.read(activeCallSessionProvider.notifier).selectAudioRoute(route);
      }
    }

    void handleVolumeChanged(String id, double volume) {
      if (onVolumeChanged != null) {
        onVolumeChanged!(id, volume);
      } else {
        ref.read(activeCallSessionProvider.notifier).setParticipantVolume(id, volume);
      }
    }

    void handleMuteToggled(String id) {
      if (onMuteToggled != null) {
        onMuteToggled!(id);
      } else {
        ref.read(activeCallSessionProvider.notifier).toggleParticipantMute(id);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Sound Control Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${effectiveParticipants.length} Active',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Audio Output Route Switcher Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RouteOptionButton(
                    key: const ValueKey('route_speaker'),
                    icon: Icons.volume_up,
                    label: 'Speaker',
                    isSelected: effectiveRoute == AudioOutputRoute.deviceSpeaker,
                    onPressed: () => handleRouteChanged(AudioOutputRoute.deviceSpeaker),
                  ),
                  _RouteOptionButton(
                    key: const ValueKey('route_earpiece'),
                    icon: Icons.phone_in_talk,
                    label: 'Earpiece',
                    isSelected: effectiveRoute == AudioOutputRoute.earSpeaker,
                    onPressed: () => handleRouteChanged(AudioOutputRoute.earSpeaker),
                  ),
                  _RouteOptionButton(
                    key: const ValueKey('route_bluetooth'),
                    icon: Icons.bluetooth,
                    label: 'Bluetooth',
                    isSelected: effectiveRoute == AudioOutputRoute.bluetoothHeadset,
                    onPressed: () => handleRouteChanged(AudioOutputRoute.bluetoothHeadset),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            // Per-Participant Volume Controls & Live Audio Indicators
            if (effectiveParticipants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No active participants',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: effectiveParticipants.length,
                itemBuilder: (context, index) {
                  final p = effectiveParticipants[index];
                  final isSpeaking = p.isSpeaking;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSpeaking ? Colors.greenAccent.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSpeaking ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Mute Button Badge
                        IconButton(
                          key: ValueKey('mute_btn_${p.id}'),
                          icon: Icon(
                            p.isMuted ? Icons.mic_off : Icons.mic,
                            color: p.isMuted ? Colors.redAccent : Colors.greenAccent,
                            size: 22,
                          ),
                          onPressed: () => handleMuteToggled(p.id),
                        ),
                        const SizedBox(width: 4),
                        // Avatar & Live Audio Indicator Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isSpeaking ? Colors.greenAccent : Colors.grey[800],
                              backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                  ? NetworkImage(p.avatarUrl!)
                                  : null,
                              child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                  ? Text(
                                      p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    )
                                  : null,
                            ),
                            if (isSpeaking)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.greenAccent, width: 2),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // Display Name and Audio Level Indicator
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSpeaking ? Colors.greenAccent : Colors.white,
                                  fontWeight: isSpeaking ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Audio Level Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: p.isMuted ? 0.0 : (p.audioLevel > 0 ? p.audioLevel : 0.05),
                                        backgroundColor: Colors.white12,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          p.isMuted
                                              ? Colors.redAccent.withValues(alpha: 0.5)
                                              : (isSpeaking ? Colors.greenAccent : Colors.cyanAccent.withValues(alpha: 0.6)),
                                        ),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    p.isMuted ? 'Muted' : '${(p.volume * 100).toInt()}%',
                                    style: TextStyle(
                                      color: p.isMuted ? Colors.redAccent : Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Individual Volume Slider
                        SizedBox(
                          width: 130,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: p.isMuted ? Colors.redAccent : Colors.cyanAccent,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: p.isMuted ? Colors.redAccent : Colors.cyanAccent,
                            ),
                            child: Slider(
                              key: ValueKey('volume_slider_${p.id}'),
                              value: p.volume.clamp(0.0, 1.0),
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) => handleVolumeChanged(p.id, val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _RouteOptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.cyanAccent;
    final inactiveColor = Colors.white54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                onPressed: onPressed,
              ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
