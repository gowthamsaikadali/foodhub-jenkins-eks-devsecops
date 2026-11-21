package com.foodhub.dto;

import com.foodhub.validation.StrongPassword;
import jakarta.validation.constraints.*;

public record RegisterRequest(
        @NotBlank @Size(min = 2, max = 100) String fullName,
        @NotBlank @Email @Size(max = 150) String email,
        @NotBlank @StrongPassword String password,
        @Pattern(regexp = "^$|^[0-9+\\- ]{7,20}$", message = "must be a valid phone number") String phone) {
}
