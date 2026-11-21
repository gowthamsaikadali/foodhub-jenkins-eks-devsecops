package com.foodhub.repository;

import com.foodhub.entity.FoodCategory;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FoodCategoryRepository extends JpaRepository<FoodCategory, Long> {
    boolean existsByNameIgnoreCase(String name);
}
