package com.foodhub.service;

import com.foodhub.dto.*;
import com.foodhub.entity.FoodCategory;
import com.foodhub.entity.FoodItem;
import com.foodhub.entity.Restaurant;
import com.foodhub.exception.ConflictException;
import com.foodhub.exception.ResourceNotFoundException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.FoodCategoryRepository;
import com.foodhub.repository.FoodItemRepository;
import com.foodhub.repository.RestaurantRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class FoodService {

    private final FoodItemRepository foods;
    private final FoodCategoryRepository categories;
    private final RestaurantRepository restaurants;
    private final RestaurantService restaurantService;
    private final EntityMapper mapper;

    public FoodService(FoodItemRepository foods, FoodCategoryRepository categories, RestaurantRepository restaurants,
                       RestaurantService restaurantService, EntityMapper mapper) {
        this.foods = foods;
        this.categories = categories;
        this.restaurants = restaurants;
        this.restaurantService = restaurantService;
        this.mapper = mapper;
    }

    // ---------- public ----------

    @Transactional(readOnly = true)
    public List<FoodResponse> search(String q, Long categoryId) {
        return foods.search(q == null ? "" : q.trim(), categoryId).stream().map(mapper::toFood).toList();
    }

    @Transactional(readOnly = true)
    public List<FoodResponse> menuOfRestaurant(Long restaurantId) {
        Restaurant r = restaurants.findById(restaurantId)
                .orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!r.isAvailable()) {
            throw new ResourceNotFoundException("Restaurant not found");
        }
        return foods.findByRestaurantIdAndAvailableTrueOrderByNameAsc(restaurantId).stream().map(mapper::toFood).toList();
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> listCategories() {
        return categories.findAll().stream().map(mapper::toCategory).toList();
    }

    // ---------- admin: foods ----------

    /** Admin view of one of their own restaurant's menu, including unavailable items. */
    @Transactional(readOnly = true)
    public List<FoodResponse> adminMenu(Long restaurantId) {
        restaurantService.findOwned(restaurantId);
        return foods.findByRestaurantIdOrderByNameAsc(restaurantId).stream().map(mapper::toFood).toList();
    }

    @Transactional
    public FoodResponse create(FoodRequest req) {
        Restaurant r = restaurantService.findOwned(req.restaurantId());
        FoodItem f = new FoodItem();
        f.setRestaurant(r);
        apply(f, req);
        return mapper.toFood(foods.save(f));
    }

    @Transactional
    public FoodResponse update(Long id, FoodRequest req) {
        FoodItem f = findOwnedFood(id);
        // the food may not be moved to a restaurant the admin does not own
        if (!f.getRestaurant().getId().equals(req.restaurantId())) {
            f.setRestaurant(restaurantService.findOwned(req.restaurantId()));
        }
        apply(f, req);
        return mapper.toFood(foods.save(f));
    }

    @Transactional
    public void delete(Long id) {
        foods.delete(findOwnedFood(id));
    }

    // ---------- admin: categories ----------

    @Transactional
    public CategoryResponse createCategory(CategoryRequest req) {
        if (categories.existsByNameIgnoreCase(req.name().trim())) {
            throw new ConflictException("Category already exists");
        }
        FoodCategory c = new FoodCategory();
        c.setName(req.name().trim());
        c.setDescription(req.description());
        return mapper.toCategory(categories.save(c));
    }

    @Transactional
    public CategoryResponse updateCategory(Long id, CategoryRequest req) {
        FoodCategory c = categories.findById(id).orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        c.setName(req.name().trim());
        c.setDescription(req.description());
        return mapper.toCategory(categories.save(c));
    }

    @Transactional
    public void deleteCategory(Long id) {
        FoodCategory c = categories.findById(id).orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        categories.delete(c); // FK is ON DELETE SET NULL, so foods stay but become uncategorised
    }

    // ---------- helpers ----------

    private FoodItem findOwnedFood(Long id) {
        FoodItem f = foods.findById(id).orElseThrow(() -> new ResourceNotFoundException("Food item not found"));
        Restaurant r = f.getRestaurant();
        if (r.getOwner() == null || !r.getOwner().getId().equals(CurrentUser.get().getId())) {
            throw new AccessDeniedException("You do not own this restaurant");
        }
        return f;
    }

    private void apply(FoodItem f, FoodRequest req) {
        f.setName(req.name().trim());
        f.setDescription(req.description());
        f.setPrice(req.price());
        f.setImageUrl(req.imageUrl());
        if (req.available() != null) {
            f.setAvailable(req.available());
        }
        if (req.categoryId() == null) {
            f.setCategory(null);
        } else {
            f.setCategory(categories.findById(req.categoryId())
                    .orElseThrow(() -> new ResourceNotFoundException("Category not found")));
        }
    }
}
