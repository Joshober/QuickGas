enum PaymentErrorType {
  network,
  validation,
  payment,
  authentication,
  configuration,
  unknown,
}

class PaymentError {
  final PaymentErrorType type;
  final String message;
  final String? code;
  final dynamic originalError;

  PaymentError({
    required this.type,
    required this.message,
    this.code,
    this.originalError,
  });

  factory PaymentError.network(String message, [dynamic originalError]) {
    return PaymentError(
      type: PaymentErrorType.network,
      message: message,
      originalError: originalError,
    );
  }

  factory PaymentError.validation(String message) {
    return PaymentError(
      type: PaymentErrorType.validation,
      message: message,
    );
  }

  factory PaymentError.payment(String message, [String? code, dynamic originalError]) {
    return PaymentError(
      type: PaymentErrorType.payment,
      message: message,
      code: code,
      originalError: originalError,
    );
  }

  factory PaymentError.authentication(String message) {
    return PaymentError(
      type: PaymentErrorType.authentication,
      message: message,
    );
  }

  factory PaymentError.configuration(String message) {
    return PaymentError(
      type: PaymentErrorType.configuration,
      message: message,
    );
  }

  factory PaymentError.unknown(String message, [dynamic originalError]) {
    return PaymentError(
      type: PaymentErrorType.unknown,
      message: message,
      originalError: originalError,
    );
  }

  String get userFriendlyMessage {
    switch (type) {
      case PaymentErrorType.network:
        return 'Network error. Please check your connection and try again.';
      case PaymentErrorType.validation:
        return message;
      case PaymentErrorType.payment:
        if (code != null) {
          switch (code) {
            case 'card_declined':
              return 'Your card was declined. Please try a different payment method.';
            case 'insufficient_funds':
              return 'Insufficient funds. Please use a different card.';
            case 'expired_card':
              return 'Your card has expired. Please use a different card.';
            case 'incorrect_cvc':
              return 'The security code is incorrect. Please check and try again.';
            case 'processing_error':
              return 'Payment processing error. Please try again.';
            default:
              return message;
          }
        }
        return message;
      case PaymentErrorType.authentication:
        return 'Authentication failed. Please try again.';
      case PaymentErrorType.configuration:
        return 'Payment service is not configured. Please contact support.';
      case PaymentErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  String toString() => 'PaymentError(type: $type, message: $message, code: $code)';
}

