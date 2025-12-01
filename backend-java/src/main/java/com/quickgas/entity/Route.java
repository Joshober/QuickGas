package com.quickgas.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "routes")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Route {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "route_id", nullable = false, unique = true)
    private String routeId; // Firestore route ID
    
    @Column(name = "driver_id", nullable = false)
    private String driverId;
    
    @Column(name = "order_ids", columnDefinition = "TEXT")
    private String orderIds; // JSON array of order IDs
    
    @Column(name = "status", nullable = false, length = 50)
    private String status; // 'planning', 'active', 'completed'
    
    @Column(name = "polyline", columnDefinition = "TEXT")
    private String polyline; // Google Maps encoded polyline
    
    @Column(name = "waypoints", columnDefinition = "TEXT")
    private String waypoints; // JSON array of waypoints
    
    @Column(name = "total_distance")
    private Double totalDistance; // Total distance in km
    
    @Column(name = "total_duration")
    private Double totalDuration; // Total duration in minutes
    
    @Column(name = "started_at")
    private LocalDateTime startedAt;
    
    @Column(name = "completed_at")
    private LocalDateTime completedAt;
    
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

