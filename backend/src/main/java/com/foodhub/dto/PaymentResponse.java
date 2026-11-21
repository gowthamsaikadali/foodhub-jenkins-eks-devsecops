package com.foodhub.dto;

import com.foodhub.entity.PaymentMethod;
import com.foodhub.entity.PaymentStatus;

import java.math.BigDecimal;
import java.time.Instant;

public record PaymentResponse(Long id, Long orderId, PaymentMethod method, PaymentStatus status, BigDecimal amount,
                              String transactionRef, Instant createdAt) {
}
