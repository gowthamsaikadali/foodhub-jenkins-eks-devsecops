package com.foodhub.controller;

import com.foodhub.dto.OrderResponse;
import com.foodhub.dto.UpdateOrderStatusRequest;
import com.foodhub.service.OrderService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/orders")
@Tag(name = "Admin - Orders")
public class AdminOrderController {

    private final OrderService orders;

    public AdminOrderController(OrderService orders) {
        this.orders = orders;
    }

    @GetMapping
    public List<OrderResponse> list() {
        return orders.adminOrders();
    }

    @PatchMapping("/{id}/status")
    public OrderResponse updateStatus(@PathVariable Long id, @Valid @RequestBody UpdateOrderStatusRequest req) {
        return orders.updateStatus(id, req.status());
    }
}
