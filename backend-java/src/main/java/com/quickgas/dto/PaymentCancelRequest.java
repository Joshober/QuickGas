package com.quickgas.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PaymentCancelRequest {
    @NotBlank(message = "Payment intent ID is required")
    private String paymentIntentId;
}

