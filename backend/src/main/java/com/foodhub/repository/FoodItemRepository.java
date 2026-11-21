package com.foodhub.repository;

import com.foodhub.entity.FoodItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface FoodItemRepository extends JpaRepository<FoodItem, Long> {

    List<FoodItem> findByRestaurantIdOrderByNameAsc(Long restaurantId);

    List<FoodItem> findByRestaurantIdAndAvailableTrueOrderByNameAsc(Long restaurantId);

    long countByRestaurantOwnerId(Long ownerId);

    @Query("""
           select f from FoodItem f join fetch f.restaurant r left join f.category c
           where f.available = true and r.available = true
             and (:q = '' or lower(f.name) like lower(concat('%', :q, '%'))
                  or lower(coalesce(f.description, '')) like lower(concat('%', :q, '%')))
             and (:categoryId is null or c.id = :categoryId)
           order by f.name asc
           """)
    List<FoodItem> search(@Param("q") String q, @Param("categoryId") Long categoryId);
}
