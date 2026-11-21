package com.foodhub.entity;

import java.util.EnumSet;
import java.util.Set;

/** Order lifecycle. Allowed transitions are enforced in {@link #canMoveTo(OrderStatus)}. */
public enum OrderStatus {
    PLACED, CONFIRMED, PREPARING, READY, DELIVERED, CANCELLED, REJECTED;

    public Set<OrderStatus> allowedNext() {
        return switch (this) {
            case PLACED -> EnumSet.of(CONFIRMED, REJECTED, CANCELLED);
            case CONFIRMED -> EnumSet.of(PREPARING, CANCELLED);
            case PREPARING -> EnumSet.of(READY);
            case READY -> EnumSet.of(DELIVERED);
            case DELIVERED, CANCELLED, REJECTED -> EnumSet.noneOf(OrderStatus.class);
        };
    }

    public boolean canMoveTo(OrderStatus next) {
        return allowedNext().contains(next);
    }

    public boolean isFinal() {
        return allowedNext().isEmpty();
    }
}
