package com.quickgas.repository;

import com.quickgas.entity.ImageEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ImageRepository extends JpaRepository<ImageEntity, String> {
    Optional<ImageEntity> findByOrderIdAndImageType(String orderId, String imageType);
    List<ImageEntity> findByOrderId(String orderId);
    List<ImageEntity> findByImageType(String imageType);
}

