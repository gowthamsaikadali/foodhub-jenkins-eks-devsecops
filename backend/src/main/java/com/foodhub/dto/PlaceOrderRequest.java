package com.foodhub.dto;

import com.foodhub.entity.PaymentMethod;
import jakarta.validation.constraints.*;

/** No prices or totals here on purpose: the backend reads the cart and computes everything itself. */
public record PlaceOrderRequest(
        @NotBlank @Size(min = 5, max = 500) String deliveryAddress,
        @Size(max = 500) String notes,
        @NotNull PaymentMethod paymentMethod) {
}
