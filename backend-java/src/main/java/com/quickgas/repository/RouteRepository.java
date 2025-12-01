package com.quickgas.repository;

import com.quickgas.entity.Route;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RouteRepository extends JpaRepository<Route, Long> {
    Optional<Route> findByRouteId(String routeId);
    
    List<Route> findByDriverIdAndStatusIn(String driverId, List<String> statuses);
    
    List<Route> findByDriverId(String driverId);
    
    void deleteByRouteId(String routeId);
}

