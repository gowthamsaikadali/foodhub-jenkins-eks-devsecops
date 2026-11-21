package com.foodhub.mapper;

import com.foodhub.dto.*;
import com.foodhub.entity.*;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** Converts entities to API DTOs so entities (and password hashes) never leave the service layer. */
@Component
public class EntityMapper {

    public UserResponse toUser(User u) {
        Set<String> roles = u.getRoles().stream().map(Role::getName).collect(Collectors.toSet());
        return new UserResponse(u.getId(), u.getFullName(), u.getEmail(), u.getPhone(), u.getAddress(), roles);
    }

    public RestaurantResponse toRestaurant(Restaurant r) {
        return new RestaurantResponse(r.getId(), r.getName(), r.getDescription(), r.getCuisine(), r.getAddress(),
                r.getCity(), r.getPhone(), r.getImageUrl(), r.getRating(), r.isAvailable());
    }

    public CategoryResponse toCategory(FoodCategory c) {
        return new CategoryResponse(c.getId(), c.getName(), c.getDescription());
    }

    public FoodResponse toFood(FoodItem f) {
        FoodCategory c = f.getCategory();
        return new FoodResponse(f.getId(), f.getRestaurant().getId(), f.getRestaurant().getName(),
                c == null ? null : c.getId(), c == null ? null : c.getName(),
                f.getName(), f.getDescription(), f.getPrice(), f.getImageUrl(), f.isAvailable());
    }

    public CartResponse toCart(Cart cart) {
        List<CartItemResponse> items = cart.getItems().stream()
                .sorted(Comparator.comparing(ci -> ci.getFoodItem().getName()))
                .map(ci -> {
                    FoodItem f = ci.getFoodItem();
                    BigDecimal line = f.getPrice().multiply(BigDecimal.valueOf(ci.getQuantity()));
                    return new CartItemResponse(f.getId(), f.getName(), f.getImageUrl(), f.getPrice(),
                            ci.getQuantity(), line, f.isAvailable());
                }).toList();
        BigDecimal subtotal = items.stream().map(CartItemResponse::lineTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        Restaurant r = cart.getRestaurant();
        return new CartResponse(r == null ? null : r.getId(), r == null ? null : r.getName(), items, subtotal);
    }

    public PaymentResponse toPayment(Payment p) {
        if (p == null) {
            return null;
        }
        return new PaymentResponse(p.getId(), p.getOrder().getId(), p.getMethod(), p.getStatus(), p.getAmount(),
                p.getTransactionRef(), p.getCreatedAt());
    }

    public OrderResponse toOrder(Order o) {
        List<OrderItemResponse> items = o.getItems().stream()
                .map(i -> new OrderItemResponse(i.getFoodItem() == null ? null : i.getFoodItem().getId(),
                        i.getFoodName(), i.getUnitPrice(), i.getQuantity(), i.getLineTotal()))
                .toList();
        return new OrderResponse(o.getId(), o.getRestaurant().getId(), o.getRestaurant().getName(),
                o.getUser().getFullName(), o.getUser().getEmail(), o.getStatus(), o.getStatus().allowedNext(),
                o.getSubtotal(), o.getDeliveryFee(), o.getTax(), o.getTotalAmount(), o.getDeliveryAddress(),
                o.getNotes(), items, toPayment(o.getPayment()), o.getCreatedAt(), o.getUpdatedAt());
    }
}
