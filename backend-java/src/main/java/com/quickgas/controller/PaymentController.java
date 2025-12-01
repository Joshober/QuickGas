package com.quickgas.controller;

import com.quickgas.dto.PaymentIntentRequest;
import com.quickgas.dto.PaymentIntentResponse;
import com.quickgas.dto.PaymentConfirmRequest;
import com.quickgas.dto.PaymentCancelRequest;
import com.quickgas.service.PaymentService;
import com.quickgas.service.SecurityService;
import com.stripe.exception.StripeException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {
    
    private final PaymentService paymentService;
    private final SecurityService securityService;
    
    @PostMapping("/create-intent")
    public ResponseEntity<PaymentIntentResponse> createPaymentIntent(
            @Valid @RequestBody PaymentIntentRequest request,
            HttpServletRequest httpRequest) throws StripeException {
        
        String userId = request.getMetadata() != null ? request.getMetadata().get("userId") : "unknown";
        String orderId = request.getMetadata() != null ? request.getMetadata().get("orderId") : null;
        String clientIp = httpRequest.getRemoteAddr();
        
        // Log security event
        securityService.logSecurityEvent("PAYMENT_INTENT_CREATE", userId, 
                "amount=" + request.getAmount() + ", orderId=" + orderId + ", ip=" + clientIp);
        
        log.info("Creating payment intent: amount={}, currency={}, orderId={}, userId={}, idempotencyKey={}", 
            request.getAmount(), request.getCurrency(), orderId, userId, request.getIdempotencyKey());
        
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

