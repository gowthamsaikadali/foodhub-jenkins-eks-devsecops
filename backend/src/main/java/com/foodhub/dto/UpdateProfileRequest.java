package com.foodhub.dto;

import jakarta.validation.constraints.*;

public record UpdateProfileRequest(
        @NotBlank @Size(min = 2, max = 100) String fullName,
        @Pattern(regexp = "^$|^[0-9+\\- ]{7,20}$", message = "must be a valid phone number") String phone,
        @Size(max = 300) String address) {
}
