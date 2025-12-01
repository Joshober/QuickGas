package com.quickgas.service;

import com.quickgas.dto.RouteOptimizeRequest;
import com.quickgas.dto.RouteStartRequest;
import com.quickgas.dto.NotificationRequest;
import com.quickgas.repository.RouteRepository;
import com.quickgas.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class RouteService {
    
    private final WebClient webClient;
    private final RouteRepository routeRepository;
    private final NotificationService notificationService;
    
    @Value("${openrouteservice.api-key:}")
    private String defaultApiKey;
    
    public RouteService(RouteRepository routeRepository, NotificationService notificationService) {
        this.routeRepository = routeRepository;
        this.notificationService = notificationService;
        this.webClient = WebClient.builder()
            .baseUrl("https://api.openrouteservice.org/v2")
            .build();
    }
    
    public Map<String, Object> optimizeRoute(RouteOptimizeRequest request) {
        String apiKey = request.getApiKey() != null && !request.getApiKey().isEmpty()
            ? request.getApiKey()
            : defaultApiKey;
        
        if (apiKey == null || apiKey.isEmpty()) {
            throw new IllegalArgumentException("OpenRouteService API key required");
        }
        
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("locations", request.getLocations());
        requestBody.put("metrics", new String[]{"distance", "duration"});
        
        @SuppressWarnings("unchecked")
        Map<String, Object> response = webClient.post()
            .uri("/matrix/driving-car")
            .header("Authorization", "Bearer " + apiKey)
            .header("Content-Type", "application/json")
            .bodyValue(requestBody)
            .retrieve()
            .bodyToMono(Map.class)
            .block();
        
        if (response == null) {
            throw new RuntimeException("Failed to get response from OpenRouteService");
        }
        
        Map<String, Object> result = new HashMap<>();
        result.put("distances", response.get("distances"));
        result.put("durations", response.get("durations"));
        
        return result;
    }
    
    @Transactional
    public Map<String, Object> startRoute(RouteStartRequest request) {
        log.info("Starting route: routeId={}, orderIds={}", request.getRouteId(), request.getOrderIds());
        
        // Update route status in database (if route exists)
        routeRepository.findByRouteId(request.getRouteId()).ifPresent(route -> {
            route.setStatus("active");
            route.setStartedAt(LocalDateTime.now());
            routeRepository.save(route);
        });
        
        // Send notifications to all order owners
        Map<String, Integer> notificationResults = new HashMap<>();
        notificationResults.put("successCount", 0);
        notificationResults.put("failureCount", 0);
        
        if (notificationService.isFirebaseEnabled() && request.getCustomerFcmTokens() != null) {
            for (Map.Entry<String, String> entry : request.getCustomerFcmTokens().entrySet()) {
                String orderId = entry.getKey();
                String fcmToken = entry.getValue();
                
                if (fcmToken != null && !fcmToken.isEmpty()) {
                    try {
                        NotificationRequest notificationRequest = new NotificationRequest();
                        notificationRequest.setFcmToken(fcmToken);
                        notificationRequest.setTitle("Delivery Started");
                        notificationRequest.setBody("Your delivery has started! Driver is on the way.");
                        notificationRequest.setData(Map.of("orderId", orderId, "status", "in_transit", "type", "route_started"));
                        
                        notificationService.sendNotification(notificationRequest);
                        notificationResults.put("successCount", notificationResults.get("successCount") + 1);
                    } catch (Exception e) {
                        log.error("Failed to send notification to order {}: {}", orderId, e.getMessage());
                        notificationResults.put("failureCount", notificationResults.get("failureCount") + 1);
                    }
                }
            }
        }
        
        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("routeId", request.getRouteId());
        result.put("notifications", notificationResults);
        
        return result;
    }
    
    @Transactional
    public Map<String, Object> completeRoute(String routeId) {
        log.info("Completing route: routeId={}", routeId);
        
        routeRepository.findByRouteId(routeId).ifPresent(route -> {
            route.setStatus("completed");
            route.setCompletedAt(LocalDateTime.now());
            routeRepository.save(route);
            // Delete route (only active routes are saved)
            routeRepository.deleteByRouteId(routeId);
        });
        
        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("routeId", routeId);
        
        return result;
    }
}

