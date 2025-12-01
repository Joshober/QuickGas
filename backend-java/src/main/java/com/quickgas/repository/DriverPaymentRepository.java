package com.quickgas.repository;

import com.quickgas.entity.DriverPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DriverPaymentRepository extends JpaRepository<DriverPayment, Long> {
    List<DriverPayment> findByDriverId(String driverId);
    
    List<DriverPayment> findByDriverIdAndStatus(String driverId, String status);
    
    Optional<DriverPayment> findByOrderId(String orderId);
    
    List<DriverPayment> findByOrderIdAndStatus(String orderId, String status);
}

