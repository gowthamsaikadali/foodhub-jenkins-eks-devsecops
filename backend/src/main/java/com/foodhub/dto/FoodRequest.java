package com.foodhub.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record FoodRequest(
        @NotNull Long restaurantId,
        Long categoryId,
        @NotBlank @Size(max = 120) String name,
        @Size(max = 1000) String description,
        @NotNull @DecimalMin(value = "0.00") @Digits(integer = 8, fraction = 2) BigDecimal price,
        @Size(max = 500) String imageUrl,
        Boolean available) {
}
