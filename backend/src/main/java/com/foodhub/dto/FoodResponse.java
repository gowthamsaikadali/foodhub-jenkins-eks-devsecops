package com.foodhub.dto;

import java.math.BigDecimal;

public record FoodResponse(Long id, Long restaurantId, String restaurantName, Long categoryId, String categoryName,
                           String name, String description, BigDecimal price, String imageUrl, boolean available) {
}
