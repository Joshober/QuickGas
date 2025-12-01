package com.quickgas.controller;

import com.quickgas.entity.DriverPayment;
import com.quickgas.service.DriverPaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.stripe.exception.StripeException;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/driver-payments")
@RequiredArgsConstructor
public class DriverPaymentController {
    
    private final DriverPaymentService driverPaymentService;
    
    @PostMapping
    public ResponseEntity<?> createDriverPayment(@RequestBody Map<String, Object> request) {
        try {
            String driverId = (String) request.get("driverId");
            String orderId = (String) request.get("orderId");
            BigDecimal orderTotal = new BigDecimal(request.get("orderTotal").toString());
            String currency = (String) request.getOrDefault("currency", "usd");
            String routeId = (String) request.get("routeId");
            
            if (driverId == null || orderId == null || orderTotal == null) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "driverId, orderId, and orderTotal are required"));
            }
            
            DriverPayment payment = driverPaymentService.createDriverPayment(
                    driverId, orderId, orderTotal, currency, routeId);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "paymentId", payment.getId(),
                "amount", payment.getAmount(),
                "status", payment.getStatus()
            ));
        } catch (Exception e) {
            log.error("Driver payment creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @PostMapping("/{paymentId}/payout")
    public ResponseEntity<?> processPayout(
            @PathVariable Long paymentId,
            @RequestBody Map<String, String> request) {
        try {
            String driverStripeAccountId = request.get("driverStripeAccountId");
            
            if (driverStripeAccountId == null || driverStripeAccountId.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "driverStripeAccountId is required"));
            }
            
            DriverPayment payment = driverPaymentService.processDriverPayout(
                    paymentId, driverStripeAccountId);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "paymentId", payment.getId(),
                "transferId", payment.getStripeTransferId(),
                "status", payment.getStatus()
            ));
        } catch (StripeException e) {
            log.error("Stripe payout error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", "Stripe payout failed: " + e.getMessage()));
        } catch (Exception e) {
            log.error("Payout processing error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @GetMapping("/driver/{driverId}")
    public ResponseEntity<?> getDriverPayments(@PathVariable String driverId) {
        try {
            List<DriverPayment> payments = driverPaymentService.getDriverPayments(driverId);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "payments", payments
            ));
        } catch (Exception e) {
            log.error("Get driver payments error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @GetMapping("/driver/{driverId}/status/{status}")
    public ResponseEntity<?> getDriverPaymentsByStatus(
            @PathVariable String driverId,
            @PathVariable String status) {
        try {
            List<DriverPayment> payments = driverPaymentService.getDriverPaymentsByStatus(
                    driverId, status);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "payments", payments
            ));
        } catch (Exception e) {
            log.error("Get driver payments by status error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

