package com.foodhub.controller;

import com.foodhub.dto.*;
import com.foodhub.service.FoodService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@Tag(name = "Admin - Foods and categories")
public class AdminFoodController {

    private final FoodService foods;

    public AdminFoodController(FoodService foods) {
        this.foods = foods;
    }

    @GetMapping("/foods")
    public List<FoodResponse> menu(@RequestParam Long restaurantId) {
        return foods.adminMenu(restaurantId);
    }

    @PostMapping("/foods")
    public ResponseEntity<FoodResponse> create(@Valid @RequestBody FoodRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(foods.create(req));
    }

    @PutMapping("/foods/{id}")
    public FoodResponse update(@PathVariable Long id, @Valid @RequestBody FoodRequest req) {
        return foods.update(id, req);
    }

    @DeleteMapping("/foods/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        foods.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/categories")
    public ResponseEntity<CategoryResponse> createCategory(@Valid @RequestBody CategoryRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(foods.createCategory(req));
    }

    @PutMapping("/categories/{id}")
    public CategoryResponse updateCategory(@PathVariable Long id, @Valid @RequestBody CategoryRequest req) {
        return foods.updateCategory(id, req);
    }

    @DeleteMapping("/categories/{id}")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long id) {
        foods.deleteCategory(id);
        return ResponseEntity.noContent().build();
    }
}
