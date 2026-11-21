package com.foodhub.dto;

import java.math.BigDecimal;

public record RestaurantResponse(Long id, String name, String description, String cuisine, String address,
                                 String city, String phone, String imageUrl, BigDecimal rating, boolean available) {
}
