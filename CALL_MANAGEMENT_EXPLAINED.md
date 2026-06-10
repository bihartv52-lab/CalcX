# 📞 Call Management System - Complete Explanation

## 🎯 Overview

The Call Management system enables **real-time audio and video calls** between users using **LiveKit** (WebRTC infrastructure) and **Supabase** (signaling and call history).

---

## 🏗️ Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Caller    │────────▶│   Supabase   │────────▶│  Receiver   │
│  (Flutter)  │         │  (Signaling) │         │  (Flutter)  │
└─────────────┘         └──────────────┘         └─────────────┘
       │                                                 │
       │                                                 │
       └────────────────▶┌──────────────┐◀──────────────┘
                         │   LiveKit    │
                         │ (Media/RTC)  │
                         └──────────────┘
```

### Components:

1. **Supabase** - Call signaling, history, and notifications
2. **LiveKit** - Real-time audio/video streaming (WebRTC)
3. **Flutter** - UI and call controls

---

## 🔄 Call Flow

### 1. **Initiating a Call**

```
User A                    Supabase                    User B
  │                          │                          │
  │──(1) Create Call────────▶│                          │
  │   (status: ringing)      │                          │
  │                          │──(2) Realtime Event─────▶│
  │                          │   (new call)             │
  │                          │                          │
  │                          │◀─(3) Accept/Reject───────│
  │◀─(4) Call Updated───────│                          │
  │   (status: ongoing)      │                          │
  │                          │                          │
  │──(5) Join LiveKit Room──────────────────────────────│
  │                                                     │
  │◀────────────(6) Audio/Video Stream─────────────────▶│
```

### 2. **Call States**

| State | Description | Actions Available |
|-------|-------------|-------------------|
| `ringing` | Call initiated, waiting for answer | Accept, Reject |
| `ongoing` | Call in progress | Mute, Video toggle, End |
| `ended` | Call completed normally | View history |
| `missed` | Receiver didn't answer | Call back |
| `rejected` | Receiver declined | - |

---

## 💾 Database Schema

### `calls` Table

```sql
CREATE TABLE calls (
  id UUID PRIMARY KEY,
  caller_id UUID REFERENCES profiles(id),    -- Who initiated
  receiver_id UUID REFERENCES profiles(id),  -- Who received
  call_type TEXT,                            -- 'audio' or 'video'
  status TEXT DEFAULT 'ringing',             -- Call state
  room_name TEXT,                            -- LiveKit room ID
  started_at TIMESTAMP,                      -- When call started
  ended_at TIMESTAMP,                        -- When call ended
  duration INTEGER                           -- Call length (seconds)
);
```

### Real-time Subscription

```dart
// Listen for incoming calls
supabase
  .from('calls')
  .stream(primaryKey: ['id'])
  .eq('receiver_id', myUserId)
  .eq('status', 'ringing')
  .listen((data) {
    // Show incoming call screen
  });
```

---

## 🎬 Implementation Details

### A. **Call Repository** (`call_repository.dart`)

Handles all call operations:

```dart
class CallRepository {
  // 1. Initiate a call
  Future<Call> initiateCall({
    required String receiverId,
    required String callType, // 'audio' or 'video'
  }) async {
    // Create call record in database
    // Generate LiveKit room name
    // Return call object
  }

  // 2. Accept a call
  Future<void> acceptCall(String callId) async {
    // Update status to 'ongoing'
    // Get LiveKit token
    // Return room details
  }

  // 3. Reject a call
  Future<void> rejectCall(String callId) async {
    // Update status to 'rejected'
  }

  // 4. End a call
  Future<void> endCall(String callId) async {
    // Update status to 'ended'
    // Calculate duration
    // Save to history
  }

  // 5. Watch incoming calls
  Stream<List<Call>> watchIncomingCalls() {
    // Real-time stream of incoming calls
  }

  // 6. Get call history
  Future<List<Call>> getCallHistory() {
    // Fetch past calls
  }
}
```

### B. **LiveKit Service** (`livekit_call_service.dart`)

Manages WebRTC connections:

```dart
class LiveKitCallService {
  Room? _room;
  
