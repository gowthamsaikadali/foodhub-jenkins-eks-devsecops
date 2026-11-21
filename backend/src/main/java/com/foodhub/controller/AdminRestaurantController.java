package com.foodhub.controller;

import com.foodhub.dto.RestaurantRequest;
import com.foodhub.dto.RestaurantResponse;
import com.foodhub.service.RestaurantService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Everything under /api/admin/** requires ROLE_ADMIN (see SecurityConfig). Ownership is checked in the service. */
@RestController
@RequestMapping("/api/admin/restaurants")
@Tag(name = "Admin - Restaurants")
public class AdminRestaurantController {

    private final RestaurantService restaurants;

    public AdminRestaurantController(RestaurantService restaurants) {
        this.restaurants = restaurants;
    }

    @GetMapping
    public List<RestaurantResponse> mine() {
        return restaurants.listMine();
    }

    @PostMapping
    public ResponseEntity<RestaurantResponse> create(@Valid @RequestBody RestaurantRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(restaurants.create(req));
    }

    @PutMapping("/{id}")
    public RestaurantResponse update(@PathVariable Long id, @Valid @RequestBody RestaurantRequest req) {
        return restaurants.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        restaurants.delete(id);
        return ResponseEntity.noContent().build();
    }
}
