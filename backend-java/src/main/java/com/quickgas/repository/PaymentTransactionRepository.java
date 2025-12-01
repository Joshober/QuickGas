package com.quickgas.repository;

import com.quickgas.entity.PaymentTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentTransactionRepository extends JpaRepository<PaymentTransaction, Long> {
    Optional<PaymentTransaction> findByStripePaymentIntentId(String stripePaymentIntentId);
    List<PaymentTransaction> findByOrderId(String orderId);
    List<PaymentTransaction> findByOrderIdAndStatus(String orderId, String status);
}

