package com.foodhub.controller;

import com.foodhub.dto.CartItemRequest;
import com.foodhub.dto.CartResponse;
import com.foodhub.service.CartService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/cart")
@Validated
@Tag(name = "Cart")
public class CartController {

    private final CartService cart;

    public CartController(CartService cart) {
        this.cart = cart;
    }

    @GetMapping
    public CartResponse get() {
        return cart.getCart();
    }

    @PostMapping("/items")
    public CartResponse add(@Valid @RequestBody CartItemRequest req) {
        return cart.addItem(req);
    }

    @PutMapping("/items/{foodItemId}")
    public CartResponse setQuantity(@PathVariable Long foodItemId,
                                    @RequestParam @Min(1) @Max(50) int quantity) {
        return cart.setQuantity(foodItemId, quantity);
    }

    @DeleteMapping("/items/{foodItemId}")
    public CartResponse remove(@PathVariable Long foodItemId) {
        return cart.removeItem(foodItemId);
    }

    @DeleteMapping
    public CartResponse clear() {
        return cart.clear();
    }
}
