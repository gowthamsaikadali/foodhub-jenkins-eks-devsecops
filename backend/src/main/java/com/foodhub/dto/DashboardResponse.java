package com.foodhub.dto;

import java.math.BigDecimal;

public record DashboardResponse(long totalCustomers, long totalRestaurants, long totalFoodItems, long totalOrders,
                                long pendingOrders, long completedOrders, BigDecimal totalOrderValue) {
}
