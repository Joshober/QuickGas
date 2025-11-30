package com.quickgas.controller;

import com.quickgas.dto.ImageResponse;
import com.quickgas.service.ImageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/images")
@RequiredArgsConstructor
public class ImageController {
    
    private final ImageService imageService;
    
    @PostMapping("/upload")
    public ResponseEntity<?> uploadImage(
            @RequestParam("orderId") String orderId,
            @RequestParam("imageType") String imageType,
            @RequestParam("file") MultipartFile file) {
        try {
            if (file.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "File is empty"));
            }
            
            // Validate file type
            String contentType = file.getContentType();
            if (contentType == null || !contentType.startsWith("image/")) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "File must be an image"));
            }
            
            // Validate file size (max 10MB)
            if (file.getSize() > 10 * 1024 * 1024) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "File size exceeds 10MB limit"));
            }
            
            ImageResponse response = imageService.uploadImage(orderId, imageType, file);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Image upload error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @GetMapping("/{imageId}")
    public ResponseEntity<byte[]> getImage(@PathVariable String imageId) {
        try {
            var image = imageService.getImage(imageId);
            
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.parseMediaType(image.getContentType()));
            headers.setContentLength(image.getFileSize());
            headers.set("Content-Disposition", 
                "inline; filename=\"" + image.getFileName() + "\"");
            
            return ResponseEntity.ok()
                .headers(headers)
                .body(image.getImageData());
        } catch (Exception e) {
            log.error("Image retrieval error: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }
    
    @GetMapping("/order/{orderId}")
    public ResponseEntity<?> getImagesByOrder(@PathVariable String orderId) {
        try {
            var images = imageService.getImagesByOrder(orderId);
            return ResponseEntity.ok(images);
        } catch (Exception e) {
            log.error("Error retrieving images for order: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @DeleteMapping("/{imageId}")
    public ResponseEntity<?> deleteImage(@PathVariable String imageId) {
        try {
            imageService.deleteImage(imageId);
            return ResponseEntity.ok(Map.of("success", true, "message", "Image deleted"));
        } catch (Exception e) {
            log.error("Image deletion error: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

