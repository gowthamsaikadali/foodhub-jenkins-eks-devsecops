package com.foodhub.controller;

import com.foodhub.dto.CategoryResponse;
import com.foodhub.dto.FoodResponse;
import com.foodhub.service.FoodService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@Tag(name = "Foods (public)")
public class FoodController {

    private final FoodService foods;

    public FoodController(FoodService foods) {
        this.foods = foods;
    }

    @GetMapping("/foods")
    public List<FoodResponse> search(@RequestParam(required = false) String q,
                                     @RequestParam(required = false) Long categoryId) {
        return foods.search(q, categoryId);
    }

    @GetMapping("/categories")
    public List<CategoryResponse> categories() {
        return foods.listCategories();
    }
}
