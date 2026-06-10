# 🚀 Quick Start Guide - Calcx Social App

## What's Been Implemented

### ✅ Working Features (Ready to Test)

1. **User Search** - Find users by username
2. **Friend Requests** - Send, accept, reject friend requests
3. **Friends List** - View all friends with online status
4. **Real-time Chat** - Send/receive messages instantly
5. **Media Sharing** - Share photos, videos, and files
6. **Typing Indicators** - See when someone is typing
7. **Chat List** - View recent conversations

---

## 🏃 Quick Start

### 1. Prerequisites
```bash
# Make sure you have:
- Flutter SDK installed
- Supabase project created
- .env file configured
```

### 2. Configure Supabase

#### A. Create Storage Bucket
1. Go to Supabase Dashboard → Storage
2. Create a new bucket named `media`
3. Set it to **Public** (or configure RLS policies)

#### B. Update .env File
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

#### C. Run Database Schema
```sql
-- Run the complete schema from:
supabase/complete_schema.sql
```

### 3. Run the App
```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

---

## 📱 How to Use

### Create Account
1. Open app
2. Enter calculator passcode (default: 1234)
3. Sign up with email/password
4. Create username and display name

### Add Friends
1. Go to **Friends** tab
2. Tap **search icon** (top right)
3. Search for username
4. Tap **person_add** icon to send request

### Accept Friend Requests
1. Go to **Friends** tab
2. See pending requests at top
3. Tap **✓** to accept or **✗** to reject

### Start Chatting
1. Go to **Chats** tab
2. Tap on a friend
3. Type message and send
4. Or tap **+** to send media

### Send Media
1. In chat, tap **+** button
2. Choose:
   - Photo from Gallery
   - Take Photo
   - Video
   - File
3. Wait for upload
4. Media appears in chat

---

## 🧪 Testing Checklist

### User Management
- [ ] Create account
- [ ] Search for users
- [ ] Send friend request
- [ ] Accept friend request
- [ ] View friends list
- [ ] Remove friend

### Chat
- [ ] Send text message
- [ ] Receive message (real-time)
- [ ] See typing indicator
- [ ] Send photo
- [ ] Send video
- [ ] Send file
- [ ] View chat list
- [ ] See unread count

### Media
- [ ] Pick image from gallery
- [ ] Take photo with camera
- [ ] Upload video
- [ ] Upload file
- [ ] See upload progress
- [ ] View media in chat

---

## 🔧 Troubleshooting

### "Supabase is not configured"
- Check `.env` file exists
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Restart app after changing .env

### "Storage bucket not found"
- Create `media` bucket in Supabase Dashboard
- Set bucket to Public or configure RLS

### "Permission denied"
- Check Android permissions in `AndroidManifest.xml`
- Request permissions at runtime
- Go to app settings and enable permissions

### Messages not appearing
- Check database schema is deployed
- Verify RLS policies are correct
- Check Supabase Realtime is enabled

### Media upload fails
- Check file size (max 50MB)
- Verify storage bucket exists
- Check internet connection

---

## 📂 Project Structure

```
lib/
├── core/
│   ├── models/
│   │   ├── user_profile.dart       # User data model
│   │   ├── message.dart            # Message model
│   │   ├── friend_request.dart     # Friend request model
│   │   ├── call.dart               # Call model
│   │   ├── room.dart               # Room model
│   │   └── app_notification.dart   # Notification model
│   │
│   └── services/
│       ├── permission_service.dart  # Handle permissions
│       ├── supabase_service.dart    # Supabase client
│       └── notification_service.dart # Notifications
│
├── features/
│   ├── friends/
│   │   ├── data/
│   │   │   └── friends_repository.dart  # Friend operations
│   │   └── presentation/
│   │       ├── friends_page.dart        # Friends list
│   │       └── user_search_page.dart    # User search
│   │
│   ├── chat/
│   │   ├── data/
│   │   │   └── chat_repository.dart     # Chat operations
│   │   └── presentation/
│   │       ├── chat_list_page.dart      # Chat list
│   │       └── chat_page.dart           # Chat screen
│   │
│   └── media/
│       └── data/
│           └── media_repository.dart    # Media upload/download
│
└── app/
    ├── app_router.dart              # Navigation
    └── calcx_app.dart               # Main app
