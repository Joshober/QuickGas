package com.quickgas.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Slf4j
@Configuration
public class FirebaseConfig {
    
    @Value("${firebase.service-account:}")
    private String serviceAccountJson;
    
    @Value("${firebase.enabled:false}")
    private boolean firebaseEnabled;
    
    @PostConstruct
    public void initializeFirebase() {
        if (!firebaseEnabled) {
            log.info("Firebase Admin not initialized (FIREBASE_ENABLED=false)");
            return;
        }
        
        if (serviceAccountJson == null || serviceAccountJson.trim().isEmpty()) {
            log.warn("Firebase Admin not initialized - FIREBASE_SERVICE_ACCOUNT is empty or not set");
            log.warn("To enable Firebase notifications, set FIREBASE_SERVICE_ACCOUNT environment variable with your service account JSON");
            return;
        }
        
        try {
            // Clean up the JSON string (remove any extra whitespace/newlines)
            String cleanedJson = serviceAccountJson.trim();
            
            log.info("Attempting to initialize Firebase Admin...");
            GoogleCredentials credentials = GoogleCredentials.fromStream(
                new ByteArrayInputStream(cleanedJson.getBytes(StandardCharsets.UTF_8))
            );
            
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(credentials)
                .build();
            
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                log.info("✅ Firebase Admin initialized successfully");
                log.info("Firebase Cloud Messaging is now available for push notifications");
            } else {
                log.info("Firebase Admin already initialized");
            }
        } catch (IOException e) {
            log.error("❌ Failed to initialize Firebase Admin: {}", e.getMessage());
            log.error("Error details: ", e);
            log.error("Please check that FIREBASE_SERVICE_ACCOUNT contains valid JSON");
            log.warn("Application will continue without Firebase support. Set FIREBASE_ENABLED=false to suppress this warning.");
        } catch (Exception e) {
            log.error("❌ Unexpected error initializing Firebase Admin: {}", e.getMessage());
            log.error("Error details: ", e);
            log.warn("Application will continue without Firebase support. Set FIREBASE_ENABLED=false to suppress this warning.");
        }
    }
    
    @Bean
    @ConditionalOnProperty(name = "firebase.enabled", havingValue = "true", matchIfMissing = false)
    @ConditionalOnExpression("T(com.google.firebase.FirebaseApp).getApps().size() > 0")
    public FirebaseMessaging firebaseMessaging() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                log.warn("Firebase not initialized, FirebaseMessaging bean will not be created");
                throw new IllegalStateException("Firebase not initialized");
            }
            return FirebaseMessaging.getInstance();
        } catch (Exception e) {
            log.error("Failed to create FirebaseMessaging bean: {}", e.getMessage());
            throw new IllegalStateException("Failed to create FirebaseMessaging", e);
        }
    }
}

