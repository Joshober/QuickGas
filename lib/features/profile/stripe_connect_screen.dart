import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

class StripeConnectScreen extends ConsumerStatefulWidget {
  const StripeConnectScreen({super.key});

  @override
  ConsumerState<StripeConnectScreen> createState() => _StripeConnectScreenState();
}

class _StripeConnectScreenState extends ConsumerState<StripeConnectScreen> {
  bool _isLoading = false;
  String? _currentAccountId;
  bool _isOnboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccountId();
  }

  Future<void> _loadCurrentAccountId() async {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.value == null) return;

      final firebaseService = ref.read(firebaseServiceProvider);
      final accountId = await firebaseService.getUserStripeAccountId(authState.value!.uid);

      setState(() {
        _currentAccountId = accountId;
        _isOnboardingComplete = accountId != null;
      });
    } catch (e) {
      print('Error loading Stripe account ID: $e');
    }
  }

  Future<void> _startOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final backendService = ref.read(backendServiceProvider);
      final firebaseService = ref.read(firebaseServiceProvider);

      if (authState.value == null) {
        throw Exception('User not authenticated');
      }

      if (backendService == null || !backendService.isAvailable) {
        throw Exception('Backend service not available');
      }

      final userProfile = await firebaseService.getUserProfile(authState.value!.uid);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Check if account already exists
      String? accountId = _currentAccountId;
      
      if (accountId == null) {
        // Create new Stripe Connect Express account
        final accountData = await backendService.createStripeConnectAccount(
          driverId: authState.value!.uid,
          email: userProfile.email,
          country: 'US',
        );

        if (accountData == null || accountData['accountId'] == null) {
          throw Exception('Failed to create Stripe account');
        }

        accountId = accountData['accountId'] as String;
        
        // Save account ID to Firestore
        await firebaseService.updateUserStripeAccountId(
          authState.value!.uid,
          accountId,
        );
      }

      // Create account link for onboarding
      final returnUrl = 'quickgas://stripe-connect-return';
      final refreshUrl = 'quickgas://stripe-connect-refresh';
      
      final linkUrl = await backendService.createAccountLink(
        accountId: accountId,
        returnUrl: returnUrl,
        refreshUrl: refreshUrl,
      );

      if (linkUrl == null) {
        throw Exception('Failed to create account link');
      }

      // Open onboarding URL
      final uri = Uri.parse(linkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete onboarding in the browser, then return to the app'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('Could not launch onboarding URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start onboarding: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Connect Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stripe Connect Account',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Connect your Stripe account to receive automatic payouts. '
                        'Click the button below to complete onboarding securely through Stripe.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isOnboardingComplete) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Connected',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Stripe account is set up and ready to receive payouts.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.account_circle),
                  label: Text(
                    _isOnboardingComplete 
                        ? 'Update Account Settings'
                        : 'Connect Stripe Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Important: Why Stripe Connect?',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Drivers need to RECEIVE money (payouts), not make payments.\n\n'
                        '• Credit cards are for PAYING, not receiving\n'
                        '• To receive payouts, drivers need a Stripe Connect account\n'
                        '• This is different from customers who just enter card info\n\n'
                        'For Testing:\n'
                        '• Use Stripe Test Mode to create test accounts\n'
                        '• Test account IDs work the same way\n'
                        '• No real money is transferred in test mode',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to Get Account ID (Testing)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Go to Stripe Dashboard (test mode)\n'
                        '2. Navigate to Connect → Accounts\n'
                        '3. Create a test connected account\n'
                        '4. Copy the account ID (format: acct_xxxxxxxxxxxxx)\n'
                        '5. Paste it in the field above\n\n'
                        'For production, drivers will complete onboarding in-app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

