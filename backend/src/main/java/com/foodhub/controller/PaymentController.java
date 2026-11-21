package com.foodhub.controller;

import com.foodhub.dto.PaymentRequest;
import com.foodhub.dto.PaymentResponse;
import com.foodhub.service.PaymentService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/payments")
@Tag(name = "Payments (simulated)")
public class PaymentController {

    private final PaymentService payments;

    public PaymentController(PaymentService payments) {
        this.payments = payments;
    }

    @PostMapping
    public PaymentResponse pay(@Valid @RequestBody PaymentRequest req) {
        return payments.pay(req);
    }

    @GetMapping("/{orderId}")
    public PaymentResponse get(@PathVariable Long orderId) {
        return payments.getForOrder(orderId);
    }
}
