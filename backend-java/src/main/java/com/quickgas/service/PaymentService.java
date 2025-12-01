package com.quickgas.service;

import com.quickgas.dto.PaymentIntentRequest;
import com.quickgas.dto.PaymentIntentResponse;
import com.quickgas.entity.PaymentTransaction;
import com.quickgas.exception.ValidationException;
import com.quickgas.repository.PaymentTransactionRepository;
import com.quickgas.service.SecurityService;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.PaymentIntent;
import com.stripe.net.RequestOptions;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.PaymentIntentCancelParams;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.annotation.PostConstruct;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {
    
    @Value("${stripe.secret-key:}")
    private String stripeSecretKey;
    
    private final PaymentTransactionRepository paymentTransactionRepository;
    private final SecurityService securityService;
    
    // Supported currencies (ISO 4217 codes)
    private static final Set<String> SUPPORTED_CURRENCIES = Set.of(
        "usd", "eur", "gbp", "cad", "aud", "jpy", "chf", "nzd", "sek", "nok", "dkk"
    );
    
    @PostConstruct
    public void init() {
        if (stripeSecretKey != null && !stripeSecretKey.isEmpty()) {
            Stripe.apiKey = stripeSecretKey;
            log.info("Stripe initialized");
        } else {
            log.warn("Stripe secret key not configured");
        }
    }
    
    @Transactional
    public PaymentIntentResponse createPaymentIntent(PaymentIntentRequest request) throws StripeException {
        try {
            if (stripeSecretKey == null || stripeSecretKey.isEmpty()) {
                log.error("Stripe secret key not configured");
                throw new IllegalStateException("Stripe secret key not configured");
            }
            
            // Validate currency - handle null and convert to lowercase
            String currency = "usd"; // default
            if (request.getCurrency() != null && !request.getCurrency().isEmpty()) {
                currency = request.getCurrency().toLowerCase();
            }
            
            if (!SUPPORTED_CURRENCIES.contains(currency)) {
                log.warn("Unsupported currency: {}", currency);
                throw new ValidationException("Unsupported currency: " + currency + ". Supported currencies: " + SUPPORTED_CURRENCIES);
            }
            
            // Validate amount
            if (request.getAmount() == null || request.getAmount() <= 0) {
                log.warn("Invalid amount: {}", request.getAmount());
                throw new ValidationException("Amount must be greater than 0");
            }
            
            // Security validation: amount limits and rate limiting
            BigDecimal amount = BigDecimal.valueOf(request.getAmount());
            String userId = "unknown";
            String orderId = null;
            
            if (request.getMetadata() != null) {
                userId = request.getMetadata().get("userId");
                if (userId == null || userId.isEmpty()) {
                    userId = "unknown";
                }
                orderId = request.getMetadata().get("orderId");
            }
            
            try {
                securityService.validatePaymentAmount(amount, userId);
                securityService.checkRateLimit(userId, "/api/payments/create-intent");
                securityService.detectSuspiciousActivity(userId, amount, orderId);
            } catch (SecurityService.SecurityException e) {
                securityService.logSecurityEvent("PAYMENT_VALIDATION_FAILED", userId, 
                        "amount=" + amount + ", reason=" + e.getMessage());
                throw e;
            }
            
            // Check for duplicate payment intent using idempotency key
            if (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isEmpty()) {
                // Stripe will handle idempotency, but we can log it
                log.info("Creating payment intent with idempotency key: {}", request.getIdempotencyKey());
            }
            
            PaymentIntentCreateParams.Builder paramsBuilder = PaymentIntentCreateParams.builder()
                .setAmount((long) (request.getAmount() * 100)) // Convert to cents
                .setCurrency(currency)
                .setAutomaticPaymentMethods(
                    PaymentIntentCreateParams.AutomaticPaymentMethods.builder()
                        .setEnabled(true)
                        .build()
                );
            
            if (request.getMetadata() != null && !request.getMetadata().isEmpty()) {
                paramsBuilder.putAllMetadata(request.getMetadata());
            }
            
            PaymentIntentCreateParams params = paramsBuilder.build();
            RequestOptions requestOptions = null;
            
            // Add idempotency key if provided (via RequestOptions)
            if (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isEmpty()) {
                requestOptions = RequestOptions.builder()
                    .setIdempotencyKey(request.getIdempotencyKey())
                    .build();
            }
            
            PaymentIntent paymentIntent;
            if (requestOptions != null) {
                paymentIntent = PaymentIntent.create(params, requestOptions);
            } else {
                paymentIntent = PaymentIntent.create(params);
            }
            
            log.info("Stripe payment intent created: paymentIntentId={}, status={}, amount={}, currency={}", 
                paymentIntent.getId(), paymentIntent.getStatus(), request.getAmount(), currency);
            
            // Save payment transaction to database
            if (orderId != null && !orderId.isEmpty()) {
                try {
                    PaymentTransaction transaction = PaymentTransaction.builder()
                        .orderId(orderId)
                        .stripePaymentIntentId(paymentIntent.getId())
                        .amount(BigDecimal.valueOf(request.getAmount()))
                        .currency(currency)
                        .status(paymentIntent.getStatus())
                        .build();
                    
                    paymentTransactionRepository.save(transaction);
                    log.info("Payment transaction saved: orderId={}, paymentIntentId={}, amount={}, status={}", 
                        orderId, paymentIntent.getId(), request.getAmount(), paymentIntent.getStatus());
                } catch (Exception e) {
                    log.error("Failed to save payment transaction: orderId={}, paymentIntentId={}", 
                        orderId, paymentIntent.getId(), e);
                    // Don't fail the payment intent creation if transaction save fails
                }
            }
            
            return new PaymentIntentResponse(
                paymentIntent.getClientSecret(),
                paymentIntent.getId()
            );
        } catch (ValidationException | SecurityService.SecurityException | IllegalStateException e) {
            // Re-throw known exceptions
            throw e;
        } catch (StripeException e) {
            log.error("Stripe API error: code={}, message={}", 
                e.getCode(), e.getMessage(), e);
            throw e;
        } catch (Exception e) {
            log.error("Unexpected error creating payment intent: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to create payment intent: " + e.getMessage(), e);
        }
    }
    
    @Transactional
    public Map<String, Object> confirmPayment(String paymentIntentId) throws StripeException {
        PaymentIntent paymentIntent = PaymentIntent.retrieve(paymentIntentId);
        
        // Update transaction status in database
        updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", paymentIntent.getStatus());
        response.put("paymentIntentId", paymentIntent.getId());
        
        return response;
    }
    
    @Transactional
    public Map<String, Object> cancelPayment(String paymentIntentId) throws StripeException {
        PaymentIntent paymentIntent = PaymentIntent.retrieve(paymentIntentId);
        paymentIntent = paymentIntent.cancel(
            PaymentIntentCancelParams.builder().build()
        );
        
        // Update transaction status in database
        updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", paymentIntent.getStatus());
        response.put("paymentIntentId", paymentIntent.getId());
        
        return response;
    }
    
    @Transactional
    public void updateTransactionStatus(String paymentIntentId, String status) {
        try {
            paymentTransactionRepository.findByStripePaymentIntentId(paymentIntentId)
                .ifPresent(transaction -> {
                    transaction.setStatus(status);
                    paymentTransactionRepository.save(transaction);
                    log.info("Payment transaction status updated: paymentIntentId={}, status={}", 
                        paymentIntentId, status);
                });
        } catch (Exception e) {
            log.error("Failed to update payment transaction status: paymentIntentId={}, status={}", 
                paymentIntentId, status, e);
        }
    }
}

