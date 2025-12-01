package com.quickgas.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

import java.util.Map;

@Data
public class PaymentIntentRequest {
    @NotNull(message = "Amount is required")
    @Min(value = 1, message = "Amount must be greater than 0")
    private Double amount;
    
    @Pattern(regexp = "^[a-z]{3}$", message = "Currency must be a valid 3-letter ISO 4217 code")
    private String currency;
    
    private Map<String, String> metadata;
    
    private String idempotencyKey;
}

