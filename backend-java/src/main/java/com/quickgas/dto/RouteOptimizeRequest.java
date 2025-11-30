package com.quickgas.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class RouteOptimizeRequest {
    @NotNull(message = "Locations are required")
    @Size(min = 2, message = "At least 2 locations required")
    private List<List<Double>> locations;
    
    private String apiKey;
}