  // 1. Join a call room
  Future<void> joinRoom({
    required String roomName,
    required String token,
    required bool video,
  }) async {
    _room = Room();
    
    // Connect to LiveKit
    await _room!.connect(
      livekitUrl,
      token,
      roomOptions: RoomOptions(
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
        ),
        defaultVideoCaptureOptions: VideoCaptureOptions(
          cameraPosition: CameraPosition.front,
        ),
      ),
    );
    
    // Publish local tracks
    if (video) {
      await _room!.localParticipant?.setCameraEnabled(true);
    }
    await _room!.localParticipant?.setMicrophoneEnabled(true);
  }

  // 2. Toggle microphone
  Future<void> toggleMicrophone() async {
    final enabled = _room!.localParticipant?.isMicrophoneEnabled();
    await _room!.localParticipant?.setMicrophoneEnabled(!enabled);
  }

  // 3. Toggle camera
  Future<void> toggleCamera() async {
    final enabled = _room!.localParticipant?.isCameraEnabled();
    await _room!.localParticipant?.setCameraEnabled(!enabled);
  }

  // 4. Switch camera (front/back)
  Future<void> switchCamera() async {
    await _room!.localParticipant?.switchCamera();
  }

  // 5. Leave room
  Future<void> leaveRoom() async {
    await _room?.disconnect();
    _room = null;
  }
}
```

### C. **LiveKit Token Service** (`livekit_token_service.dart`)

Generates secure tokens:

```dart
class LiveKitTokenService {
  Future<String> getToken({
    required String roomName,
    required String participantName,
  }) async {
    // Call Supabase Edge Function to generate token
    final response = await supabase.functions.invoke(
      'livekit-token',
      body: {
        'room_name': roomName,
        'participant_name': participantName,
      },
    );
    
    return response.data['token'];
  }
}
```

---

## 📱 UI Components

### 1. **Incoming Call Screen**

Shows when receiving a call:

```dart
IncomingCallPage(
  call: call,
  onAccept: () {
    // Accept call
    // Navigate to ActiveCallPage
  },
  onReject: () {
    // Reject call
    // Close screen
  },
)
```

**Features:**
- Full-screen overlay
- Caller name and avatar
- Ringtone/vibration
- Accept (green) / Reject (red) buttons
- Auto-timeout after 30 seconds

### 2. **Active Call Screen**

Shows during an ongoing call:

```dart
ActiveCallPage(
  call: call,
  room: livekitRoom,
  onEnd: () {
    // End call
    // Navigate back
  },
)
```

**Features:**
- Video preview (local + remote)
- Call duration timer
- Control buttons:
  - Mute/Unmute microphone
  - Speaker on/off
  - Video on/off
  - Switch camera
  - End call (red)
- Connection quality indicator
- Participant info

### 3. **Call History**

Shows past calls:

```dart
CallHistoryPage(
  calls: callHistory,
  onCallBack: (userId) {
    // Initiate new call
  },
)
```

**Features:**
- List of all calls
- Call type icon (audio/video)
- Call status (completed/missed/rejected)
- Duration display
- Timestamp
- Call-back button
- Delete option

---

## 🔔 Notifications

### Push Notifications for Incoming Calls

```dart
// When call is created
await supabase.from('notifications').insert({
  'user_id': receiverId,
  'type': 'call',
  'title': 'Incoming Call',
  'body': '$callerName is calling you',
  'data': {
    'call_id': callId,
    'call_type': callType,
  },
});

// FCM sends push notification
// User taps notification → Opens IncomingCallPage
```

---

## 🎮 Call Controls

### During a Call:

| Control | Icon | Action |
|---------|------|--------|
| **Mute** | 🎤 | Toggle microphone on/off |
| **Speaker** | 🔊 | Toggle speaker/earpiece |
| **Video** | 📹 | Toggle camera on/off |
| **Switch Camera** | 🔄 | Front/back camera |
| **End Call** | ❌ | Disconnect and end |

### Implementation:

```dart
// Mute button
IconButton(
  icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
  onPressed: () async {
    await livekitService.toggleMicrophone();
    setState(() => isMuted = !isMuted);
  },
)

// Video button
IconButton(
  icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
  onPressed: () async {
    await livekitService.toggleCamera();
    setState(() => isVideoOn = !isVideoOn);
  },
)

