package com.quickgas.controller;

import com.quickgas.dto.PaymentIntentRequest;
import com.quickgas.dto.PaymentIntentResponse;
import com.quickgas.dto.PaymentConfirmRequest;
import com.quickgas.dto.PaymentCancelRequest;
import com.quickgas.service.PaymentService;
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
    public ResponseEntity<?> createPaymentIntent(@Valid @RequestBody PaymentIntentRequest request) {
        try {
            PaymentIntentResponse response = paymentService.createPaymentIntent(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Payment intent creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @PostMapping("/confirm")
    public ResponseEntity<?> confirmPayment(@Valid @RequestBody PaymentConfirmRequest request) {
        try {
            var response = paymentService.confirmPayment(request.getPaymentIntentId());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Payment confirmation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @PostMapping("/cancel")
    public ResponseEntity<?> cancelPayment(@Valid @RequestBody PaymentCancelRequest request) {
        try {
            var response = paymentService.cancelPayment(request.getPaymentIntentId());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Payment cancellation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

