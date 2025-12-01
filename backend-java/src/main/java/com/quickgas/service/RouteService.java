package com.quickgas.service;

import com.quickgas.dto.RouteOptimizeRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
public class RouteService {
    
    private final WebClient webClient;
    
    @Value("${openrouteservice.api-key:}")
    private String defaultApiKey;
    
    public RouteService() {
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
}

