package com.foodhub.dto;

import java.util.Set;

public record UserResponse(Long id, String fullName, String email, String phone, String address, Set<String> roles) {
}
