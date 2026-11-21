package com.foodhub.dto;

import jakarta.validation.constraints.NotNull;

/** Simulated payment. There are deliberately NO card number / CVV fields: we never accept or store them. */
public record PaymentRequest(@NotNull Long orderId, boolean simulateFailure) {
}
