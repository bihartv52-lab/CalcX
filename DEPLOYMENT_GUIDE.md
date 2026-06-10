# 🚀 Deployment Guide - Calcx Social App

## 📋 Prerequisites

- ✅ Flutter SDK installed
- ✅ Supabase account and project
- ✅ LiveKit account and project
- ✅ Firebase account (for push notifications)
- ✅ Android Studio / Xcode

---

## 1️⃣ Supabase Setup

### A. Create Project
1. Go to https://supabase.com
2. Create new project
3. Note your project URL and anon key

### B. Deploy Database Schema

1. Go to **SQL Editor** in Supabase Dashboard
2. Create a new query
3. Copy contents from `supabase/complete_schema.sql`
4. Run the query

**Note:** If you get "relation already exists" errors, that's okay! It means some tables are already created.

### C. Create Storage Bucket

1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Name: `media`
4. Set to **Public** (or configure RLS policies)
5. Click **Create bucket**

### D. Deploy Edge Function

#### Install Supabase CLI

```bash
# macOS/Linux
brew install supabase/tap/supabase

# Windows
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

#### Login and Deploy

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref ephrnrtnoykxggujbpgo

# Set environment variables
supabase secrets set LIVEKIT_API_KEY=APIntmvUf4ZGZJa
supabase secrets set LIVEKIT_API_SECRET=TY4Rfp2a9gefGxsRfz0MPpHIdbMo73c3HzQxSBbH2eRA

# Deploy the function
supabase functions deploy livekit-token
```

#### Verify Deployment

```bash
# Test the function
curl -X POST \
  'https://ephrnrtnoykxggujbpgo.supabase.co/functions/v1/livekit-token' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"room_name":"test-room","participant_name":"test-user"}'
```

---

## 2️⃣ LiveKit Setup

### Your LiveKit Credentials (Already Configured)

```
URL: wss://calcx-hk8fpmgd.livekit.cloud
API Key: APIntmvUf4ZGZJa
API Secret: TY4Rfp2a9gefGxsRfz0MPpHIdbMo73c3HzQxSBbH2eRA
```

✅ **Already added to `.env` file!**

### Verify LiveKit Project

1. Go to https://cloud.livekit.io
2. Login to your account
3. Select project: `calcx-hk8fpmgd`
4. Verify it's active

---

## 3️⃣ Firebase Setup (Optional - for Push Notifications)

### A. Create Firebase Project

1. Go to https://console.firebase.google.com
2. Create new project
3. Add Android app
4. Download `google-services.json`

### B. Configure Android

1. Place `google-services.json` in `android/app/`
2. Update `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

3. Update `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### C. Enable Cloud Messaging

1. In Firebase Console, go to **Cloud Messaging**
2. Enable **Cloud Messaging API**
3. Note your **Server Key**

---

## 4️⃣ Environment Configuration

### Your `.env` File (Already Configured)

```env
SUPABASE_URL=https://ephrnrtnoykxggujbpgo.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaHJucnRub3lreGdndWpicGdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MTg4OTYsImV4cCI6MjA5NDM5NDg5Nn0.RmIOtfTj6L5_slmY6edZc7HELiQtjKSd0Sp-vbopYjM
LIVEKIT_URL=wss://calcx-hk8fpmgd.livekit.cloud
LIVEKIT_API_KEY=APIntmvUf4ZGZJa
LIVEKIT_API_SECRET=TY4Rfp2a9gefGxsRfz0MPpHIdbMo73c3HzQxSBbH2eRA
LIVEKIT_TOKEN_FUNCTION=livekit-token
```

✅ **All credentials configured!**

---

## 5️⃣ Build & Run

### Install Dependencies

```bash
flutter pub get
```

### Run on Device/Emulator

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

### Build APK