```

---

## 🎯 Key Files to Know

### Models
- `lib/core/models/message.dart` - Message structure
- `lib/core/models/user_profile.dart` - User data

### Repositories
- `lib/features/chat/data/chat_repository.dart` - All chat operations
- `lib/features/friends/data/friends_repository.dart` - Friend operations
- `lib/features/media/data/media_repository.dart` - Media operations

### UI Pages
- `lib/features/chat/presentation/chat_page.dart` - Chat screen
- `lib/features/friends/presentation/friends_page.dart` - Friends list
- `lib/features/friends/presentation/user_search_page.dart` - User search

### Database
- `supabase/complete_schema.sql` - Complete database schema

---

## 🔐 Security Notes

### Row Level Security (RLS)
All tables have RLS policies:
- Users can only see their own data
- Messages visible to sender/receiver only
- Friend requests visible to involved parties
- Media files have user-specific paths

### Permissions
Required Android permissions:
- Camera (for taking photos)
- Storage/Photos (for gallery access)
- Microphone (for calls - future)
- Notifications (for push notifications)

---

## 📊 Database Tables

### Core Tables
- `profiles` - User profiles
- `friends` - Friend relationships
- `friend_requests` - Pending requests
- `messages` - Chat messages
- `message_reactions` - Message reactions
- `message_reads` - Read receipts
- `typing_indicators` - Typing status
- `media_files` - Uploaded media metadata
- `calls` - Call history
- `rooms` - Party rooms
- `room_participants` - Room members
- `notifications` - System notifications

---

## 🚀 Next Features to Implement

### Priority 1: Calls
- Incoming call screen
- Call controls (mute, speaker, video, end)
- Call history

### Priority 2: Rooms
- Create room UI
- Join room UI
- Room chat
- Participant list

### Priority 3: Notifications
- FCM configuration
- Push notifications
- In-app notification center

---

## 💡 Tips

1. **Test with 2 accounts** - Use 2 devices/emulators to test real-time features
2. **Check Supabase logs** - Dashboard → Logs for debugging
3. **Use Supabase Studio** - View data in real-time
4. **Enable Realtime** - Make sure Realtime is enabled for tables
5. **Check RLS policies** - If data not showing, check RLS

---

## 📞 Common Issues

### Issue: "No users found" in search
**Solution:** Make sure you have created multiple accounts

### Issue: Messages not real-time
**Solution:** 
1. Check Supabase Realtime is enabled
2. Verify table is added to realtime publication
3. Check internet connection

### Issue: Media upload stuck
**Solution:**
1. Check file size (max 50MB)
2. Verify storage bucket exists
3. Check bucket permissions

### Issue: Friend request not appearing
**Solution:**
1. Pull to refresh
2. Check database for request
3. Verify RLS policies

---

## 🎨 UI Theme

The app uses a **glass-morphism** design:
- Dark background
- Frosted glass cards
- Neon accents
- Smooth animations

All new UI should match this theme using `GlassCard` widget.

---

## 📝 Code Conventions

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables: `camelCase`
- Private: `_leadingUnderscore`

### Structure
- Models in `lib/core/models/`
- Services in `lib/core/services/`
- Features in `lib/features/[feature]/`
- Each feature has `data/` and `presentation/`

### State Management
- Use Riverpod providers
- Repository pattern
- Streams for real-time data

---

## ✅ Ready to Go!

You now have a working social media app with:
- ✅ User management
- ✅ Friend system
- ✅ Real-time chat
- ✅ Media sharing
- ✅ Beautiful UI

**Start testing and enjoy!** 🎉

---

**Need Help?**
- Check `IMPLEMENTATION_COMPLETE_SUMMARY.md` for detailed info
- Review `PHASE1_IMPLEMENTATION_STATUS.md` for feature status
- See `supabase/complete_schema.sql` for database structure
