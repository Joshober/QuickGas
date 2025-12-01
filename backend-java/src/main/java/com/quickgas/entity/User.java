package com.quickgas.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {
    @Id
    @Column(name = "id", nullable = false, length = 255)
    private String id;
    
    @Column(name = "email", nullable = false, unique = true, length = 255)
    private String email;
    
    @Column(name = "name", nullable = false, length = 255)
    private String name;
    
    @Column(name = "phone", length = 50)
    private String phone;
    
    @Column(name = "role", nullable = false, length = 50)
    private String role;
    
    @Column(name = "default_role", nullable = false, length = 50)
    private String defaultRole;
    
    @Column(name = "fcm_token", columnDefinition = "TEXT")
    private String fcmToken;
    
    @Column(name = "stripe_account_id", length = 255)
    private String stripeAccountId;
    
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

