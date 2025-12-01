import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/notification_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isPermissionGranted = false;
  bool _isLoading = false;
  bool _isEmailNotificationsEnabled = true;
  bool _isSavingEmailPref = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
    _loadEmailNotificationPreference();
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await _notificationService.isPermissionGranted();
    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
      });
    }
  }

  Future<void> _loadEmailNotificationPreference() async {
    final userProfileAsync = ref.read(userProfileProvider);
    userProfileAsync.whenData((userProfile) {
      if (userProfile != null && mounted) {
        setState(() {
          _isEmailNotificationsEnabled = userProfile.emailNotificationsEnabled;
        });
      }
    });
  }

  Future<void> _requestPermission() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final granted = await _notificationService.requestPermissionManually();
      if (mounted) {
        setState(() {
          _isPermissionGranted = granted;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Notification permission granted!'
                  : 'Notification permission denied. Please enable in device settings.',
            ),
            backgroundColor: granted ? AppTheme.successColor : AppTheme.warningColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _updateEmailNotifications(bool enabled) async {
    if (_isSavingEmailPref) return;
    
    setState(() {
      _isSavingEmailPref = true;
      _isEmailNotificationsEnabled = enabled;
    });

    try {
      final authState = ref.read(authStateProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      
      if (authState.value != null) {
        await firebaseService.updateEmailNotificationsEnabled(
          authState.value!.uid,
          enabled,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled
                    ? 'Email notifications enabled'
                    : 'Email notifications disabled',
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEmailNotificationsEnabled = !enabled; // Revert on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update email notifications: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingEmailPref = false;
        });
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      await _notificationService.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to user profile changes to update email notification preference
    ref.listen(userProfileProvider, (previous, next) {
      next.whenData((userProfile) {
        if (userProfile != null && mounted) {
          setState(() {
            _isEmailNotificationsEnabled = userProfile.emailNotificationsEnabled;
          });
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Notifications',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: Text(
                    _isPermissionGranted
                        ? 'Notifications are enabled'
                        : 'Tap to enable notifications',
                  ),
                  value: _isPermissionGranted,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value && !_isPermissionGranted) {
                            _requestPermission();
                          } else if (!value) {
                            // Show message that they need to disable in device settings
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'To disable push notifications, go to device settings',
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  secondary: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications),
                ),
                if (!_isPermissionGranted) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications_active),
                    title: const Text('Request Permission'),
                    subtitle: const Text('Enable push notifications'),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isLoading ? null : _requestPermission,
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Test Notification'),
                  subtitle: const Text('Send a test notification'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _testNotification,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: Text(
                    _isEmailNotificationsEnabled
                        ? 'You will receive email updates about your orders'
                        : 'Email notifications are disabled',
                  ),
                  value: _isEmailNotificationsEnabled,
                  onChanged: _isSavingEmailPref
                      ? null
                      : (value) {
                          _updateEmailNotifications(value);
                        },
                  secondary: _isSavingEmailPref
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'App Preferences',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language settings coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.dark_mode),
                  title: const Text('Theme'),
                  subtitle: const Text('Light'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Theme settings coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'About',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('App Version'),
                  subtitle: Text('1.0.0'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy policy coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of service coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
