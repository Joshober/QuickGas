package com.quickgas.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ImageResponse {
    private String id;
    private String orderId;
    private String imageType;
    private String fileName;
    private String contentType;
    private Long fileSize;
    private String url; // URL to access the image
    private String createdAt;
}