```bash
# Build release APK
flutter build apk --release

# Build app bundle (for Play Store)
flutter build appbundle --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## 6️⃣ Testing

### Test Checklist

#### Authentication
- [ ] Sign up with email/password
- [ ] Login
- [ ] Logout

#### Friends
- [ ] Search users
- [ ] Send friend request
- [ ] Accept friend request
- [ ] View friends list

#### Chat
- [ ] Send text message
- [ ] Receive message (real-time)
- [ ] Send image
- [ ] Send video
- [ ] Send file
- [ ] See typing indicator

#### Calls
- [ ] Initiate audio call
- [ ] Initiate video call
- [ ] Accept incoming call
- [ ] Reject call
- [ ] Mute/unmute
- [ ] Toggle video
- [ ] End call
- [ ] View call history

### Test with 2 Devices

1. **Device A:** Login as User 1
2. **Device B:** Login as User 2
3. Add each other as friends
4. Test chat (should be real-time)
5. Test calls (audio and video)

---

## 7️⃣ Troubleshooting

### Common Issues

#### "Supabase is not configured"
**Solution:** 
- Check `.env` file exists
- Verify credentials are correct
- Restart app after changing `.env`

#### "Storage bucket not found"
**Solution:**
- Create `media` bucket in Supabase Dashboard
- Set bucket to Public or configure RLS

#### "LiveKit token error"
**Solution:**
- Deploy edge function: `supabase functions deploy livekit-token`
- Set secrets: `supabase secrets set LIVEKIT_API_KEY=...`
- Verify function is deployed in Supabase Dashboard

#### "Permission denied"
**Solution:**
- Check `AndroidManifest.xml` has all permissions
- Request permissions at runtime
- Go to app settings and enable permissions

#### Calls not connecting
**Solution:**
- Verify LiveKit credentials in `.env`
- Check edge function is deployed
- Test edge function with curl
- Check internet connection

#### Messages not real-time
**Solution:**
- Verify Supabase Realtime is enabled
- Check tables are added to realtime publication
- Restart app

---

## 8️⃣ Production Deployment

### Android Play Store

1. **Update version** in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

2. **Create keystore**:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

3. **Configure signing** in `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

4. **Build app bundle**:
```bash
flutter build appbundle --release
```

5. **Upload to Play Console**:
- Go to https://play.google.com/console
- Create new app
- Upload bundle from `build/app/outputs/bundle/release/`

### iOS App Store

1. **Update version** in `pubspec.yaml`

2. **Configure signing** in Xcode:
- Open `ios/Runner.xcworkspace`
- Select Runner → Signing & Capabilities
- Select your team

3. **Build archive**:
```bash
flutter build ios --release
```

4. **Upload to App Store Connect**:
- Open Xcode
- Product → Archive
- Upload to App Store

---

## 9️⃣ Monitoring & Analytics

### Supabase Dashboard

Monitor:
- Database queries
- Storage usage
- Edge function invocations
- Realtime connections

### LiveKit Dashboard

Monitor:
- Active rooms
- Participant count
- Bandwidth usage
- Call quality

---

## 🔐 Security Checklist

- [ ] Environment variables not committed to git
- [ ] RLS policies enabled on all tables
- [ ] Storage bucket has proper policies
- [ ] Edge function validates authentication
- [ ] API keys are server-side only
- [ ] HTTPS/WSS for all connections
- [ ] Input validation on all forms
- [ ] Rate limiting on API calls

---

## 📊 Performance Optimization

### Database
- ✅ Indexes on frequently queried columns
- ✅ Pagination for large lists
- ✅ Efficient RLS policies

### Media
- ✅ Image compression (max 1920x1920)
- ✅ Thumbnail generation
- ✅ Cached network images
- ⏳ Video compression (TODO)

### Calls
- ✅ Adaptive bitrate
- ✅ Echo cancellation
- ✅ Noise suppression

---

## 📝 Maintenance

### Regular Tasks

**Weekly:**
- Check error logs
- Monitor storage usage
- Review call quality metrics

**Monthly:**
- Update dependencies
- Review security policies
- Backup database

**Quarterly:**
- Performance audit
- User feedback review
- Feature planning

---

## 🆘 Support

### Resources

- **Supabase Docs:** https://supabase.com/docs
- **LiveKit Docs:** https://docs.livekit.io
- **Flutter Docs:** https://flutter.dev/docs

### Contact

- **Supabase Support:** https://supabase.com/support
- **LiveKit Support:** https://livekit.io/support

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Database schema deployed
- [ ] Storage bucket created
- [ ] Edge function deployed
- [ ] Environment variables set
- [ ] Permissions configured

### Deployment
- [ ] Build release APK/IPA
- [ ] Test on real devices
- [ ] Upload to store
- [ ] Submit for review

### Post-Deployment
- [ ] Monitor error logs
- [ ] Check analytics
- [ ] Gather user feedback
- [ ] Plan next iteration

---

## 🎉 You're Ready!

Your Calcx social app is now configured and ready to deploy!

**Next Steps:**
1. Deploy edge function: `supabase functions deploy livekit-token`
2. Test on real devices
3. Build release APK
4. Deploy to Play Store

**Good luck!** 🚀
