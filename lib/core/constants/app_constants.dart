class AppConstants {
  static const String appName = 'QuickGas';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String ordersCollection = 'orders';
  static const String routesCollection = 'routes';
  static const String deliveryVerificationsCollection =
      'delivery_verifications';

  static const String orderStatusPending = 'pending';
  static const String orderStatusAccepted = 'accepted';
  static const String orderStatusInTransit = 'in_transit';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';

  static const String roleCustomer = 'customer';
  static const String roleDriver = 'driver';
  static const String roleBoth = 'both';

  static const String paymentMethodStripe = 'stripe';
  static const String paymentMethodCash = 'cash';

  static const String paymentStatusPending = 'pending';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusFailed = 'failed';

  static const String routeStatusPlanning = 'planning';
  static const String routeStatusActive = 'active';
  static const String routeStatusCompleted = 'completed';

  static const String openRouteServiceBaseUrl =
      'https://api.openrouteservice.org/v2';

  static const Duration animationDurationFast = Duration(milliseconds: 200);
  static const Duration animationDurationNormal = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);

  static const int maxImageSize = 5 * 1024 * 1024;
  static const double imageCompressionQuality = 0.8;

  // Pricing
  static const double pricePerGallon = 3.50; // Default price per gallon in USD
  static const double deliveryFee = 5.00; // Default delivery fee in USD

  static double calculateOrderTotal(double gasQuantity) {
    return (gasQuantity * pricePerGallon) + deliveryFee;
  }

  // Payment Validation
  static const double minPaymentAmount = 0.50; // Minimum payment amount in USD
  static const double maxPaymentAmount = 10000.00; // Maximum payment amount in USD
  static const List<String> supportedCurrencies = [
    'usd',
    'eur',
    'gbp',
    'cad',
    'aud',
    'jpy',
    'chf',
    'nzd',
    'sek',
    'nok',
    'dkk',
  ];

  static bool isValidPaymentAmount(double amount) {
    return amount >= minPaymentAmount && amount <= maxPaymentAmount;
  }

  static bool isSupportedCurrency(String currency) {
    return supportedCurrencies.contains(currency.toLowerCase());
  }
}
