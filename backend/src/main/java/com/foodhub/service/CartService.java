package com.foodhub.service;

import com.foodhub.dto.CartItemRequest;
import com.foodhub.dto.CartResponse;
import com.foodhub.entity.Cart;
import com.foodhub.entity.CartItem;
import com.foodhub.entity.FoodItem;
import com.foodhub.exception.BadRequestException;
import com.foodhub.exception.ResourceNotFoundException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.CartRepository;
import com.foodhub.repository.FoodItemRepository;
import com.foodhub.repository.UserRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CartService {

    private static final int MAX_QTY = 50;

    private final CartRepository carts;
    private final FoodItemRepository foods;
    private final UserRepository users;
    private final EntityMapper mapper;

    public CartService(CartRepository carts, FoodItemRepository foods, UserRepository users, EntityMapper mapper) {
        this.carts = carts;
        this.foods = foods;
        this.users = users;
        this.mapper = mapper;
    }

    @Transactional
    public CartResponse getCart() {
        return mapper.toCart(getOrCreate());
    }

    /** Adds quantity to an existing line, or creates the line. A cart holds items from ONE restaurant only. */
    @Transactional
    public CartResponse addItem(CartItemRequest req) {
        Cart cart = getOrCreate();
        FoodItem food = foods.findById(req.foodItemId()).orElseThrow(() -> new ResourceNotFoundException("Food item not found"));
        if (!food.isAvailable() || !food.getRestaurant().isAvailable()) {
            throw new BadRequestException("This item is currently unavailable");
        }
        if (cart.getRestaurant() != null && !cart.getRestaurant().getId().equals(food.getRestaurant().getId())
                && !cart.getItems().isEmpty()) {
            throw new BadRequestException("Your cart has items from another restaurant. Clear the cart first.");
        }
        cart.setRestaurant(food.getRestaurant());
        CartItem line = cart.getItems().stream().filter(i -> i.getFoodItem().getId().equals(food.getId())).findFirst().orElse(null);
        if (line == null) {
            line = new CartItem();
            line.setCart(cart);
            line.setFoodItem(food);
            line.setQuantity(req.quantity());
            cart.getItems().add(line);
        } else {
            line.setQuantity(Math.min(MAX_QTY, line.getQuantity() + req.quantity()));
        }
        return mapper.toCart(carts.save(cart));
    }

    /** Sets an exact quantity (used by the +/- buttons). */
    @Transactional
    public CartResponse setQuantity(Long foodItemId, int quantity) {
        if (quantity < 1 || quantity > MAX_QTY) {
            throw new BadRequestException("Quantity must be between 1 and " + MAX_QTY);
        }
        Cart cart = getOrCreate();
        CartItem line = cart.getItems().stream().filter(i -> i.getFoodItem().getId().equals(foodItemId)).findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Item is not in your cart"));
        line.setQuantity(quantity);
        return mapper.toCart(carts.save(cart));
    }

    @Transactional
    public CartResponse removeItem(Long foodItemId) {
        Cart cart = getOrCreate();
        cart.getItems().removeIf(i -> i.getFoodItem().getId().equals(foodItemId));
        if (cart.getItems().isEmpty()) {
            cart.setRestaurant(null);
        }
        return mapper.toCart(carts.save(cart));
    }

    @Transactional
    public CartResponse clear() {
        Cart cart = getOrCreate();
        cart.getItems().clear();
        cart.setRestaurant(null);
        return mapper.toCart(carts.save(cart));
    }

    /** Used by OrderService inside its own transaction. */
    Cart getOrCreate() {
        Long userId = CurrentUser.get().getId();
        return carts.findByUserId(userId).orElseGet(() -> {
            Cart c = new Cart();
            c.setUser(users.getReferenceById(userId));
            return carts.save(c);
        });
    }
}
