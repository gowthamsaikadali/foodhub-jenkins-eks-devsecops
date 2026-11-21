package com.foodhub.repository;

import com.foodhub.entity.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RestaurantRepository extends JpaRepository<Restaurant, Long> {

    List<Restaurant> findByAvailableTrueOrderByNameAsc();

    @Query("""
           select r from Restaurant r
           where r.available = true
             and (lower(r.name) like lower(concat('%', :q, '%'))
               or lower(coalesce(r.cuisine, '')) like lower(concat('%', :q, '%'))
               or lower(r.city) like lower(concat('%', :q, '%')))
           order by r.name asc
           """)
    List<Restaurant> search(@Param("q") String q);

    List<Restaurant> findByOwnerId(Long ownerId);

    long countByOwnerId(Long ownerId);
}
