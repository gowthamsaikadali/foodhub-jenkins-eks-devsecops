package com.foodhub.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.math.BigDecimal;

/** Business settings from application.yml (prefix "app.order"), so fees are never hardcoded in code. */
@ConfigurationProperties(prefix = "app.order")
public record AppProperties(BigDecimal deliveryFee, BigDecimal freeDeliveryAbove, BigDecimal taxRate) {
}
