# 🚀 CalcX Setup & Build Guide

## 📋 Prerequisites Completed ✅

All code changes have been implemented! Here's what was done:

### ✅ Features Implemented:
1. **Calculator Passcode Lock** - First calculation becomes secret passcode
2. **Modern Gen Z Signup Page** - Beautiful, modern UI with animations
3. **Biometric Settings** - Fingerprint removed by default, added to settings
4. **App Name Changed** - "Calculator" instead of "CalcX" for stealth
5. **Improved Error Messages** - Better Supabase configuration messages

## 🎨 App Icon Setup (REQUIRED)

You provided a beautiful calculator icon. To use it:

### Step 1: Save the Icon
Save your calculator icon image as:
```
g:\Calcx\assets\images\app_icon.png
```

**Requirements:**
- Format: PNG with transparency
- Size: At least 1024x1024 pixels
- The image you provided is perfect!

### Step 2: Generate Icon Files
Open terminal in `g:\Calcx` and run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically create all required icon sizes for Android.

## 🔧 Supabase Configuration (Optional)

If you want to enable authentication, you need to provide Supabase credentials.

### Option 1: Environment Variables (Recommended for Development)
Create a file `g:\Calcx\.env` (already exists) and add:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Option 2: Build-time Configuration (For Release)
When building APK, use:
```bash
flutter build apk --release ^
  --dart-define=SUPABASE_URL=your_url ^
  --dart-define=SUPABASE_ANON_KEY=your_key
```

### Option 3: Skip Authentication
The app works without Supabase! Users will see a message that auth is not configured, but the calculator lock feature works perfectly.

## 📦 Building the APK

### Quick Build (Using Your Script)
Simply run:
```bash
G:\Calcx\BUILD-CALCX-APK.bat
```

This will:
1. Get dependencies
2. Build debug APK (faster)
3. Copy to `G:\CalcX.apk`

### Release Build (Smaller, Optimized)
For production/distribution:
```bash
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

### Release Build with Supabase
```bash
flutter build apk --release ^
  --dart-define=SUPABASE_URL=your_url ^
  --dart-define=SUPABASE_ANON_KEY=your_key
```

## 🧪 Testing the Features

### 1. Test Calculator Lock
1. Open app → See "Calculator" screen
2. Notice instruction: "Set your passcode as a calculation and press ="
3. Enter: `0-0=` (or any calculation)
4. See result, then navigate to signup page
5. Close and reopen app
6. Enter: `0-0=` again → Unlocks to main app
7. Enter: `5+5=` (wrong passcode) → Shows "10" like normal calculator

### 2. Test Modern Signup Page
1. After setting passcode, you'll see the new signup page
2. Notice the gradient icon, emoji headers
3. Toggle between "Sign up" and "Log in" tabs
4. Try entering credentials (will show Supabase message if not configured)

### 3. Test Biometric Settings
1. Unlock app with passcode
2. Go to Settings
3. Find "Enable biometric unlock" toggle
4. Enable it
5. Go back to calculator screen (logout)
6. Notice fingerprint button appears
7. Disable in settings → Button disappears

## 📱 Installation on Phone

1. Copy the APK to your phone:
   - Via USB: Copy `G:\CalcX.apk` to phone storage
   - Via cloud: Upload to Google Drive, download on phone

2. On your phone:
   - Open the APK file
   - Allow "Install from unknown sources" if prompted
   - Install the app

3. The app will appear as "Calculator" in your app drawer 🎭

## 🎯 App Behavior

### Stealth Features:
- ✅ App name: "Calculator" (not CalcX)
- ✅ Icon: Looks like a real calculator
- ✅ Wrong passcode: Shows real calculator results
- ✅ No hints: Nothing indicates it's a hidden app

### Security:
- ✅ Passcode encrypted with SHA-256 + salt
- ✅ Stored in secure storage
- ✅ Optional biometric unlock
- ✅ Can change passcode in settings

## 🐛 Troubleshooting

### "Flutter not found"
Use the full path from your build script:
```bash
C:\Users\avigu\Downloads\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat
```

### "Supabase not configured"
This is normal! The app works without it. The calculator lock feature is independent of Supabase.

### Icon not updating
1. Make sure `app_icon.png` is in `assets/images/`
2. Run `flutter pub run flutter_launcher_icons`
3. Rebuild the APK
4. Uninstall old app from phone before installing new one

### Build fails
1. Run `flutter clean`
2. Run `flutter pub get`
3. Try building again

## 📝 Quick Command Reference

```bash
# Get dependencies
flutter pub get

# Generate icons (after saving app_icon.png)
flutter pub run flutter_launcher_icons

# Build debug APK (fast)
flutter build apk --debug

# Build release APK (optimized)
flutter build apk --release

# Run on connected device
flutter run

# Clean build files
flutter clean
```

## 🎉 You're All Set!

The only manual step remaining is:
1. Save your calculator icon as `assets/images/app_icon.png`
2. Run `flutter pub run flutter_launcher_icons`
3. Build the APK

Everything else is ready to go! 🚀
