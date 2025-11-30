package com.quickgas.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.IOException;

@Slf4j
@Configuration
public class FirebaseConfig {
    
    @Value("${firebase.service-account:}")
    private String serviceAccountJson;
    
    @Value("${firebase.enabled:false}")
    private boolean firebaseEnabled;
    
    @PostConstruct
    public void initializeFirebase() {
        if (!firebaseEnabled || serviceAccountJson == null || serviceAccountJson.isEmpty()) {
            log.info("Firebase Admin not initialized (disabled or missing service account)");
            return;
        }
        
        try {
            GoogleCredentials credentials = GoogleCredentials.fromStream(
                new ByteArrayInputStream(serviceAccountJson.getBytes())
            );
            
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(credentials)
                .build();
            
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                log.info("Firebase Admin initialized successfully");
            }
        } catch (IOException e) {
            log.error("Failed to initialize Firebase Admin: {}", e.getMessage());
        }
    }
    
    @Bean
    @ConditionalOnProperty(name = "firebase.enabled", havingValue = "true", matchIfMissing = false)
    public FirebaseMessaging firebaseMessaging() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                log.warn("Firebase not initialized, FirebaseMessaging bean will not be created");
                return null;
            }
            return FirebaseMessaging.getInstance();
        } catch (Exception e) {
            log.error("Failed to create FirebaseMessaging bean: {}", e.getMessage());
            return null;
        }
    }
}

