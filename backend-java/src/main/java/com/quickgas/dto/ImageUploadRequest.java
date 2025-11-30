package com.quickgas.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import org.springframework.web.multipart.MultipartFile;

@Data
public class ImageUploadRequest {
    @NotBlank(message = "Order ID is required")
    private String orderId;
    
    @NotBlank(message = "Image type is required")
    private String imageType; // 'delivery_photo', 'profile_picture', etc.
    
    @NotNull(message = "Image file is required")
    private MultipartFile file;
}

