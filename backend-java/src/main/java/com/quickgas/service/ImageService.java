package com.quickgas.service;

import com.quickgas.dto.ImageResponse;
import com.quickgas.entity.ImageEntity;
import com.quickgas.repository.ImageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ImageService {
    
    private final ImageRepository imageRepository;
    
    @Value("${server.port:8080}")
    private int serverPort;
    
    @Value("${server.address:localhost}")
    private String serverAddress;
    
    @Value("${server.base-url:}")
    private String baseUrl;
    
    @Transactional
    public ImageResponse uploadImage(String orderId, String imageType, MultipartFile file) 
            throws IOException {
        // Generate unique ID for image
        String imageId = UUID.randomUUID().toString();
        
        // Read file data
        byte[] imageData = file.getBytes();
        
        // Create image entity
        ImageEntity imageEntity = ImageEntity.builder()
            .id(imageId)
            .orderId(orderId)
            .imageType(imageType)
            .fileName(file.getOriginalFilename())
            .contentType(file.getContentType())
            .fileSize(file.getSize())
            .imageData(imageData)
            .createdAt(LocalDateTime.now())
            .updatedAt(LocalDateTime.now())
            .build();
        
        // Save to database
        imageEntity = imageRepository.save(imageEntity);
        
        // Build response with URL
        String imageUrl;
        if (baseUrl != null && !baseUrl.isEmpty()) {
            imageUrl = String.format("%s/api/images/%s", baseUrl, imageId);
        } else {
            imageUrl = String.format("http://%s:%d/api/images/%s", 
                serverAddress, serverPort, imageId);
        }
        
        return ImageResponse.builder()
            .id(imageEntity.getId())
            .orderId(imageEntity.getOrderId())
            .imageType(imageEntity.getImageType())
            .fileName(imageEntity.getFileName())
            .contentType(imageEntity.getContentType())
            .fileSize(imageEntity.getFileSize())
            .url(imageUrl)
            .createdAt(imageEntity.getCreatedAt().toString())
            .build();
    }
    
    public ImageEntity getImage(String imageId) {
        return imageRepository.findById(imageId)
            .orElseThrow(() -> new RuntimeException("Image not found: " + imageId));
    }
    
    public List<ImageResponse> getImagesByOrder(String orderId) {
        List<ImageEntity> images = imageRepository.findByOrderId(orderId);
        
        return images.stream()
            .map(image -> {
                String imageUrl;
                if (baseUrl != null && !baseUrl.isEmpty()) {
                    imageUrl = String.format("%s/api/images/%s", baseUrl, image.getId());
                } else {
                    imageUrl = String.format("http://%s:%d/api/images/%s", 
                        serverAddress, serverPort, image.getId());
                }
                
                return ImageResponse.builder()
                    .id(image.getId())
                    .orderId(image.getOrderId())
                    .imageType(image.getImageType())
                    .fileName(image.getFileName())
                    .contentType(image.getContentType())
                    .fileSize(image.getFileSize())
                    .url(imageUrl)
                    .createdAt(image.getCreatedAt().toString())
                    .build();
            })
            .collect(Collectors.toList());
    }
    
    @Transactional
    public void deleteImage(String imageId) {
        if (!imageRepository.existsById(imageId)) {
            throw new RuntimeException("Image not found: " + imageId);
        }
        imageRepository.deleteById(imageId);
    }
    
    public ImageResponse getImageResponse(String imageId) {
        ImageEntity image = getImage(imageId);
        String imageUrl;
        if (baseUrl != null && !baseUrl.isEmpty()) {
            imageUrl = String.format("%s/api/images/%s", baseUrl, image.getId());
        } else {
            imageUrl = String.format("http://%s:%d/api/images/%s", 
                serverAddress, serverPort, image.getId());
        }
        
        return ImageResponse.builder()
            .id(image.getId())
            .orderId(image.getOrderId())
            .imageType(image.getImageType())
            .fileName(image.getFileName())
            .contentType(image.getContentType())
            .fileSize(image.getFileSize())
            .url(imageUrl)
            .createdAt(image.getCreatedAt().toString())
            .build();
    }
}

