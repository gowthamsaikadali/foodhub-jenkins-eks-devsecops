package com.foodhub.service;

import com.foodhub.config.AppProperties;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** All money maths for an order lives here, in one small testable class. Always BigDecimal, never double. */
@Component
public class OrderPricing {

    public record Totals(BigDecimal subtotal, BigDecimal deliveryFee, BigDecimal tax, BigDecimal total) { }

    private final AppProperties props;

    public OrderPricing(AppProperties props) {
        this.props = props;
    }

    public Totals calculate(BigDecimal subtotal) {
        BigDecimal sub = subtotal.setScale(2, RoundingMode.HALF_UP);
        BigDecimal delivery = sub.compareTo(props.freeDeliveryAbove()) >= 0
                ? BigDecimal.ZERO.setScale(2)
                : props.deliveryFee().setScale(2, RoundingMode.HALF_UP);
        BigDecimal tax = sub.multiply(props.taxRate()).setScale(2, RoundingMode.HALF_UP);
        BigDecimal total = sub.add(delivery).add(tax);
        return new Totals(sub, delivery, tax, total);
    }
}
