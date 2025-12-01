import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/animations/page_transitions.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../payments/driver_payments_screen.dart';
import 'stripe_connect_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userProfile.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile data'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            profile.name.isNotEmpty
                                ? profile.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                profile.email,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                'Role: ${profile.role}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (profile.role == AppConstants.roleBoth) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: const Text('Switch Role'),
                      subtitle: Text('Current: ${profile.defaultRole}'),
                      trailing: Switch(
                        value: profile.defaultRole == AppConstants.roleDriver,
                        onChanged: (value) async {
                          final firebaseService = ref.read(
                            firebaseServiceProvider,
                          );
                          final newRole = value
                              ? AppConstants.roleDriver
                              : AppConstants.roleCustomer;
                          
                          await firebaseService.updateUserRole(
                            profile.id,
                            newRole,
                          );
                          
                          // Wait a moment for Firestore to update
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // Navigate to home to refresh the UI
                          if (context.mounted) {
                            context.go('/home');
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit Profile'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransitions.slideTransition(
                              const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransitions.slideTransition(
                              const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Driver-specific options - only show when in driver mode
                if (profile.defaultRole == AppConstants.roleDriver) ...[
                  Text(
                    'Driver',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.payments),
                          title: const Text('Payment History'),
                          subtitle: const Text('View your earnings and payment history'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideTransition(
                                const DriverPaymentsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.account_circle),
                          title: const Text('Stripe Connect Setup'),
                          subtitle: const Text('Connect your Stripe account for payouts'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideTransition(
                                const StripeConnectScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final firebaseService = ref.read(firebaseServiceProvider);
                      await firebaseService.signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
