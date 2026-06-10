import 'dart:convert';

import 'package:calcx/core/services/secure_storage_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = SupabaseService.clientOrNull;
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(supabaseClient: supabase, storage: storage);
});

class AuthRepository {
  AuthRepository({
    required SupabaseClient? supabaseClient,
    required FlutterSecureStorage storage,
  }) : _supabase = supabaseClient,
       _storage = storage;

  final SupabaseClient? _supabase;
  final FlutterSecureStorage _storage;

  static const _localUserKey = 'calcx.local_user';
  static const _localEmailKey = 'calcx.local_email';
  static const _localUsernameKey = 'calcx.local_username';
  static const _localPasswordHashKey = 'calcx.local_password_hash';

  bool get _useLocal => _supabase == null;

  Stream<AuthState>? authChanges() => _supabase?.auth.onAuthStateChange;

  User? get currentUser => _supabase?.auth.currentUser;

  /// Returns true if a user is signed in (either Supabase or local).
  Future<bool> isSignedIn() async {
    if (!_useLocal) {
      return currentUser != null;
    }
    final localUser = await _storage.read(key: _localUserKey);
    return localUser == 'true';
  }

  Future<void> signIn({required String email, required String password}) async {
    final supabase = _supabase;
    if (supabase != null) {
      final response = await supabase.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user != null) {
        try {
          await supabase.from('profiles').update({
            'password': password,
          }).eq('id', user.id);
        } catch (_) {}
      }
      return;
    }

    // Local sign-in
    final storedEmail = await _storage.read(key: _localEmailKey);
    final storedHash = await _storage.read(key: _localPasswordHashKey);

    if (storedEmail == null || storedHash == null) {
      throw Exception('No account found. Please sign up first.');
    }

    if (email != storedEmail) {
      throw Exception('Invalid email or password.');
    }

    final inputHash = _hashPassword(password);
    if (inputHash != storedHash) {
      throw Exception('Invalid email or password.');
    }

    await _storage.write(key: _localUserKey, value: 'true');
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    // Validate email format
    if (email.isEmpty) {
      throw Exception('Email is required.');
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      throw Exception('Please enter a valid email address.');
    }

    var finalUsername = username.trim();
    if (finalUsername.isEmpty) {
      finalUsername = email
          .split('@')
          .first
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (finalUsername.length < 3) {
        finalUsername = '${finalUsername}_calcx';
      }
      if (finalUsername.length > 20) {
        finalUsername = finalUsername.substring(0, 20);
      }
    }

    // Validate username
    if (finalUsername.length < 3) {
      throw Exception('Username must be at least 3 characters.');
    }
    if (finalUsername.length > 20) {
      throw Exception('Username must be less than 20 characters.');
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(finalUsername)) {
      throw Exception(
        'Username can only contain letters, numbers, and underscores.',
      );
    }

    // Validate password
    if (password.isEmpty) {
      throw Exception('Password is required.');
    }
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw Exception('Password must contain at least one uppercase letter.');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      throw Exception('Password must contain at least one lowercase letter.');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw Exception('Password must contain at least one number.');
    }

    final supabase = _supabase;
    if (supabase != null) {
      // Check if username already exists
      final existingUser = await supabase
          .from('profiles')
          .select('username')
          .eq('username', finalUsername)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('Username already taken. Please choose another.');
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': finalUsername},
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed. Please try again.');
      }

      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': finalUsername,
        'display_name': finalUsername,
        'password': password,
      });
      return;
    }

    // Local sign-up
    final existingEmail = await _storage.read(key: _localEmailKey);
    if (existingEmail != null) {
      throw Exception('An account already exists. Please log in.');
    }

    await _storage.write(key: _localEmailKey, value: email);
    await _storage.write(key: _localUsernameKey, value: finalUsername);
    await _storage.write(
      key: _localPasswordHashKey,
      value: _hashPassword(password),
    );
    await _storage.write(key: _localUserKey, value: 'true');
  }

  Future<void> signOut() async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.auth.signOut();
      return;
    }
    await _storage.write(key: _localUserKey, value: 'false');
  }

  Future<String?> get localUsername async =>
      _storage.read(key: _localUsernameKey);

  /// Update current user's username
  Future<void> updateUsername(String newUsername) async {
    final finalUsername = newUsername.trim();
    if (finalUsername.length < 3) {
      throw Exception('Username must be at least 3 characters.');
    }
    if (finalUsername.length > 20) {
      throw Exception('Username must be less than 20 characters.');
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(finalUsername)) {
      throw Exception('Username can only contain letters, numbers, and underscores.');
    }

    final supabase = _supabase;
    if (supabase != null) {
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) throw Exception('Not signed in.');

      // Check if username already exists
      final existingUser = await supabase
          .from('profiles')
          .select('username')
          .eq('username', finalUsername)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('Username already taken. Please choose another.');
      }

      await supabase.from('profiles').update({
        'username': finalUsername,
        'display_name': finalUsername,
      }).eq('id', myId);
      return;
    }

    // Local mode
    await _storage.write(key: _localUsernameKey, value: finalUsername);
  }

  /// Update password (authenticated state)
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    if (newPassword.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }
    if (!newPassword.contains(RegExp(r'[A-Z]'))) {
      throw Exception('Password must contain at least one uppercase letter.');
    }
    if (!newPassword.contains(RegExp(r'[a-z]'))) {
      throw Exception('Password must contain at least one lowercase letter.');
    }
    if (!newPassword.contains(RegExp(r'[0-9]'))) {
      throw Exception('Password must contain at least one number.');
    }

    final supabase = _supabase;
    if (supabase != null) {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not signed in.');

      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      // Update in profiles table
      await supabase.from('profiles').update({
        'password': newPassword,
      }).eq('id', user.id);
      return;
    }

    // Local mode
    final storedHash = await _storage.read(key: _localPasswordHashKey);
    final inputHash = _hashPassword(currentPassword);
    if (storedHash != inputHash) {
      throw Exception('Current password is incorrect.');
    }
    await _storage.write(key: _localPasswordHashKey, value: _hashPassword(newPassword));
  }

  /// Request password reset link (unauthenticated state)
  Future<void> sendPasswordReset(String email) async {
    final emailText = email.trim();
    if (emailText.isEmpty) {
      throw Exception('Email is required.');
    }

    final supabase = _supabase;
    if (supabase != null) {
      await supabase.auth.resetPasswordForEmail(emailText);
      return;
    }

    // Local mode
    final storedEmail = await _storage.read(key: _localEmailKey);
    if (storedEmail == null || storedEmail != emailText) {
      throw Exception('No local account found with that email.');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}

final authChangesProvider = StreamProvider<AuthState?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authChanges() ?? const Stream.empty();
});
