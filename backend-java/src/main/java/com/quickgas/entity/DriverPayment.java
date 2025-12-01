package com.quickgas.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "driver_payments")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DriverPayment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "driver_id", nullable = false)
    private String driverId;
    
    @Column(name = "order_id", nullable = false)
    private String orderId;
    
    @Column(name = "route_id")
    private String routeId; // Optional route ID
    
    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount; // 80% of order total
    
    @Column(name = "currency", nullable = false, length = 10)
    private String currency;
    
    @Column(name = "status", nullable = false, length = 50)
    private String status; // 'pending', 'paid', 'failed'
    
    @Column(name = "stripe_payout_id")
    private String stripePayoutId;
    
    @Column(name = "stripe_transfer_id")
    private String stripeTransferId;
    
    @Column(name = "paid_at")
    private LocalDateTime paidAt;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

