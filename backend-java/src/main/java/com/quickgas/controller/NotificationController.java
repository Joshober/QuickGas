package com.quickgas.controller;

import com.quickgas.dto.NotificationRequest;
import com.quickgas.dto.BatchNotificationRequest;
import com.quickgas.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.validation.Valid;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {
    
    private final NotificationService notificationService;
    
    @PostMapping("/send")
    public ResponseEntity<?> sendNotification(@Valid @RequestBody NotificationRequest request) {
        try {
            if (!notificationService.isFirebaseEnabled()) {
                return ResponseEntity.status(503)
                    .body(Map.of("error", "Firebase Admin not initialized"));
            }
            
            String messageId = notificationService.sendNotification(request);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "messageId", messageId
            ));
        } catch (Exception e) {
            log.error("Notification sending error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
    
    @PostMapping("/send-multiple")
    public ResponseEntity<?> sendBatchNotifications(@Valid @RequestBody BatchNotificationRequest request) {
        try {
            if (!notificationService.isFirebaseEnabled()) {
                return ResponseEntity.status(503)
                    .body(Map.of("error", "Firebase Admin not initialized"));
            }
            
            var result = notificationService.sendBatchNotifications(request);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "successCount", result.get("successCount"),
                "failureCount", result.get("failureCount")
            ));
        } catch (Exception e) {
            log.error("Batch notification error: {}", e.getMessage());
            return ResponseEntity.status(500)
                .body(Map.of("error", e.getMessage()));
        }
    }
}

