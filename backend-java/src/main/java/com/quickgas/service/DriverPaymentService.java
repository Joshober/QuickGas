package com.quickgas.service;

import com.quickgas.entity.DriverPayment;
import com.quickgas.entity.User;
import com.quickgas.repository.DriverPaymentRepository;
import com.quickgas.repository.UserRepository;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Transfer;
import com.stripe.param.TransferCreateParams;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.annotation.PostConstruct;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class DriverPaymentService {
    
    @Value("${stripe.secret-key:}")
    private String stripeSecretKey;
    
    private final DriverPaymentRepository driverPaymentRepository;
    private final UserRepository userRepository;
    
    // Driver gets 80% of order total
    private static final double DRIVER_PAYMENT_PERCENTAGE = 0.80;
    
    @PostConstruct
    public void init() {
        if (stripeSecretKey != null && !stripeSecretKey.isEmpty()) {
            Stripe.apiKey = stripeSecretKey;
            log.info("Stripe initialized for driver payments");
        } else {
            log.warn("Stripe secret key not configured for driver payments");
        }
    }
    
    /**
     * Create a driver payment record (80% of order total)
     * @param driverId Driver ID
     * @param orderId Order ID
     * @param orderTotal Total order amount (including tip)
     * @param currency Currency code
     * @param routeId Optional route ID
     * @return Created DriverPayment entity
     */
    @Transactional
    public DriverPayment createDriverPayment(
            String driverId,
            String orderId,
            BigDecimal orderTotal,
            String currency,
            String routeId) {
        
        // Calculate driver payment (80% of order total)
        BigDecimal driverAmount = orderTotal
                .multiply(BigDecimal.valueOf(DRIVER_PAYMENT_PERCENTAGE))
                .setScale(2, RoundingMode.HALF_UP);
        
        DriverPayment payment = DriverPayment.builder()
                .driverId(driverId)
                .orderId(orderId)
                .routeId(routeId)
                .amount(driverAmount)
                .currency(currency.toLowerCase())
                .status("pending")
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        
        payment = driverPaymentRepository.save(payment);
        log.info("Created driver payment: paymentId={}, driverId={}, orderId={}, amount={}", 
                payment.getId(), driverId, orderId, driverAmount);
        
        // Attempt automatic payout if driver has Stripe Connect account
        attemptAutomaticPayout(payment);
        
        return payment;
    }
    
    /**
     * Attempt automatic payout if driver has Stripe Connect account ID
     * This method does not throw exceptions - failures are logged but don't block payment creation
     */
    private void attemptAutomaticPayout(DriverPayment payment) {
        try {
            // Fetch driver's Stripe account ID from database
            User driver = userRepository.findById(payment.getDriverId()).orElse(null);
            
            if (driver == null) {
                log.warn("Driver not found for automatic payout: driverId={}", payment.getDriverId());
                return;
            }
            
            String stripeAccountId = driver.getStripeAccountId();
            
            if (stripeAccountId == null || stripeAccountId.isEmpty()) {
                log.info("Driver does not have Stripe Connect account set up: driverId={}, paymentId={}", 
                        payment.getDriverId(), payment.getId());
                return;
            }
            
            // Attempt to process payout
            log.info("Attempting automatic payout: paymentId={}, driverId={}, stripeAccountId={}", 
                    payment.getId(), payment.getDriverId(), stripeAccountId);
            
            processDriverPayout(payment.getId(), stripeAccountId);
            
            log.info("Automatic payout successful: paymentId={}, transferId={}", 
                    payment.getId(), payment.getStripeTransferId());
            
        } catch (StripeException e) {
            log.error("Automatic payout failed (Stripe error): paymentId={}, error={}", 
                    payment.getId(), e.getMessage());
            // Payment remains in "pending" status for manual retry
        } catch (Exception e) {
            log.error("Automatic payout failed (unexpected error): paymentId={}, error={}", 
                    payment.getId(), e.getMessage(), e);
            // Payment remains in "pending" status for manual retry
        }
    }
    
    /**
     * Process driver payout via Stripe Transfer
     * Note: This requires Stripe Connect and driver's connected account ID
     * For now, this is a placeholder - actual implementation depends on Stripe Connect setup
     */
    @Transactional
    public DriverPayment processDriverPayout(Long paymentId, String driverStripeAccountId) 
            throws StripeException {
        
        DriverPayment payment = driverPaymentRepository.findById(paymentId)
                .orElseThrow(() -> new IllegalArgumentException("Driver payment not found"));
        
        if (!"pending".equals(payment.getStatus())) {
            throw new IllegalStateException("Payment is not in pending status");
        }
        
        // Convert amount to cents for Stripe
        long amountInCents = payment.getAmount()
                .multiply(BigDecimal.valueOf(100))
                .longValue();
        
        try {
            // Create Stripe Transfer to driver's connected account
            TransferCreateParams params = TransferCreateParams.builder()
                    .setAmount(amountInCents)
                    .setCurrency(payment.getCurrency())
                    .setDestination(driverStripeAccountId)
                    .putMetadata("orderId", payment.getOrderId())
                    .putMetadata("driverId", payment.getDriverId())
                    .build();
            
            Transfer transfer = Transfer.create(params);
            
            // Update payment record
            payment.setStatus("paid");
            payment.setStripeTransferId(transfer.getId());
            payment.setPaidAt(LocalDateTime.now());
            payment = driverPaymentRepository.save(payment);
            
            log.info("Driver payout processed: paymentId={}, transferId={}, amount={}", 
                    payment.getId(), transfer.getId(), payment.getAmount());
            
            return payment;
        } catch (StripeException e) {
            log.error("Failed to process driver payout: paymentId={}, error={}", 
                    paymentId, e.getMessage());
            
            payment.setStatus("failed");
            payment = driverPaymentRepository.save(payment);
            
            throw e;
        }
    }
    
    /**
     * Get all payments for a driver
     */
    public List<DriverPayment> getDriverPayments(String driverId) {
        return driverPaymentRepository.findByDriverId(driverId);
    }
    
    /**
     * Get payments by status for a driver
     */
    public List<DriverPayment> getDriverPaymentsByStatus(String driverId, String status) {
        return driverPaymentRepository.findByDriverIdAndStatus(driverId, status);
    }
    
    /**
     * Get payment by order ID
     */
    public DriverPayment getPaymentByOrderId(String orderId) {
        return driverPaymentRepository.findByOrderId(orderId)
                .orElse(null);
    }
}

