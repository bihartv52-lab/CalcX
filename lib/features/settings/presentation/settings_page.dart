import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/services/settings_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/calculator/data/passcode_repository.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _newPasscode = TextEditingController();
  final _notificationText = TextEditingController(
    text: 'Your previous calculation is pending.',
  );
  final _newUsername = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _autoAcceptFriends = true;
  bool _isLoadingAutoAccept = true;
  bool _isUpdatingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadAutoAcceptSetting();
  }

  Future<void> _loadAutoAcceptSetting() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) {
      // Local mode username loading
      final username = await ref.read(authRepositoryProvider).localUsername;
      if (username != null) {
        setState(() {
          _newUsername.text = username;
          _isLoadingAutoAccept = false;
        });
      }
      return;
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await client
          .from('profiles')
          .select('auto_accept_friends, custom_notification_text, username')
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        setState(() {
          if (response['auto_accept_friends'] != null) {
            _autoAcceptFriends = response['auto_accept_friends'] as bool;
          }
          if (response['custom_notification_text'] != null) {
            _notificationText.text = response['custom_notification_text'] as String;
          }
          if (response['username'] != null) {
            _newUsername.text = response['username'] as String;
          }
          _isLoadingAutoAccept = false;
        });
      } else {
        setState(() => _isLoadingAutoAccept = false);
      }
    } catch (_) {
      setState(() => _isLoadingAutoAccept = false);
    }
  }

  Future<void> _updateUsername() async {
    final username = _newUsername.text.trim();
    if (username.isEmpty) return;

    setState(() => _isUpdatingAccount = true);
    try {
      await ref.read(authRepositoryProvider).updateUsername(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Username updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAccount = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPass = _currentPassword.text;
    final newPass = _newPassword.text;
    if (newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password cannot be empty')),
      );
      return;
    }

    setState(() => _isUpdatingAccount = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(currentPass, newPass);
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAccount = false);
    }
  }

  Future<void> _pickWallpaper() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      
      // Extract color seed from image
      try {
        final imageBytes = await file.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          final pixel = image.getPixel(image.width ~/ 2, image.height ~/ 2);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          final extractedColor = Color.fromARGB(255, r, g, b);
          await ref.read(themeServiceProvider.notifier).setSeedColor(extractedColor);
        }
      } catch (e) {
        debugPrint('Color extraction failed, falling back to default seed: $e');
      }

      await ref.read(themeServiceProvider.notifier).setGlobalWallpaper(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Custom wallpaper updated globally!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking wallpaper: $e')),
        );
      }
    }
  }

  Future<void> _backupTheme() async {
    try {
      final path = await ref.read(themeServiceProvider.notifier).exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Backup saved locally to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error backing up: $e')),
        );
      }
    }
  }

  Future<void> _restoreTheme() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final path = '${appDir.path}/theme_backup.json';
      if (!await File(path).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backup file found at default location.')),
        );
        return;
      }
      await ref.read(themeServiceProvider.notifier).importBackup(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Theme configuration restored!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring: $e')),
        );
      }
    }
  }

  Future<void> _toggleAutoAccept(bool value) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _autoAcceptFriends = value;
    });

    try {
      await client
          .from('profiles')
          .update({'auto_accept_friends': value})
          .eq('id', userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating setting: $e')),
        );
      }
    }
  }

  Future<void> _launchApkDownload() async {
    final url = Uri.parse('https://bihartv52-2243s-projects.vercel.app/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download page')),
        );
      }
    }
  }

  @override
  void dispose() {
    _newPasscode.dispose();
    _notificationText.dispose();
    _newUsername.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final blurEnabled = ref.watch(blurInBackgroundProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Privacy gate',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasscode,
                decoration: const InputDecoration(
                  labelText: 'New calculator expression',
                  prefixIcon: Icon(Icons.calculate_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final newPasscode = _newPasscode.text.trim();
                  if (newPasscode.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a calculation'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  try {
                    // Validate the expression can be evaluated
                    final engine = ref.read(calculatorEngineProvider);
                    engine.evaluate(newPasscode);
                    
                    // Save the passcode
                    await ref
                        .read(passcodeRepositoryProvider)
                        .savePasscode(newPasscode);
                    _newPasscode.clear();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Passcode updated successfully'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid calculation. Please enter a valid expression.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save passcode'),
              ),
            ],
          ),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Account Settings',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newUsername,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isUpdatingAccount ? null : _updateUsername,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Update username'),
              ),
              const Divider(height: 24, thickness: 1),
              const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_open_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isUpdatingAccount ? null : _changePassword,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Change password'),
              ),
            ],
          ),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notificationText,
                decoration: const InputDecoration(
                  labelText: 'Notification text',
                  prefixIcon: Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final text = _notificationText.text.trim();
                  if (text.isEmpty) return;

                  // Save locally
                  await ref
                      .read(passcodeRepositoryProvider)
                      .saveNotificationText(text);

                  // Save to Supabase profiles table
                  final client = SupabaseService.clientOrNull;
                  if (client != null) {
                    final userId = client.auth.currentUser?.id;
                    if (userId != null) {
                      try {
                        await client
                            .from('profiles')
                            .update({'custom_notification_text': text})
                            .eq('id', userId);
                      } catch (e) {
                        debugPrint('Error updating custom notification text in DB: $e');
                      }
                    }
                  }

                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification text saved')),
                  );
                },
                icon: const Icon(Icons.done_rounded),
                label: const Text('Save text'),
              ),
            ],
          ),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Consumer(
            builder: (context, ref, child) {
              final settings = ref.watch(themeServiceProvider);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Theme & Background',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: settings.themeName,
                    decoration: const InputDecoration(
                      labelText: 'App Theme Preset',
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sunset', child: Text('Sunset (Orange & Rose)')),
                      DropdownMenuItem(value: 'crimson', child: Text('Crimson (Red & Gold)')),
                      DropdownMenuItem(value: 'light', child: Text('Material Light Mode')),
                      DropdownMenuItem(value: 'amoled', child: Text('AMOLED Deep Black')),
                      DropdownMenuItem(value: 'material_you', child: Text('Material You (Dynamic)')),
                      DropdownMenuItem(value: 'gallery', child: Text('Custom Wallpaper')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(themeServiceProvider.notifier).setThemeName(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Wallpaper pick button
                  OutlinedButton.icon(
                    onPressed: _pickWallpaper,
                    icon: const Icon(Icons.wallpaper_rounded),
                    label: const Text('Select Custom Wallpaper'),
                  ),
                  
                  if (settings.globalWallpaperPath != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Wallpaper Controls',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    // Opacity slider
                    Row(
                      children: [
                        const Icon(Icons.opacity_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Opacity: ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: settings.wallpaperOpacity,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (val) {
                              ref.read(themeServiceProvider.notifier).setWallpaperSliders(opacity: val);
                            },
                          ),
                        ),
                        Text('${(settings.wallpaperOpacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    
                    // Blur slider
                    Row(
                      children: [
                        const Icon(Icons.blur_on_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Blur: ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: settings.wallpaperBlur,
                            min: 0.0,
                            max: 20.0,
                            onChanged: (val) {
                              ref.read(themeServiceProvider.notifier).setWallpaperSliders(blur: val);
                            },
                          ),
                        ),
                        Text('${settings.wallpaperBlur.toInt()}px', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    
                    // Dim slider
                    Row(
                      children: [
                        const Icon(Icons.brightness_medium_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Dimming: ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: settings.wallpaperDim,
                            min: 0.0,
                            max: 0.9,
                            onChanged: (val) {
                              ref.read(themeServiceProvider.notifier).setWallpaperSliders(dim: val);
                            },
                          ),
                        ),
                        Text('${(settings.wallpaperDim * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                  
                  const Divider(height: 24, thickness: 1),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _backupTheme,
                          icon: const Icon(Icons.backup_rounded),
                          label: const Text('Backup Theme'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _restoreTheme,
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Restore Theme'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              if (!_isLoadingAutoAccept)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoAcceptFriends,
                  onChanged: _toggleAutoAccept,
                  title: const Text('Auto-accept friend requests'),
                  subtitle: const Text('Automatically accept new incoming requests'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: biometricEnabled,
                onChanged: (value) {
                  ref.read(biometricEnabledProvider.notifier).setEnabled(value);
                },
                title: const Text('Enable biometric unlock'),
                subtitle: const Text('Use fingerprint on calculator screen'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: blurEnabled,
                onChanged: (value) {
                  ref.read(blurInBackgroundProvider.notifier).setEnabled(value);
                },
                title: const Text('Blur private screens in background'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: reduceMotion,
                onChanged: (value) {
                  ref.read(reduceMotionProvider.notifier).setEnabled(value);
                },
                title: const Text('Reduce motion'),
              ),
            ],
          ),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CalcX Version & Updates',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ensure your app has the latest privacy features, encrypted chats, and game wagers.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _launchApkDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Latest APK'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff10b981), // Premium green accent
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            // Show confirmation dialog
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            
            if (confirmed != true || !context.mounted) {
              return;
            }
            
            try {
              await ref.read(authRepositoryProvider).signOut();
              if (!context.mounted) {
                return;
              }
              // Navigate to calculator and show message
              context.go(AppRoutes.calculator);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Signed out successfully'),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error signing out: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
