package com.quickgas.controller;

import com.quickgas.entity.DriverPayment;
import com.quickgas.service.DriverPaymentService;
import com.quickgas.service.SecurityService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.stripe.exception.StripeException;
import com.stripe.model.Account;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/driver-payments")
@RequiredArgsConstructor
public class DriverPaymentController {
    
    private final DriverPaymentService driverPaymentService;
    private final SecurityService securityService;
    
    @PostMapping
    public ResponseEntity<?> createDriverPayment(
            @RequestBody Map<String, Object> request,
            HttpServletRequest httpRequest) {
        try {
            String driverId = (String) request.get("driverId");
            String orderId = (String) request.get("orderId");
            BigDecimal orderTotal = new BigDecimal(request.get("orderTotal").toString());
            String currency = (String) request.getOrDefault("currency", "usd");
            String routeId = (String) request.get("routeId");
            String clientIp = httpRequest.getRemoteAddr();
            
            if (driverId == null || orderId == null || orderTotal == null) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "driverId, orderId, and orderTotal are required"));
            }
            
            // Log security event
            securityService.logSecurityEvent("DRIVER_PAYMENT_CREATE_REQUEST", driverId, 
                    "orderId=" + orderId + ", amount=" + orderTotal + ", ip=" + clientIp);
            
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
    
    @PostMapping("/connect/create-account")
    public ResponseEntity<?> createConnectAccount(@RequestBody Map<String, String> request) {
        try {
            String driverId = request.get("driverId");
            String email = request.get("email");
            String country = request.getOrDefault("country", "US");
            
            if (driverId == null || email == null) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "driverId and email are required"));
            }
            
            Account account = driverPaymentService.createStripeConnectAccount(driverId, email, country);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "accountId", account.getId(),
                "detailsSubmitted", account.getDetailsSubmitted(),
                "chargesEnabled", account.getChargesEnabled(),
                "payoutsEnabled", account.getPayoutsEnabled()
            ));
        } catch (StripeException e) {
            log.error("Stripe Connect account creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", "Stripe error: " + e.getMessage()));
        } catch (Exception e) {
            log.error("Connect account creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @PostMapping("/connect/create-link")
    public ResponseEntity<?> createAccountLink(@RequestBody Map<String, String> request) {
        try {
            String accountId = request.get("accountId");
            String returnUrl = request.get("returnUrl");
            String refreshUrl = request.get("refreshUrl");
            
            if (accountId == null || returnUrl == null || refreshUrl == null) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "accountId, returnUrl, and refreshUrl are required"));
            }
            
            String linkUrl = driverPaymentService.createAccountLink(accountId, returnUrl, refreshUrl);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "url", linkUrl
            ));
        } catch (StripeException e) {
            log.error("Stripe account link creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", "Stripe error: " + e.getMessage()));
        } catch (Exception e) {
            log.error("Account link creation error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @GetMapping("/connect/return")
    public ResponseEntity<?> handleConnectReturn(
            @RequestParam String driverId,
            @RequestParam(required = false) String status) {
        // This endpoint handles the return from Stripe Connect onboarding
        // In a mobile app, this would redirect to a deep link
        // For now, return a simple HTML page with instructions
        String html = "<!DOCTYPE html><html><head><title>Stripe Connect</title>" +
                "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
                "<style>body{font-family:Arial,sans-serif;text-align:center;padding:50px;}" +
                "h1{color:#635BFF;}p{color:#666;}</style></head><body>" +
                "<h1>✓ Account Connected</h1>" +
                "<p>Your Stripe account has been successfully connected.</p>" +
                "<p>You can now close this window and return to the app.</p>" +
                "<script>setTimeout(function(){window.close();},3000);</script>" +
                "</body></html>";
        return ResponseEntity.ok().header("Content-Type", "text/html").body(html);
    }
    
    @GetMapping("/connect/refresh")
    public ResponseEntity<?> handleConnectRefresh(@RequestParam String driverId) {
        // This endpoint handles refresh requests from Stripe
        // Redirect back to onboarding if needed
        String html = "<!DOCTYPE html><html><head><title>Stripe Connect</title>" +
                "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
                "<style>body{font-family:Arial,sans-serif;text-align:center;padding:50px;}" +
                "h1{color:#635BFF;}p{color:#666;}</style></head><body>" +
                "<h1>Please Complete Onboarding</h1>" +
                "<p>Please complete all required information to continue.</p>" +
                "</body></html>";
        return ResponseEntity.ok().header("Content-Type", "text/html").body(html);
    }
    
    @GetMapping("/connect/account/{accountId}")
    public ResponseEntity<?> getAccount(@PathVariable String accountId) {
        try {
            Account account = driverPaymentService.getAccount(accountId);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "accountId", account.getId(),
                "detailsSubmitted", account.getDetailsSubmitted(),
                "chargesEnabled", account.getChargesEnabled(),
                "payoutsEnabled", account.getPayoutsEnabled(),
                "email", account.getEmail() != null ? account.getEmail() : ""
            ));
        } catch (StripeException e) {
            log.error("Get Stripe account error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", "Stripe error: " + e.getMessage()));
        } catch (Exception e) {
            log.error("Get account error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

