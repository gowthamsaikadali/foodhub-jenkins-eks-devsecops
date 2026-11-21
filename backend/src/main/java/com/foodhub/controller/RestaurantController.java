package com.foodhub.controller;

import com.foodhub.dto.FoodResponse;
import com.foodhub.dto.RestaurantResponse;
import com.foodhub.service.FoodService;
import com.foodhub.service.RestaurantService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/restaurants")
@Tag(name = "Restaurants (public)")
public class RestaurantController {

    private final RestaurantService restaurants;
    private final FoodService foods;

    public RestaurantController(RestaurantService restaurants, FoodService foods) {
        this.restaurants = restaurants;
        this.foods = foods;
    }

    @GetMapping
    public List<RestaurantResponse> list(@RequestParam(required = false) String q) {
        return restaurants.listPublic(q);
    }

    @GetMapping("/{id}")
    public RestaurantResponse get(@PathVariable Long id) {
        return restaurants.getPublic(id);
    }

    @GetMapping("/{id}/foods")
    public List<FoodResponse> menu(@PathVariable Long id) {
        return foods.menuOfRestaurant(id);
    }
}
