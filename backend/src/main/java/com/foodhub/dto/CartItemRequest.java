package com.foodhub.dto;

import jakarta.validation.constraints.*;

public record CartItemRequest(@NotNull Long foodItemId, @NotNull @Min(1) @Max(50) Integer quantity) {
}
