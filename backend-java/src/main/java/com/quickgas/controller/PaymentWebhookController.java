package com.quickgas.controller;

import com.quickgas.service.PaymentWebhookService;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.net.Webhook;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentWebhookController {
    
    @Value("${stripe.webhook-secret:}")
    private String webhookSecret;
    
    private final PaymentWebhookService webhookService;
    
    @PostMapping("/webhook")
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {
        
        if (webhookSecret == null || webhookSecret.isEmpty()) {
            log.warn("Webhook secret not configured, skipping webhook verification");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Webhook secret not configured");
        }
        
        Event event;
        
        try {
            // Verify webhook signature
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
            log.info("Webhook event received: type={}, id={}", event.getType(), event.getId());
        } catch (SignatureVerificationException e) {
            log.error("Webhook signature verification failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body("Invalid signature");
        } catch (Exception e) {
            log.error("Error processing webhook: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body("Error processing webhook");
        }
        
        // Handle the event
        try {
            webhookService.handleEvent(event);
            return ResponseEntity.ok("Webhook processed successfully");
        } catch (Exception e) {
            log.error("Error handling webhook event: type={}, id={}", event.getType(), event.getId(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Error handling webhook event");
        }
    }
}

