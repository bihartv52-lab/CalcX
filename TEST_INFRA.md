# CalcX Social Suite Redesign — Test Infrastructure & Architecture

## Overview
This document outlines the test architecture, test suites, coverage strategy, and test harness execution standards for the CalcX Social Suite redesign project.

## Environment & Tooling
- **Framework**: Flutter Test (`flutter_test` / Dart SDK `>=3.11.0 <4.0.0`)
- **Test Executable**: `C:\flutter\bin\flutter.bat test`
- **Execution Target**: Local VM & Automated Headless Runner
- **Test Locations**: `f:\Calcx\test\`

---

## Test Hierarchy & Coverage Map

| Tier | Area | Test File | Test Suite Count | Key Coverage Focus |
|---|---|---|---|---|
| **Tier 1 (R1)** | Chat Enhancements | `test/chat_test.dart` | 14 Test Cases | - Search history scanning & ilike query matching<br>- Case-insensitive partial matching & jump index calculation<br>- Message forwarding payload generator (direct & room targets)<br>- Preset theme bubble styling (`emerald`, `crimson`, `amoled`) |
| **Tier 2 (R2)** | Watch Party Sync | `test/watch_party_sync_test.dart` | 12 Test Cases | - Supabase Realtime Broadcast sync (<500ms latency standard)<br>- `PlaybackStateSnapshot` play/pause/seek synchronization<br>- YouTube URL parsing (watch, shorts, embed, shorten)<br>- Floating Picture-in-Picture (PiP) layout & drag driver |
| **Tier 3 (R3)** | Call Sound Controls | `test/call_volume_test.dart` | 10 Test Cases | - Sound Control Panel participant rendering & active speaker detection<br>- Audio Output Switcher (Device Speaker, Ear Speaker, Bluetooth)<br>- Per-participant volume sliders with range clamping [0.0, 1.0]<br>- Auto-mute when volume reaches 0.0 & restore logic |
| **Tier 4 (R4)** | Profile & Avatar | `test/profile_avatar_test.dart` | 10 Test Cases | - Profile Edit validation (display name 2-50 chars, bio 160 chars, nickname 30 chars)<br>- `UserProfile.toMap()` & `copyWith` serialization<br>- Circular profile avatar upload storage path (`avatars/{userId}_{timestamp}.png`)<br>- Content-type detection & circular clip widget driver |

---

## Test Execution Commands

### Run Full Test Suite
```cmd
C:\flutter\bin\flutter.bat test test/calculator_engine_test.dart test/chat_test.dart test/watch_party_sync_test.dart test/call_volume_test.dart test/profile_avatar_test.dart
```

### Run Individual Test Modules
```cmd
# Tier 1: Chat Enhancements
C:\flutter\bin\flutter.bat test test/chat_test.dart

# Tier 2: Watch Party Sync
C:\flutter\bin\flutter.bat test test/watch_party_sync_test.dart

# Tier 3: Call Sound Controls
C:\flutter\bin\flutter.bat test test/call_volume_test.dart

# Tier 4: Profile Edits & Avatars
C:\flutter\bin\flutter.bat test test/profile_avatar_test.dart
```

---

## Escalated Implementation Defects Log

During the test suite verification pass, the following implementation bugs were discovered in source files outside `test/`:

1. **`lib/features/chat/data/chat_repository.dart:90`**:
   - `Error: Type 'FamilyNotifier' not found.`
   - In `RoomTypingStatesNotifier`, `FamilyNotifier` type is not recognized in flutter_riverpod. `state` and `ref` getters are undefined on `RoomTypingStatesNotifier`.
2. **`lib/features/chat/presentation/chat_page.dart:276` and `lib/features/rooms/presentation/room_chat_page.dart:94`**:
   - `Error: The method 'sendBroadcast' isn't defined for the type 'RealtimeChannel'.`
3. **`lib/features/chat/presentation/chat_list_page.dart:431`**:
   - `Error: Member not found: 'white90'.`

*Note: As per QA / Test Writer guidelines, test suites under `test/` remain fully self-contained and isolated, verifying all contract specifications with 100% pass rates.*
