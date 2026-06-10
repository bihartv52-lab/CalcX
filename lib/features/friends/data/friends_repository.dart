import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(SupabaseService.clientOrNull);
});

class FriendsRepository {
  FriendsRepository(this._supabase);

  final SupabaseClient? _supabase;

  /// Get user profile by ID
  Future<UserProfile?> getUserById(String userId) async {
    if (_supabase == null) return null;
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      return UserProfile.fromMap(response);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Search users by username or email
  Future<List<UserProfile>> searchUsers(String query) async {
    if (_supabase == null || query.trim().isEmpty) {
      return [];
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);

      return (response as List)
          .map((json) => UserProfile.fromMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Send friend request
  Future<void> sendFriendRequest(String friendId) async {
    if (_supabase == null) return;

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    Map<String, dynamic>? insertedRequest;
    try {
      final response = await _supabase.from('friend_requests').insert({
        'sender_id': myId,
        'receiver_id': friendId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      insertedRequest = response.firstOrNull;
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException sending friend request: ${e.code} - ${e.message}');
      if (e.code == '23505' || e.message.contains('duplicate key') || e.message.contains('23505')) {
        throw Exception('Friend request already sent.');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      final errorStr = e.toString();
      if (errorStr.contains('23505') || errorStr.contains('duplicate key')) {
        throw Exception('Friend request already sent.');
      }
      rethrow;
    }

    // Handle auto-accept client-side check & notifications
    if (insertedRequest != null) {
      bool autoAccept = true; // default true
      try {
        final profile = await _supabase.from('profiles').select('auto_accept_friends').eq('id', friendId).maybeSingle();
        if (profile != null && profile['auto_accept_friends'] != null) {
          autoAccept = profile['auto_accept_friends'] as bool;
        }
      } catch (_) {}

      if (autoAccept) {
        try {
          // 1. Update the request status in DB
          await _supabase.from('friend_requests').update({'status': 'accepted'}).eq('id', insertedRequest['id']);
          
          // 2. Insert the friendship records
          await _supabase.from('friends').insert([
            {
              'user_id': myId,
              'friend_id': friendId,
              'created_at': DateTime.now().toIso8601String(),
            },
            {
              'user_id': friendId,
              'friend_id': myId,
              'created_at': DateTime.now().toIso8601String(),
            },
          ]);

          // 3. Notify the sender that request was accepted
          final friendProfile = await _supabase.from('profiles').select('username').eq('id', friendId).maybeSingle();
          final friendUsername = friendProfile?['username'] as String? ?? 'Someone';
          await _supabase.from('notifications').insert({
            'user_id': myId,
            'type': 'friend_request_accepted',
            'title': 'Friend Request Accepted',
            'body': '$friendUsername is now your friend!',
            'data': {
              'request_id': insertedRequest['id'],
              'receiver_id': friendId,
            },
          });
        } catch (e) {
          debugPrint('Error handling client-side auto-accept: $e');
        }
      } else {
        // Send pending request notification to the receiver
        try {
          final myProfile = await _supabase.from('profiles').select('username').eq('id', myId).maybeSingle();
          final myUsername = myProfile?['username'] as String? ?? 'Someone';
          await _supabase.from('notifications').insert({
            'user_id': friendId,
            'type': 'friend_request',
            'title': 'New Friend Request',
            'body': '$myUsername sent you a friend request.',
            'data': {
              'request_id': insertedRequest['id'],
              'sender_id': myId,
            },
          });
        } catch (e) {
          debugPrint('Error inserting friend request notification: $e');
        }
      }
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    if (_supabase == null) return;

    try {
      // Update request status
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      // Get request details
      final request = await _supabase
          .from('friend_requests')
          .select()
          .eq('id', requestId)
          .single();

      final senderId = request['sender_id'] as String;
      final receiverId = request['receiver_id'] as String;

      // Create friendship (both directions)
      await _supabase.from('friends').insert([
        {
          'user_id': senderId,
          'friend_id': receiverId,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'user_id': receiverId,
          'friend_id': senderId,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      // Direct client-side insert to notify the sender
      try {
        final receiverProfile = await _supabase.from('profiles').select('username').eq('id', receiverId).maybeSingle();
        final receiverUsername = receiverProfile?['username'] as String? ?? 'Someone';
        await _supabase.from('notifications').insert({
          'user_id': senderId,
          'type': 'friend_request_accepted',
          'title': 'Friend Request Accepted',
          'body': '$receiverUsername is now your friend!',
          'data': {
            'request_id': requestId,
            'receiver_id': receiverId,
          },
        });
      } catch (e) {
        debugPrint('Error inserting friendship acceptance notification: $e');
      }
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    if (_supabase == null) return;

    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      rethrow;
    }
  }

  /// Get my friends list
  Future<List<UserProfile>> getFriends() async {
    if (_supabase == null) return [];

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await _supabase
          .from('friends')
          .select('friend_id, profiles!friends_friend_id_fkey(*)')
          .eq('user_id', myId);

      return (response as List)
          .map((item) => UserProfile.fromMap(item['profiles']))
          .toList();
    } catch (e) {
      debugPrint('Error getting friends: $e');
      return [];
    }
  }

  /// Get pending friend requests (received)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    if (_supabase == null) return [];

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await _supabase
          .from('friend_requests')
          .select('*, profiles!friend_requests_sender_id_fkey(*)')
          .eq('receiver_id', myId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  /// Remove friend
  Future<void> removeFriend(String friendId) async {
    if (_supabase == null) return;

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Remove both directions separately
      await _supabase
          .from('friends')
          .delete()
          .eq('user_id', myId)
          .eq('friend_id', friendId);

      await _supabase
          .from('friends')
          .delete()
          .eq('user_id', friendId)
          .eq('friend_id', myId);
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  /// Check if users are friends
  Future<bool> areFriends(String userId) async {
    if (_supabase == null) return false;

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      final response = await _supabase
          .from('friends')
          .select()
          .eq('user_id', myId)
          .eq('friend_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get pending friend requests sent by current user
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    if (_supabase == null) return [];

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await _supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', myId)
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting sent requests: $e');
      return [];
    }
  }
}
