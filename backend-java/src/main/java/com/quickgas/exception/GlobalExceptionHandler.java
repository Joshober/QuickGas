package com.quickgas.exception;

import com.stripe.exception.StripeException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<Map<String, Object>> handleValidationException(ValidationException e) {
        log.warn("Validation error: {}", e.getMessage());
        Map<String, Object> response = new HashMap<>();
        response.put("error", e.getMessage());
        response.put("type", "validation_error");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }
    
    @ExceptionHandler(PaymentException.class)
    public ResponseEntity<Map<String, Object>> handlePaymentException(PaymentException e) {
        log.error("Payment error: {}", e.getMessage(), e);
        Map<String, Object> response = new HashMap<>();
        response.put("error", e.getMessage());
        response.put("type", "payment_error");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }
    
    @ExceptionHandler(StripeException.class)
    public ResponseEntity<Map<String, Object>> handleStripeException(StripeException e) {
        log.error("Stripe API error: code={}, message={}", e.getCode(), e.getMessage(), e);
        
        Map<String, Object> response = new HashMap<>();
        response.put("error", e.getMessage());
        response.put("type", "stripe_error");
        response.put("code", e.getCode());
        
        // Map Stripe error codes to appropriate HTTP status codes
        HttpStatus status = mapStripeErrorToHttpStatus(e);
        
        return ResponseEntity.status(status).body(response);
    }
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationErrors(MethodArgumentNotValidException e) {
        log.warn("Validation errors: {}", e.getMessage());
        Map<String, String> errors = new HashMap<>();
        e.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });
        
        Map<String, Object> response = new HashMap<>();
        response.put("error", "Validation failed");
        response.put("type", "validation_error");
        response.put("errors", errors);
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }
    
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalStateException(IllegalStateException e) {
        log.error("Configuration error: {}", e.getMessage());
        Map<String, Object> response = new HashMap<>();
        response.put("error", e.getMessage());
        response.put("type", "configuration_error");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception e) {
        log.error("Unexpected error: {}", e.getMessage(), e);
        Map<String, Object> response = new HashMap<>();
        response.put("error", "An unexpected error occurred");
        response.put("type", "internal_error");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
    
    private HttpStatus mapStripeErrorToHttpStatus(StripeException e) {
        String code = e.getCode();
        if (code == null) {
            return HttpStatus.INTERNAL_SERVER_ERROR;
        }
        
        // Payment method errors (card declined, insufficient funds, etc.)
        if (code.startsWith("card_") || code.startsWith("payment_method_")) {
            return HttpStatus.PAYMENT_REQUIRED; // 402
        }
        
        // Invalid request errors
        if (code.startsWith("invalid_") || code.equals("parameter_invalid_empty") || 
            code.equals("parameter_invalid_integer") || code.equals("parameter_invalid_string_blank")) {
            return HttpStatus.BAD_REQUEST; // 400
        }
        
        // Rate limit errors
        if (code.equals("rate_limit")) {
            return HttpStatus.TOO_MANY_REQUESTS; // 429
        }
        
        // Authentication errors
        if (code.equals("api_key_expired") || code.equals("authentication_required")) {
            return HttpStatus.UNAUTHORIZED; // 401
        }
        
        // Default to 500 for other errors
        return HttpStatus.INTERNAL_SERVER_ERROR;
    }
}

