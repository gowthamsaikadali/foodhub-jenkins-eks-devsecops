package com.foodhub.dto;

public record AuthResponse(String token, String tokenType, long expiresInSeconds, UserResponse user) {
}
