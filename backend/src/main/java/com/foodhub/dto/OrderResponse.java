package com.foodhub.dto;

import com.foodhub.entity.OrderStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Set;

public record OrderResponse(Long id, Long restaurantId, String restaurantName, String customerName, String customerEmail,
                            OrderStatus status, Set<OrderStatus> nextStatuses, BigDecimal subtotal, BigDecimal deliveryFee,
                            BigDecimal tax, BigDecimal totalAmount, String deliveryAddress, String notes,
                            List<OrderItemResponse> items, PaymentResponse payment, Instant createdAt, Instant updatedAt) {
}
