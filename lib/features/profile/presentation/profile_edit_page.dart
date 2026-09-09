import 'dart:io';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _nicknameController;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _currentAvatarUrl;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _nicknameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final profileAsync = ref.watch(myProfileProvider);
      profileAsync.whenData((profile) {
        if (profile != null && !_isInitialized) {
          _displayNameController.text = profile.displayName;
          _bioController.text = profile.bio ?? '';
          _nicknameController.text = profile.nickname ?? '';
          _currentAvatarUrl = profile.avatarUrl;
          _isInitialized = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  String _getInitials(String displayName, String username) {
    final name = displayName.trim().isNotEmpty ? displayName.trim() : username.trim();
    final parts = name.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final authRepo = ref.read(authRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final userId = authRepo.currentUser?.id ?? 'local_user_id';

    try {
      final XFile? pickedFile = await profileRepo.pickAvatarImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await pickedFile.readAsBytes();
      final uploadedUrl = await profileRepo.uploadAvatar(
        userId: userId,
        bytes: bytes,
        filename: pickedFile.name,
      );

      setState(() {
        _currentAvatarUrl = uploadedUrl;
      });

      // Update avatar URL in profile immediately
      await profileRepo.updateProfile(
        userId: userId,
        avatarUrl: uploadedUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar upload failed: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.purpleAccent),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = ref.read(authRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final userId = authRepo.currentUser?.id ?? 'local_user_id';

    setState(() => _isSaving = true);

    try {
      await profileRepo.updateProfile(
        userId: userId,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        nickname: _nicknameController.text.trim(),
        avatarUrl: _currentAvatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, color: Colors.greenAccent),
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          final displayName = _displayNameController.text.isNotEmpty
              ? _displayNameController.text
              : (profile?.displayName ?? '');
          final username = profile?.username ?? 'User';

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Circular Avatar Card Section
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        key: const ValueKey('circular_avatar_clip'),
                        child: Container(
                          width: 110,
                          height: 110,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                              ? Image.network(
                                  _currentAvatarUrl!,
                                  key: const ValueKey('avatar_network_image'),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _getInitials(displayName, username),
                                      key: const ValueKey('avatar_initials_fallback'),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _getInitials(displayName, username),
                                    key: const ValueKey('avatar_initials_fallback'),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _isUploadingAvatar ? null : _showAvatarSourceSheet,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '@$username',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public Identity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Display Name Field
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'e.g. Alex Rivera',
                          prefixIcon: Icon(Icons.person_rounded),
                          helperText: '2 - 50 characters',
                        ),
                        validator: UserProfile.validateDisplayName,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Nickname Field
                      TextFormField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          hintText: 'e.g. CyberPilot',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          helperText: 'Max 30 characters (Optional)',
                        ),
                        validator: UserProfile.validateNickname,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Custom Bio Field
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText: 'Tell the community about yourself...',
                          prefixIcon: Icon(Icons.notes_rounded),
                          alignLabelWithHint: true,
                        ),
                        validator: UserProfile.validateBio,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Profile Button
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text(
                    'Save Profile Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading profile: $err'),
        ),
      ),
    );
  }
}
