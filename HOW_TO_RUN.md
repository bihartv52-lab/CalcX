# 🚀 How to Run Your Calcx App

## ✅ Everything is Ready!

Your app is **100% configured** and ready to run:
- ✅ Supabase configured
- ✅ LiveKit configured
- ✅ Firebase configured
- ✅ Edge function deployed
- ✅ Database ready
- ✅ All code implemented

---

## 📱 Option 1: Run with Android Studio (EASIEST)

### Step 1: Open Project
1. Open **Android Studio**
2. Click **Open** or **File → Open**
3. Navigate to `G:\Calcx`
4. Click **OK**

### Step 2: Wait for Indexing
- Android Studio will index the project (1-2 minutes)
- Wait for "Gradle sync" to complete

### Step 3: Connect Device
**Option A - Real Android Device:**
1. Enable **Developer Options** on your phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
2. Enable **USB Debugging**:
   - Settings → Developer Options → USB Debugging
3. Connect phone via USB
4. Allow USB debugging on phone

**Option B - Android Emulator:**
1. In Android Studio, click **Device Manager** (phone icon)
2. Click **Create Device**
3. Select a device (e.g., Pixel 5)
4. Download a system image (e.g., Android 13)
5. Click **Finish**
6. Click **Play** button to start emulator

### Step 4: Run App
1. Make sure device/emulator is selected in top toolbar
2. Click the **green play button** (▶️) or press **Shift+F10**
3. Wait for build to complete (first time: 2-5 minutes)
4. App will launch automatically!

---

## 📱 Option 2: Run with VS Code

### Step 1: Open Project
1. Open **VS Code**
2. Click **File → Open Folder**
3. Select `G:\Calcx`

### Step 2: Install Flutter Extension
1. Click **Extensions** (Ctrl+Shift+X)
2. Search for "Flutter"
3. Install **Flutter** extension by Dart Code

### Step 3: Connect Device
- Connect Android device or start emulator (same as above)

### Step 4: Run App
1. Press **F5** or click **Run → Start Debugging**
2. Select **Dart & Flutter** if prompted
3. App will build and launch!

---

## 📱 Option 3: Run with Command Line

### Step 1: Open Command Prompt
1. Press **Windows + R**
2. Type `cmd` and press Enter
3. Navigate to project:
   ```cmd
   cd G:\Calcx
   ```

### Step 2: Check Flutter
```cmd
flutter doctor
```

If you get "flutter is not recognized":
1. Find your Flutter installation folder
2. Add to PATH:
   - Right-click **This PC** → **Properties**
   - Click **Advanced system settings**
   - Click **Environment Variables**
   - Under **System Variables**, find **Path**
   - Click **Edit** → **New**
   - Add: `C:\flutter\bin` (or your Flutter path)
   - Click **OK** on all windows
   - **Restart Command Prompt**

### Step 3: Get Dependencies
```cmd
flutter pub get
```

### Step 4: Check Connected Devices
```cmd
flutter devices
```

You should see your connected device or emulator.

### Step 5: Run App
```cmd
flutter run
```

Wait for build to complete (2-5 minutes first time).

---

## 🎮 Testing the App

### 1. Create Account
- Open app
- Enter calculator passcode: **1234**
- Tap **Sign Up**
- Enter email and password
- Create username

### 2. Test Features

#### Friends
1. Tap **Friends** tab
2. Tap **search icon** (top right)
3. Search for a username
4. Send friend request

#### Chat
1. Go to **Chats** tab
2. Tap on a friend
3. Send a message
4. Tap **+** to send photo/video

#### Calls
1. Go to **Calls** tab
2. Or from chat, tap **call icon**
3. Make audio or video call

---

## 🐛 Troubleshooting

### "Flutter not found"
**Solution:**
1. Download Flutter: https://flutter.dev/docs/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to PATH
4. Restart terminal

### "No devices found"
**Solution:**
- For real device: Enable USB debugging
- For emulator: Start emulator from Android Studio

### "Gradle build failed"
**Solution:**
```cmd
cd G:\Calcx\android
gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### "Supabase error"
**Solution:**
- Check `.env` file exists in `G:\Calcx`
- Verify credentials are correct
- Restart app

### "Permission denied"
**Solution:**
- Grant permissions when app asks
- Or go to: Settings → Apps → Calcx → Permissions

---

## 📊 Build APK (Optional)

To create an installable APK:

```cmd
cd G:\Calcx
flutter build apk --release
```

APK will be at:
```
G:\Calcx\build\app\outputs\flutter-apk\app-release.apk
```

Copy this file to your phone and install!

---

## 🎉 You're All Set!

Your app is ready to run. Choose any method above and enjoy your social media app!

**Need help?** Check the documentation:
- `QUICK_START_GUIDE.md`
- `DEPLOYMENT_GUIDE.md`
- `CALLS_IMPLEMENTATION_COMPLETE.md`

---

## 📞 Quick Reference

### Important Files
- **Main app:** `lib/main.dart`
- **Environment:** `.env`
- **Database:** `supabase/complete_schema.sql`

### Important Commands
```cmd
flutter pub get          # Install dependencies
flutter run              # Run app
flutter build apk        # Build APK
flutter clean            # Clean build
flutter doctor           # Check setup
```

### Project Structure
```
G:\Calcx\
├── lib/                 # Flutter code
├── android/             # Android config
├── assets/              # Images, etc.
├── supabase/            # Database schema
└── .env                 # Configuration
```

---

**Happy coding!** 🚀✨
