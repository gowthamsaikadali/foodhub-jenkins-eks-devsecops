package com.foodhub.service;

import com.foodhub.config.AppProperties;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

class OrderPricingTest {

    private final OrderPricing pricing = new OrderPricing(
            new AppProperties(new BigDecimal("40.00"), new BigDecimal("500.00"), new BigDecimal("0.05")));

    @Test
    void addsDeliveryFeeAndTaxBelowFreeDeliveryThreshold() {
        OrderPricing.Totals t = pricing.calculate(new BigDecimal("200.00"));
        assertThat(t.subtotal()).isEqualByComparingTo("200.00");
        assertThat(t.deliveryFee()).isEqualByComparingTo("40.00");
        assertThat(t.tax()).isEqualByComparingTo("10.00");
        assertThat(t.total()).isEqualByComparingTo("250.00");
    }

    @Test
    void deliveryIsFreeAtOrAboveThreshold() {
        OrderPricing.Totals t = pricing.calculate(new BigDecimal("500.00"));
        assertThat(t.deliveryFee()).isEqualByComparingTo("0.00");
        assertThat(t.total()).isEqualByComparingTo("525.00");
    }

    @Test
    void taxIsRoundedHalfUpToTwoDecimals() {
        OrderPricing.Totals t = pricing.calculate(new BigDecimal("30.10")); // 1.505 -> 1.51
        assertThat(t.tax()).isEqualByComparingTo("1.51");
    }
}
