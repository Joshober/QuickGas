package com.quickgas.service;

import com.quickgas.dto.PaymentIntentRequest;
import com.quickgas.dto.PaymentIntentResponse;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.PaymentIntent;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.PaymentIntentCancelParams;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
public class PaymentService {
    
    @Value("${stripe.secret-key:}")
    private String stripeSecretKey;
    
    @PostConstruct
    public void init() {
        if (stripeSecretKey != null && !stripeSecretKey.isEmpty()) {
            Stripe.apiKey = stripeSecretKey;
            log.info("Stripe initialized");
        } else {
            log.warn("Stripe secret key not configured");
        }
    }
    
    public PaymentIntentResponse createPaymentIntent(PaymentIntentRequest request) throws StripeException {
        if (stripeSecretKey == null || stripeSecretKey.isEmpty()) {
            throw new IllegalStateException("Stripe secret key not configured");
        }
        
        PaymentIntentCreateParams.Builder paramsBuilder = PaymentIntentCreateParams.builder()
            .setAmount((long) (request.getAmount() * 100)) // Convert to cents
            .setCurrency(request.getCurrency().toLowerCase())
            .setAutomaticPaymentMethods(
                PaymentIntentCreateParams.AutomaticPaymentMethods.builder()
                    .setEnabled(true)
                    .build()
            );
        
        if (request.getMetadata() != null && !request.getMetadata().isEmpty()) {
            paramsBuilder.putAllMetadata(request.getMetadata());
        }
        
        PaymentIntent paymentIntent = PaymentIntent.create(paramsBuilder.build());
        
        return new PaymentIntentResponse(
            paymentIntent.getClientSecret(),
            paymentIntent.getId()
        );
    }
    
    public Map<String, Object> confirmPayment(String paymentIntentId) throws StripeException {
        PaymentIntent paymentIntent = PaymentIntent.retrieve(paymentIntentId);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", paymentIntent.getStatus());
        response.put("paymentIntentId", paymentIntent.getId());
        
        return response;
    }
    
    public Map<String, Object> cancelPayment(String paymentIntentId) throws StripeException {
        PaymentIntent paymentIntent = PaymentIntent.retrieve(paymentIntentId);
        paymentIntent = paymentIntent.cancel(
            PaymentIntentCancelParams.builder().build()
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", paymentIntent.getStatus());
        response.put("paymentIntentId", paymentIntent.getId());
        
        return response;
    }
}

