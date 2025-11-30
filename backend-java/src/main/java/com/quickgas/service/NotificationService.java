package com.quickgas.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MulticastMessage;
import com.quickgas.dto.BatchNotificationRequest;
import com.quickgas.dto.NotificationRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {
    
    private final FirebaseMessaging firebaseMessaging;
    
    public boolean isFirebaseEnabled() {
        return firebaseMessaging != null;
    }
    
    public String sendNotification(NotificationRequest request) throws FirebaseMessagingException {
        if (firebaseMessaging == null) {
            throw new IllegalStateException("Firebase Messaging not initialized");
        }
        
        Message.Builder messageBuilder = Message.builder()
            .setToken(request.getFcmToken())
            .setNotification(
                com.google.firebase.messaging.Notification.builder()
                    .setTitle(request.getTitle())
                    .setBody(request.getBody())
                    .build()
            );
        
        if (request.getData() != null && !request.getData().isEmpty()) {
            Map<String, String> dataMap = new HashMap<>();
            request.getData().forEach((key, value) -> 
                dataMap.put(key, String.valueOf(value))
            );
            messageBuilder.putAllData(dataMap);
        }
        
        return firebaseMessaging.send(messageBuilder.build());
    }
    
    public Map<String, Integer> sendBatchNotifications(BatchNotificationRequest request) 
            throws FirebaseMessagingException {
        if (firebaseMessaging == null) {
            throw new IllegalStateException("Firebase Messaging not initialized");
        }
        
        MulticastMessage.Builder messageBuilder = MulticastMessage.builder()
            .addAllTokens(request.getFcmTokens())
            .setNotification(
                com.google.firebase.messaging.Notification.builder()
                    .setTitle(request.getTitle())
                    .setBody(request.getBody())
                    .build()
            );
        
        if (request.getData() != null && !request.getData().isEmpty()) {
            Map<String, String> dataMap = new HashMap<>();
            request.getData().forEach((key, value) -> 
                dataMap.put(key, String.valueOf(value))
            );
            messageBuilder.putAllData(dataMap);
        }
        
        var response = firebaseMessaging.sendEachForMulticast(messageBuilder.build());
        
        Map<String, Integer> result = new HashMap<>();
        result.put("successCount", response.getSuccessCount());
        result.put("failureCount", response.getFailureCount());
        
        return result;
    }
}

