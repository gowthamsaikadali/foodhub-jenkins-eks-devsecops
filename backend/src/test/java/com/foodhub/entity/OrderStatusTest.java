package com.foodhub.entity;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class OrderStatusTest {

    @Test
    void happyPathIsAllowed() {
        assertThat(OrderStatus.PLACED.canMoveTo(OrderStatus.CONFIRMED)).isTrue();
        assertThat(OrderStatus.CONFIRMED.canMoveTo(OrderStatus.PREPARING)).isTrue();
        assertThat(OrderStatus.PREPARING.canMoveTo(OrderStatus.READY)).isTrue();
        assertThat(OrderStatus.READY.canMoveTo(OrderStatus.DELIVERED)).isTrue();
    }

    @Test
    void cannotSkipOrGoBackwards() {
        assertThat(OrderStatus.PLACED.canMoveTo(OrderStatus.DELIVERED)).isFalse();
        assertThat(OrderStatus.READY.canMoveTo(OrderStatus.PLACED)).isFalse();
    }

    @Test
    void finalStatesHaveNoTransitions() {
        assertThat(OrderStatus.DELIVERED.isFinal()).isTrue();
        assertThat(OrderStatus.CANCELLED.isFinal()).isTrue();
        assertThat(OrderStatus.REJECTED.isFinal()).isTrue();
        assertThat(OrderStatus.DELIVERED.canMoveTo(OrderStatus.CANCELLED)).isFalse();
    }

    @Test
    void placedOrderCanBeRejectedButPreparingCannot() {
        assertThat(OrderStatus.PLACED.canMoveTo(OrderStatus.REJECTED)).isTrue();
        assertThat(OrderStatus.PREPARING.canMoveTo(OrderStatus.REJECTED)).isFalse();
    }
}
