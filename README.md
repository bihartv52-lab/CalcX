# 📱 Calcx - Social Media App

A feature-rich social media application built with Flutter, Supabase, and LiveKit.

![Flutter](https://img.shields.io/badge/Flutter-3.11+-blue.svg)
![Supabase](https://img.shields.io/badge/Supabase-Enabled-green.svg)
![LiveKit](https://img.shields.io/badge/LiveKit-WebRTC-orange.svg)

---

## ✨ Features

### 🔐 Authentication
- Email/password authentication
- Secure calculator disguise
- Biometric authentication support

### 👥 Friends Management
- Search users by username
- Send/accept/reject friend requests
- Online status indicators
- Friend list with quick actions

### 💬 Real-time Chat
- Text messaging
- Image sharing
- Video sharing
- File sharing
- Typing indicators
- Read receipts
- Message reactions
- Edit/delete messages

### 📞 Audio/Video Calls
- High-quality audio calls
- HD video calls
- Call controls (mute, speaker, video toggle)
- Camera switching (front/back)
- Call history
- Missed call notifications

### 🎉 Party Rooms
- Create public/private rooms
- Room chat
- Participant management
- Invite codes
- Media sync (coming soon)

### 🔔 Notifications
- Push notifications
- In-app notifications
- Friend request alerts
- Message notifications
- Call notifications

---

## 🏗️ Architecture

### Tech Stack
- **Frontend:** Flutter 3.11+
- **Backend:** Supabase (PostgreSQL + Realtime)
- **Calls:** LiveKit (WebRTC)
- **Notifications:** Firebase Cloud Messaging
- **State Management:** Riverpod
- **Navigation:** go_router

### Project Structure
```
lib/
├── app/                    # App configuration
├── core/
│   ├── models/            # Data models
│   ├── services/          # Core services
│   └── widgets/           # Reusable widgets
└── features/
    ├── auth/              # Authentication
    ├── calculator/        # Calculator disguise
    ├── calls/             # Audio/video calls
    ├── chat/              # Messaging
    ├── friends/           # Friend management
    ├── media/             # Media upload/download
    ├── rooms/             # Party rooms
    └── settings/          # App settings
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.11+
- Dart SDK 3.11+
- Android Studio / Xcode
- Supabase account
- LiveKit account

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd Calcx
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure environment**

Create `.env` file (already configured):
```env
SUPABASE_URL=https://ephrnrtnoykxggujbpgo.supabase.co
SUPABASE_ANON_KEY=your_anon_key
LIVEKIT_URL=wss://calcx-hk8fpmgd.livekit.cloud
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
```

4. **Deploy database schema**
- Go to Supabase Dashboard → SQL Editor
- Run `supabase/complete_schema.sql`

5. **Create storage bucket**
- Go to Supabase Dashboard → Storage
- Create bucket named `media`
- Set to Public

6. **Deploy edge function**
```bash
supabase functions deploy livekit-token
```

7. **Run the app**
```bash
flutter run
```

---

## 📚 Documentation

- **[Quick Start Guide](QUICK_START_GUIDE.md)** - Get started quickly
- **[Implementation Summary](IMPLEMENTATION_COMPLETE_SUMMARY.md)** - What's implemented
- **[Call Management Explained](CALL_MANAGEMENT_EXPLAINED.md)** - How calls work
- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Deploy to production
- **[TODO Phase 1](TODO_PHASE1.md)** - Remaining tasks

---

## 🎯 Current Status

### Phase 1: Foundation (85% Complete)

| Feature | Status | Completion |
|---------|--------|------------|
| Core Infrastructure | ✅ Complete | 100% |
| User Management | ✅ Complete | 100% |
| Friends System | ✅ Complete | 100% |
| Chat & Messaging | ✅ Complete | 95% |
| Media Upload | ✅ Complete | 90% |
| Audio/Video Calls | ✅ Complete | 100% |
| Rooms | 🔄 In Progress | 30% |
| Notifications | 🔄 In Progress | 50% |

---

## 🧪 Testing

### Run Tests
```bash
flutter test
```

### Test with 2 Devices
1. Login as User 1 on Device A
2. Login as User 2 on Device B
3. Add each other as friends
4. Test chat (real-time)
5. Test calls (audio/video)

---

## 📦 Build

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

---

## 🔐 Security

- ✅ Row Level Security (RLS) on all tables
- ✅ Secure token generation (server-side)
- ✅ Environment variables not in git
- ✅ HTTPS/WSS for all connections
- ✅ Input validation
- ✅ Permission handling

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- **Supabase** - Backend infrastructure
- **LiveKit** - WebRTC infrastructure
- **Flutter** - UI framework
- **Firebase** - Push notifications

---

## 📞 Support

For issues and questions:
- Check [Documentation](QUICK_START_GUIDE.md)
- Review [Troubleshooting](DEPLOYMENT_GUIDE.md#troubleshooting)
- Open an issue on GitHub

---

## 🗺️ Roadmap

### Phase 2: Advanced Features
- [ ] Group chats
- [ ] Message forwarding
- [ ] Voice messages
- [ ] Screen sharing
- [ ] Music sync in rooms
- [ ] End-to-end encryption

### Phase 3: Polish
- [ ] Dark/light theme toggle
- [ ] Custom themes
- [ ] Stickers and GIFs
- [ ] Message search
- [ ] Advanced filters
- [ ] Analytics dashboard

---

## 📊 Stats

- **Lines of Code:** ~15,000+
- **Features:** 8 major features
- **Models:** 6 data models
- **Screens:** 20+ screens
- **Dependencies:** 25+ packages

---

## 🎉 Credits

Built with ❤️ using Flutter, Supabase, and LiveKit.

**Version:** 1.0.0
**Last Updated:** May 18, 2026

---

## 🚀 Get Started Now!

```bash
flutter pub get
flutter run
```

**Happy coding!** 🎨✨
