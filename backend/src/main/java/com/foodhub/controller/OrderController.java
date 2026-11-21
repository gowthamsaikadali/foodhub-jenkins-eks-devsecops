package com.foodhub.controller;

import com.foodhub.dto.OrderResponse;
import com.foodhub.dto.PlaceOrderRequest;
import com.foodhub.service.OrderService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
@Tag(name = "Orders (customer)")
public class OrderController {

    private final OrderService orders;

    public OrderController(OrderService orders) {
        this.orders = orders;
    }

    @PostMapping
    public ResponseEntity<OrderResponse> place(@Valid @RequestBody PlaceOrderRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(orders.place(req));
    }

    @GetMapping("/my-orders")
    public List<OrderResponse> myOrders() {
        return orders.myOrders();
    }

    @GetMapping("/{id}")
    public OrderResponse get(@PathVariable Long id) {
        return orders.getOne(id);
    }

    @PostMapping("/{id}/cancel")
    public OrderResponse cancel(@PathVariable Long id) {
        return orders.cancelMine(id);
    }
}
