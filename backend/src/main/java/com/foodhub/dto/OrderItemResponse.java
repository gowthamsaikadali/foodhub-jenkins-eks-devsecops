package com.foodhub.dto;

import java.math.BigDecimal;

public record OrderItemResponse(Long foodItemId, String foodName, BigDecimal unitPrice, int quantity, BigDecimal lineTotal) {
}
