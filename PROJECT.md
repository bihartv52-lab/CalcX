# Project: CalcX Social Suite Redesign

## Architecture
- Framework: Flutter (Dart SDK `>=3.11.0 <4.0.0`)
- State Management: Riverpod (`flutter_riverpod: ^3.3.1`)
- Routing: GoRouter (`go_router: ^17.2.3`)
- Backend & DB: Supabase (`supabase_flutter: ^2.12.4`, Postgres DB, Realtime Broadcast Channels, Storage Bucket `avatars`)
- Voice & Video Calls: LiveKit WebRTC (`livekit_client: ^2.7.0`)
- Video Players: `better_player_plus: ^1.2.1`, `youtube_player_flutter: ^9.1.3`
- Audio Controls: `audioplayers: ^6.1.0`
- Build Executable: `C:\flutter\bin\flutter.bat`
- Test Executable: `C:\flutter\bin\flutter.bat test`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Chat History Search & Jump | Search direct and room chat message history (DB ilike filter), display matching list, jump to message index | M1 | R1 |
| 2 | Message Forwarding | Multi-select or single-select message forwarding to other direct chats or rooms | M1 | R1 |
| 3 | Dynamic Theme Bubble Styling | Dynamically apply emerald (`#00E676`), crimson (`#FF1744`), amoled (`#00DBE9`) preset theme colors to message bubbles | M1 | R1 |
| 4 | Watch Party Supabase Realtime Sync | Synchronize play, pause, seek state across room participants via Supabase Realtime Broadcast (<500ms sync) | M2 | R2 |
| 5 | Watch Party Video Sources & Local Files | Support YouTube URL parsing (`youtube_player_flutter`) and local video file playback (`file_picker` + `better_player_plus`) | M2 | R2 |
| 6 | Watch Party Responsive PiP Overlay | Floating picture-in-picture overlay widget when navigating away or scrolling chat | M2 | R2 |
| 7 | Call Sound Control Panel | Custom sound control panel in active voice & video calls displaying active participants and mute indicators | M3 | R3 |
| 8 | Call Audio Output Switcher | Switch audio output route between Device Speaker, Ear Speaker, and Bluetooth headsets | M3 | R3 |
| 9 | Individual Participant Volume Sliders | Individual volume slider controls for adjusting volume levels per participant on the call | M3 | R3 |
| 10 | Profile Edits Screen | Profile edit screen allowing users to change display names, custom bios, and set nicknames | M4 | R4 |
| 11 | Circular Avatar Storage Upload & Refresh | Upload circular profile avatars to Supabase storage bucket (`avatars`) with real-time app refresh | M4 | R4 |
| 12 | Automated Verification & Testing Suite | Driver scripts and unit/integration test suite covering watch party sync, call volume sliders, and profile avatar upload flows | M5 | R5 |

## Code Layout
- `lib/core/models/`: `message.dart`, `user_profile.dart`, `playback_state.dart`
- `lib/core/theme/`: `app_theme.dart` (theme presets)
- `lib/features/chat/`: `data/chat_repository.dart`, `presentation/chat_page.dart`, `presentation/chat_list_page.dart`
- `lib/features/rooms/`: `presentation/room_chat_page.dart`, `presentation/room_watch_party_page.dart`, `domain/playback_state.dart`, `presentation/widgets/floating_pip_overlay.dart`
- `lib/features/calls/`: `data/livekit_call_service.dart`, `presentation/active_call_page.dart`, `presentation/widgets/sound_control_panel.dart`
- `lib/features/profile/`: `presentation/profile_edit_page.dart`, `data/profile_repository.dart`
- `test/`: `chat_test.dart`, `watch_party_sync_test.dart`, `call_volume_test.dart`, `profile_avatar_test.dart`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Chat Enhancements (R1) | Search & history jump, message forwarding, dynamic theme bubbles | none | DONE |
| 2 | Watch Party Features (R2) | Supabase Realtime broadcast sync (<500ms), YouTube/local video sources, PiP overlay | M1 | DONE |
| 3 | Call Sound Control (R3) | Sound control panel, speaker/earpiece/bluetooth audio output switcher, per-participant volume sliders | M1 | DONE |
| 4 | Profile Edits & System Integration (R4) | Profile edit screen (names/bios/nicknames), circular avatar upload to Supabase, realtime refresh | M1 | DONE |
| 5 | Verification & E2E Test Pass (R5) | Automated test suite for sync, volume sliders, avatar upload + forensic audit | M1, M2, M3, M4 | IN_PROGRESS |

## Interface Contracts
### Chat ↔ Theme System
- `ThemeData.colorScheme.primary` supplies active thread preset color (`emerald`, `crimson`, `amoled`). `MessageBubble` widget consumes primary color for user messages.
### Watch Party ↔ Supabase Realtime
- Broadcast channel name: `room:{roomId}:watch_party`
- Events: `play`, `pause`, `seek` with payload `{ timestamp, positionMs, sourceUrl }`.
### Call Service ↔ Sound Panel
- Sound panel listens to `CallSessionProvider` participant stream. Individual volume map `{ participantId: volumeDouble }` passed to `livekit_client` track volume controller.
- Audio output switcher calls `Hardware.instance.selectAudioOutput(AudioDeviceType)`.
### Profile ↔ Supabase Storage
- Bucket: `avatars`
- Profile table columns: `id`, `username`, `display_name`, `bio`, `nickname`, `avatar_url`, `updated_at`.