// End call button
IconButton(
  icon: Icon(Icons.call_end),
  color: Colors.red,
  onPressed: () async {
    await callRepository.endCall(callId);
    await livekitService.leaveRoom();
    Navigator.pop(context);
  },
)
```

---

## 🔐 Security

### 1. **LiveKit Tokens**

Tokens are generated server-side (Supabase Edge Function) to prevent abuse:

```typescript
// Supabase Edge Function: livekit-token
import { AccessToken } from 'livekit-server-sdk';

Deno.serve(async (req) => {
  const { room_name, participant_name } = await req.json();
  
  const token = new AccessToken(
    LIVEKIT_API_KEY,
    LIVEKIT_API_SECRET,
    {
      identity: participant_name,
    }
  );
  
  token.addGrant({
    room: room_name,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });
  
  return new Response(
    JSON.stringify({ token: token.toJwt() }),
    { headers: { 'Content-Type': 'application/json' } }
  );
});
```

### 2. **Row Level Security**

Only call participants can access call data:

```sql
CREATE POLICY "Users can view their calls"
  ON calls FOR SELECT
  USING (auth.uid() = caller_id OR auth.uid() = receiver_id);
```

---

## 📊 Call Quality

### Connection Quality Indicator

```dart
// Listen to connection quality
room.connectionState.listen((state) {
  if (state == ConnectionState.connected) {
    // Good connection
  } else if (state == ConnectionState.reconnecting) {
    // Poor connection
  }
});

// Show indicator
Icon(
  connectionQuality == 'good' 
    ? Icons.signal_cellular_4_bar 
    : Icons.signal_cellular_1_bar,
  color: connectionQuality == 'good' ? Colors.green : Colors.orange,
)
```

---

## 🐛 Error Handling

### Common Issues:

1. **Permission Denied**
   - Request camera/microphone permissions
   - Show permission dialog

2. **Connection Failed**
   - Check internet connection
   - Retry connection
   - Show error message

3. **Call Timeout**
   - Auto-reject after 30 seconds
   - Update status to 'missed'

4. **User Busy**
   - Check if user is already in a call
   - Show "User is busy" message

---

## 📈 Call Statistics

Track call metrics:

```dart
class CallStats {
  final int totalCalls;
  final int missedCalls;
  final int totalDuration; // seconds
  final double averageDuration;
  
  // Calculate from call history
  static CallStats fromHistory(List<Call> calls) {
    return CallStats(
      totalCalls: calls.length,
      missedCalls: calls.where((c) => c.isMissed).length,
      totalDuration: calls.fold(0, (sum, c) => sum + (c.duration ?? 0)),
      averageDuration: calls.isEmpty ? 0 : 
        calls.fold(0, (sum, c) => sum + (c.duration ?? 0)) / calls.length,
    );
  }
}
```

---

## 🎯 Best Practices

1. **Always request permissions** before initiating a call
2. **Show loading states** during connection
3. **Handle network changes** gracefully
4. **Clean up resources** when call ends
5. **Save call history** for user reference
6. **Test with real devices** (not just emulators)
7. **Handle background/foreground** transitions
8. **Implement call timeout** (30-60 seconds)
9. **Show connection quality** to users
10. **Log errors** for debugging

---

## 🚀 Testing Checklist

- [ ] Initiate audio call
- [ ] Initiate video call
- [ ] Accept incoming call
- [ ] Reject incoming call
- [ ] Mute/unmute during call
- [ ] Toggle video during call
- [ ] Switch camera (front/back)
- [ ] End call (both parties)
- [ ] Call timeout (no answer)
- [ ] Call history display
- [ ] Call back from history
- [ ] Permissions handling
- [ ] Network interruption
- [ ] Background/foreground
- [ ] Multiple calls (busy state)

---

## 📚 Resources

- **LiveKit Docs:** https://docs.livekit.io/
- **LiveKit Flutter SDK:** https://pub.dev/packages/livekit_client
- **Supabase Realtime:** https://supabase.com/docs/guides/realtime
- **WebRTC Basics:** https://webrtc.org/getting-started/overview

---

## 🎉 Summary

The Call Management system provides:

✅ **Real-time audio/video calls** using LiveKit
✅ **Call signaling** through Supabase
✅ **Call history** tracking
✅ **Push notifications** for incoming calls
✅ **Call controls** (mute, video, speaker)
✅ **Connection quality** monitoring
✅ **Secure token generation**
✅ **Beautiful UI** matching app theme

**Result:** A production-ready calling system like WhatsApp or Telegram! 📞✨
