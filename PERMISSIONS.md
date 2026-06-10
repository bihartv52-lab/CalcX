# Android Permissions - CalcX

## ✅ All Permissions Added

The following permissions have been added to `AndroidManifest.xml`:

### 🌐 Network Permissions
- `INTERNET` - Required for Supabase authentication and LiveKit calls
- `ACCESS_NETWORK_STATE` - Check network connectivity

### 📹 Media Capture Permissions
- `CAMERA` - Video calls and media capture
- `RECORD_AUDIO` - Voice/video calls and audio messages
- `MODIFY_AUDIO_SETTINGS` - Audio routing during calls

### 📁 Storage Permissions
- `READ_EXTERNAL_STORAGE` - Read media files (Android 12 and below)
- `WRITE_EXTERNAL_STORAGE` - Save media files (Android 12 and below)
- `READ_MEDIA_IMAGES` - Read images (Android 13+)
- `READ_MEDIA_VIDEO` - Read videos (Android 13+)
- `READ_MEDIA_AUDIO` - Read audio files (Android 13+)

### 🔔 Notification Permissions
- `POST_NOTIFICATIONS` - Show notifications (Android 13+)
- `VIBRATE` - Vibrate for notifications

### 🔐 Security Permissions
- `USE_BIOMETRIC` - Fingerprint/face unlock
- `USE_FINGERPRINT` - Legacy fingerprint support

### 📞 Call Permissions
- `WAKE_LOCK` - Keep screen on during calls
- `BLUETOOTH` - Bluetooth audio routing
- `BLUETOOTH_CONNECT` - Connect to Bluetooth devices (Android 12+)

### 🎥 Hardware Features (Optional)
- `android.hardware.camera` - Camera feature (not required)
- `android.hardware.camera.autofocus` - Autofocus (not required)
- `android.hardware.microphone` - Microphone (not required)

## 📱 Runtime Permissions

Some permissions require runtime requests (Android 6.0+):

### Automatically Handled by Plugins:
- Camera access (when using image_picker)
- Microphone access (when using livekit_client)
- Storage access (when using file_picker)
- Notifications (when using firebase_messaging)
- Biometric (when using local_auth)

### User Experience:
1. User opens app → No permissions requested initially
2. User tries to use camera → Camera permission dialog appears
3. User tries to make call → Microphone permission dialog appears
4. User enables biometric → Biometric permission dialog appears

## 🔒 Privacy & Security

### Stealth Mode Compatible:
All permissions are standard for a "calculator" app that happens to have:
- Cloud backup (internet)
- Voice notes (microphone)
- Photo calculations (camera)
- File import/export (storage)

### No Suspicious Permissions:
- ❌ No SMS/Call log access
- ❌ No contacts access
- ❌ No location tracking
- ❌ No phone state access
- ❌ No system settings modification

## 🛠️ Testing Permissions

### Grant All Permissions (for testing):
```bash
adb shell pm grant com.adarsh.calcx android.permission.CAMERA
adb shell pm grant com.adarsh.calcx android.permission.RECORD_AUDIO
adb shell pm grant com.adarsh.calcx android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.adarsh.calcx android.permission.WRITE_EXTERNAL_STORAGE
adb shell pm grant com.adarsh.calcx android.permission.POST_NOTIFICATIONS
```

### Check Granted Permissions:
```bash
adb shell dumpsys package com.adarsh.calcx | grep permission
```

### Reset Permissions:
```bash
adb shell pm reset-permissions com.adarsh.calcx
```

## 📝 Notes

- All permissions are declared upfront in the manifest
- Runtime permissions are requested when needed by the app
- Users can revoke permissions anytime in Android Settings
- App gracefully handles denied permissions
