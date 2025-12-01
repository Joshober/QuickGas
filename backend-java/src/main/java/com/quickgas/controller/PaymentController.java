package com.quickgas.controller;

import com.quickgas.dto.PaymentIntentRequest;
import com.quickgas.dto.PaymentIntentResponse;
import com.quickgas.dto.PaymentConfirmRequest;
import com.quickgas.dto.PaymentCancelRequest;
import com.quickgas.service.PaymentService;
import com.stripe.exception.StripeException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {
    
    private final PaymentService paymentService;
    
    @PostMapping("/create-intent")
    public ResponseEntity<PaymentIntentResponse> createPaymentIntent(@Valid @RequestBody PaymentIntentRequest request) throws StripeException {
        String orderId = request.getMetadata() != null ? request.getMetadata().get("orderId") : null;
        log.info("Creating payment intent: amount={}, currency={}, orderId={}, idempotencyKey={}", 
            request.getAmount(), request.getCurrency(), orderId, request.getIdempotencyKey());
        
        PaymentIntentResponse response = paymentService.createPaymentIntent(request);
        
        log.info("Payment intent created: paymentIntentId={}, orderId={}", 
            response.getPaymentIntentId(), orderId);
        
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/confirm")
    public ResponseEntity<?> confirmPayment(@Valid @RequestBody PaymentConfirmRequest request) throws StripeException {
        log.info("Confirming payment: paymentIntentId={}", request.getPaymentIntentId());
        
        var response = paymentService.confirmPayment(request.getPaymentIntentId());
        
        log.info("Payment confirmed: paymentIntentId={}, status={}", 
            request.getPaymentIntentId(), response.get("status"));
        
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/cancel")
    public ResponseEntity<?> cancelPayment(@Valid @RequestBody PaymentCancelRequest request) throws StripeException {
        log.info("Cancelling payment: paymentIntentId={}", request.getPaymentIntentId());
        
        var response = paymentService.cancelPayment(request.getPaymentIntentId());
        
        log.info("Payment cancelled: paymentIntentId={}, status={}", 
            request.getPaymentIntentId(), response.get("status"));
        
        return ResponseEntity.ok(response);
    }
}

