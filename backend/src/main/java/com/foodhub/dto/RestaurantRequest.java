package com.foodhub.dto;

import jakarta.validation.constraints.*;

public record RestaurantRequest(
        @NotBlank @Size(max = 120) String name,
        @Size(max = 1000) String description,
        @Size(max = 60) String cuisine,
        @NotBlank @Size(max = 300) String address,
        @NotBlank @Size(max = 80) String city,
        @Pattern(regexp = "^$|^[0-9+\\- ]{7,20}$", message = "must be a valid phone number") String phone,
        @Size(max = 500) String imageUrl,
        Boolean available) {
}
