package com.quickgas.service;

import com.stripe.model.Event;
import com.stripe.model.PaymentIntent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentWebhookService {
    
    private final PaymentService paymentService;
    
    @Transactional
    public void handleEvent(Event event) {
        String eventType = event.getType();
        
        log.info("Processing webhook event: type={}, id={}", eventType, event.getId());
        
        switch (eventType) {
            case "payment_intent.succeeded":
                handlePaymentIntentSucceeded(event);
                break;
            case "payment_intent.payment_failed":
                handlePaymentIntentFailed(event);
                break;
            case "payment_intent.canceled":
                handlePaymentIntentCanceled(event);
                break;
            case "payment_intent.requires_action":
                handlePaymentIntentRequiresAction(event);
                break;
            default:
                log.debug("Unhandled webhook event type: {}", eventType);
        }
    }
    
    private void handlePaymentIntentSucceeded(Event event) {
        PaymentIntent paymentIntent = (PaymentIntent) event.getDataObjectDeserializer()
            .getObject()
            .orElse(null);
        
        if (paymentIntent == null) {
            log.warn("Payment intent not found in webhook event: {}", event.getId());
            return;
        }
        
        String paymentIntentId = paymentIntent.getId();
        log.info("Payment intent succeeded: paymentIntentId={}, amount={}, currency={}", 
            paymentIntentId, paymentIntent.getAmount(), paymentIntent.getCurrency());
        
        // Update transaction status
        paymentService.updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
        
        // Log for audit trail
        log.info("Payment transaction updated via webhook: paymentIntentId={}, status=succeeded", 
            paymentIntentId);
    }
    
    private void handlePaymentIntentFailed(Event event) {
        PaymentIntent paymentIntent = (PaymentIntent) event.getDataObjectDeserializer()
            .getObject()
            .orElse(null);
        
        if (paymentIntent == null) {
            log.warn("Payment intent not found in webhook event: {}", event.getId());
            return;
        }
        
        String paymentIntentId = paymentIntent.getId();
        String lastPaymentError = paymentIntent.getLastPaymentError() != null 
            ? paymentIntent.getLastPaymentError().getMessage() 
            : "Unknown error";
        
        log.warn("Payment intent failed: paymentIntentId={}, error={}", 
            paymentIntentId, lastPaymentError);
        
        // Update transaction status
        paymentService.updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
        
        // Log for audit trail
        log.info("Payment transaction updated via webhook: paymentIntentId={}, status=failed", 
            paymentIntentId);
    }
    
    private void handlePaymentIntentCanceled(Event event) {
        PaymentIntent paymentIntent = (PaymentIntent) event.getDataObjectDeserializer()
            .getObject()
            .orElse(null);
        
        if (paymentIntent == null) {
            log.warn("Payment intent not found in webhook event: {}", event.getId());
            return;
        }
        
        String paymentIntentId = paymentIntent.getId();
        log.info("Payment intent canceled: paymentIntentId={}", paymentIntentId);
        
        // Update transaction status
        paymentService.updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
    }
    
    private void handlePaymentIntentRequiresAction(Event event) {
        PaymentIntent paymentIntent = (PaymentIntent) event.getDataObjectDeserializer()
            .getObject()
            .orElse(null);
        
        if (paymentIntent == null) {
            log.warn("Payment intent not found in webhook event: {}", event.getId());
            return;
        }
        
        String paymentIntentId = paymentIntent.getId();
        log.info("Payment intent requires action (3D Secure): paymentIntentId={}", paymentIntentId);
        
        // Update transaction status
        paymentService.updateTransactionStatus(paymentIntentId, paymentIntent.getStatus());
    }
}

