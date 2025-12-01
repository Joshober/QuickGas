import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/models/driver_payment_model.dart';
import 'package:intl/intl.dart';

class DriverPaymentsScreen extends ConsumerStatefulWidget {
  const DriverPaymentsScreen({super.key});

  @override
  ConsumerState<DriverPaymentsScreen> createState() => _DriverPaymentsScreenState();
}

class _DriverPaymentsScreenState extends ConsumerState<DriverPaymentsScreen> {
  List<DriverPaymentModel> _allPayments = [];
  List<DriverPaymentModel> _filteredPayments = [];
  String _selectedStatus = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  Set<int> _processingPayments = {}; // Track which payments are being processed

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments({bool retry = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authStateProvider);
      final backendService = ref.read(backendServiceProvider);

      if (authState.value == null) {
        throw Exception('User not authenticated');
      }

      if (backendService == null) {
        throw Exception('Backend service not initialized');
      }

      // Try to check availability if not already available
      if (!backendService.isAvailable && !retry) {
        await backendService.checkAvailability();
      }

      final paymentsData = await backendService.getDriverPayments(authState.value!.uid);

      if (paymentsData != null) {
        try {
          final payments = paymentsData
              .map((json) {
                try {
                  return DriverPaymentModel.fromJson(json);
                } catch (e) {
                  print('Failed to parse payment: $e, data: $json');
                  return null;
                }
              })
              .where((payment) => payment != null)
              .cast<DriverPaymentModel>()
              .toList();
          
          // Sort by created date (newest first)
          payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          setState(() {
            _allPayments = payments;
            _applyFilter();
            _isLoading = false;
          });
        } catch (e) {
          throw Exception('Failed to parse payment data: $e');
        }
      } else {
        // If null, it might be a network error - try retry once
        if (!retry) {
          await Future.delayed(const Duration(seconds: 1));
          return _loadPayments(retry: true);
        }
        setState(() {
          _allPayments = [];
          _applyFilter();
          _isLoading = false;
          _errorMessage = 'Unable to load payments. Please check your connection and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load payments: ${e.toString().replaceAll('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (_selectedStatus == 'all') {
      _filteredPayments = List.from(_allPayments);
    } else {
      _filteredPayments = _allPayments
          .where((payment) => payment.status == _selectedStatus)
          .toList();
    }
  }

  double _calculateTotalEarnings() {
    return _allPayments
        .where((p) => p.status == 'paid')
        .fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double _calculatePendingEarnings() {
    return _allPayments
        .where((p) => p.status == 'pending')
        .fold(0.0, (sum, payment) => sum + payment.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPayments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: Column(
                    children: [
                      // Earnings Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Earnings Summary',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Total Paid',
                                    _calculateTotalEarnings(),
                                    AppTheme.successColor,
                                    Icons.check_circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Pending',
                                    _calculatePendingEarnings(),
                                    Colors.orange,
                                    Icons.pending,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('pending', 'Pending'),
                            const SizedBox(width: 8),
                            _buildFilterChip('paid', 'Paid'),
                            const SizedBox(width: 8),
                            _buildFilterChip('failed', 'Failed'),
                          ],
                        ),
                      ),
                      // Payments List
                      Expanded(
                        child: _filteredPayments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.payment_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No payments found',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredPayments.length,
                                itemBuilder: (context, index) {
                                  final payment = _filteredPayments[index];
                                  return _buildPaymentCard(payment);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEarningsCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
          _applyFilter();
        });
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Widget _buildPaymentCard(DriverPaymentModel payment) {
    final statusColor = _getStatusColor(payment.status);
    final statusIcon = _getStatusIcon(payment.status);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${payment.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          payment.status.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (payment.paidAt != null)
                  Text(
                    dateFormat.format(payment.paidAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      payment.orderId.substring(0, 8),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      dateFormat.format(payment.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (payment.stripeTransferId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Transfer ID: ${payment.stripeTransferId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (payment.status == 'pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processingPayments.contains(payment.id)
                      ? null
                      : () => _processPayment(payment),
                  icon: _processingPayments.contains(payment.id)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _processingPayments.contains(payment.id)
                        ? 'Processing...'
                        : 'Process Payment',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(DriverPaymentModel payment) async {
    setState(() {
      _processingPayments.add(payment.id);
    });

    try {
      final backendService = ref.read(backendServiceProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      final authState = ref.read(authStateProvider);
      
      if (backendService == null) {
        throw Exception('Backend service not initialized');
      }

      if (authState.value == null) {
        throw Exception('User not authenticated');
      }

      // Fetch user data from Firestore (to sync to PostgreSQL if needed)
      final userProfile = await firebaseService.getUserProfile(authState.value!.uid);
      if (userProfile == null) {
        throw Exception('User profile not found in Firestore');
      }

      // Fetch Stripe account ID from Firestore
      String? stripeAccountId;
      try {
        stripeAccountId = await firebaseService.getUserStripeAccountId(authState.value!.uid);
        if (stripeAccountId == null || stripeAccountId.isEmpty) {
          throw Exception('Stripe Connect account not set up. Please complete Stripe Connect onboarding first.');
        }
      } catch (e) {
        throw Exception('Failed to get Stripe account: ${e.toString().replaceAll('Exception: ', '')}');
      }

      // Prepare user data to sync to PostgreSQL
      final userData = <String, dynamic>{
        'email': userProfile.email,
        'name': userProfile.name,
        'phone': userProfile.phone,
        'role': userProfile.role,
        'defaultRole': userProfile.defaultRole,
        if (userProfile.fcmToken != null) 'fcmToken': userProfile.fcmToken,
      };

      await backendService.processPendingPayment(
        payment.id,
        stripeAccountId: stripeAccountId,
        userData: userData,
      );

      // If we get here, payment was processed successfully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment processed successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Small delay to ensure backend has updated the payment status
        await Future.delayed(const Duration(milliseconds: 500));
        // Reload payments to get updated status
        await _loadPayments();
      }
    } catch (e) {
      // Always refresh payments even on error to show updated status
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadPayments();
        
        // Show error message
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        // Provide helpful message for Stripe test mode issues
        if (errorMessage.contains('insufficient funds') || errorMessage.contains('balance')) {
          errorMessage = 'Insufficient Stripe test funds. In test mode, you need to add funds to your Stripe account using test card 4000000000000077.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process payment: $errorMessage'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5), // Longer duration for important messages
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingPayments.remove(payment.id);
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.successColor;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}

