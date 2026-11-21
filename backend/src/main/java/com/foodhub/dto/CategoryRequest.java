package com.foodhub.dto;

import jakarta.validation.constraints.*;

public record CategoryRequest(@NotBlank @Size(max = 60) String name, @Size(max = 300) String description) {
}
