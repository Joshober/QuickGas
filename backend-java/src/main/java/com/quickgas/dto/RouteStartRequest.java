package com.quickgas.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
public class RouteStartRequest {
    @NotBlank(message = "Route ID is required")
    private String routeId;
    
    @NotEmpty(message = "Order IDs are required")
    private List<String> orderIds;
    
    // Map of orderId -> customerFcmToken for notifications
    private Map<String, String> customerFcmTokens;
}

