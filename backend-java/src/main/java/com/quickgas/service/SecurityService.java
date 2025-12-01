package com.quickgas.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Security service for fraud detection, rate limiting, and transaction monitoring
 */
@Slf4j
@Service
public class SecurityService {
    
    // Amount limits (configurable via environment variables)
    @Value("${security.payment.min-amount:0.50}")
    private double minPaymentAmount;
    
    @Value("${security.payment.max-amount:10000.00}")
    private double maxPaymentAmount;
    
    @Value("${security.payment.max-daily-amount:50000.00}")
    private double maxDailyAmount;
    
    @Value("${security.rate-limit.enabled:true}")
    private boolean rateLimitEnabled;
    
    @Value("${security.rate-limit.max-requests-per-minute:60}")
    private int maxRequestsPerMinute;
    
    // Rate limiting: userId -> request count
    private final Map<String, RateLimitTracker> rateLimitMap = new ConcurrentHashMap<>();
    
    // Daily amount tracking: userId -> daily total
    private final Map<String, DailyAmountTracker> dailyAmountMap = new ConcurrentHashMap<>();
    
    /**
     * Validate payment amount against security limits
     */
    public void validatePaymentAmount(BigDecimal amount, String userId) {
        double amountValue = amount.doubleValue();
        
        if (amountValue < minPaymentAmount) {
            log.warn("Payment amount below minimum: amount={}, min={}, userId={}", 
                    amountValue, minPaymentAmount, userId);
            throw new SecurityException("Payment amount must be at least $" + minPaymentAmount);
        }
        
        if (amountValue > maxPaymentAmount) {
            log.warn("Payment amount above maximum: amount={}, max={}, userId={}", 
                    amountValue, maxPaymentAmount, userId);
            throw new SecurityException("Payment amount exceeds maximum limit of $" + maxPaymentAmount);
        }
        
        // Check daily limit
        DailyAmountTracker tracker = dailyAmountMap.computeIfAbsent(userId, 
                k -> new DailyAmountTracker());
        
        if (tracker.isNewDay()) {
            tracker.reset();
        }
        
        double newDailyTotal = tracker.addAmount(amountValue);
        
        if (newDailyTotal > maxDailyAmount) {
            log.warn("Daily payment limit exceeded: userId={}, dailyTotal={}, max={}", 
                    userId, newDailyTotal, maxDailyAmount);
            throw new SecurityException("Daily payment limit exceeded. Maximum: $" + maxDailyAmount);
        }
    }
    
    /**
     * Check rate limiting for a user
     */
    public void checkRateLimit(String userId, String endpoint) {
        if (!rateLimitEnabled) {
            return;
        }
        
        RateLimitTracker tracker = rateLimitMap.computeIfAbsent(userId, 
                k -> new RateLimitTracker());
        
        if (tracker.isNewMinute()) {
            tracker.reset();
        }
        
        int requests = tracker.increment();
        
        if (requests > maxRequestsPerMinute) {
            log.warn("Rate limit exceeded: userId={}, endpoint={}, requests={}, max={}", 
                    userId, endpoint, requests, maxRequestsPerMinute);
            throw new SecurityException("Rate limit exceeded. Please try again later.");
        }
    }
    
    /**
     * Detect suspicious activity patterns
     */
    public void detectSuspiciousActivity(String userId, BigDecimal amount, String orderId) {
        // Check for rapid successive payments
        RateLimitTracker tracker = rateLimitMap.get(userId);
        if (tracker != null && tracker.getRequests() > 10) {
            log.warn("Suspicious activity detected: rapid payments, userId={}, requests={}", 
                    userId, tracker.getRequests());
            // Could trigger additional verification here
        }
        
        // Check for unusually large amounts
        if (amount.doubleValue() > maxPaymentAmount * 0.8) {
            log.warn("Large payment detected: userId={}, amount={}, orderId={}", 
                    userId, amount, orderId);
        }
    }
    
    /**
     * Log security event for audit trail
     */
    public void logSecurityEvent(String eventType, String userId, String details) {
        log.info("SECURITY_EVENT: type={}, userId={}, details={}, timestamp={}", 
                eventType, userId, details, LocalDateTime.now());
        // In production, this could be sent to a security monitoring system
    }
    
    /**
     * Rate limit tracker (per minute)
     */
    private static class RateLimitTracker {
        private long minuteTimestamp;
        private final AtomicInteger requestCount = new AtomicInteger(0);
        
        boolean isNewMinute() {
            long currentMinute = System.currentTimeMillis() / 60000;
            if (currentMinute != minuteTimestamp) {
                return true;
            }
            return false;
        }
        
        void reset() {
            minuteTimestamp = System.currentTimeMillis() / 60000;
            requestCount.set(0);
        }
        
        int increment() {
            return requestCount.incrementAndGet();
        }
        
        int getRequests() {
            return requestCount.get();
        }
    }
    
    /**
     * Daily amount tracker
     */
    private static class DailyAmountTracker {
        private int dayOfYear;
        private double totalAmount;
        
        boolean isNewDay() {
            int currentDay = LocalDateTime.now().getDayOfYear();
            if (currentDay != dayOfYear) {
                return true;
            }
            return false;
        }
        
        void reset() {
            dayOfYear = LocalDateTime.now().getDayOfYear();
            totalAmount = 0.0;
        }
        
        double addAmount(double amount) {
            totalAmount += amount;
            return totalAmount;
        }
    }
    
    /**
     * Custom security exception
     */
    public static class SecurityException extends RuntimeException {
        public SecurityException(String message) {
            super(message);
        }
    }
}

