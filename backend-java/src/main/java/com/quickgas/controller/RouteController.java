package com.quickgas.controller;

import com.quickgas.dto.RouteOptimizeRequest;
import com.quickgas.service.RouteService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/routes")
@RequiredArgsConstructor
public class RouteController {
    
    private final RouteService routeService;
    
    @PostMapping("/optimize")
    public ResponseEntity<?> optimizeRoute(@Valid @RequestBody RouteOptimizeRequest request) {
        try {
            var response = routeService.optimizeRoute(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Route optimization error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

