package com.foodhub.dto;

import java.math.BigDecimal;
import java.util.List;

public record CartResponse(Long restaurantId, String restaurantName, List<CartItemResponse> items, BigDecimal subtotal) {
}
