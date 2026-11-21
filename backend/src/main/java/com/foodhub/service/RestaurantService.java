package com.foodhub.service;

import com.foodhub.dto.RestaurantRequest;
import com.foodhub.dto.RestaurantResponse;
import com.foodhub.entity.Restaurant;
import com.foodhub.entity.User;
import com.foodhub.exception.ConflictException;
import com.foodhub.exception.ResourceNotFoundException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.OrderRepository;
import com.foodhub.repository.RestaurantRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class RestaurantService {

    private final RestaurantRepository restaurants;
    private final OrderRepository orders;
    private final EntityMapper mapper;

    public RestaurantService(RestaurantRepository restaurants, OrderRepository orders, EntityMapper mapper) {
        this.restaurants = restaurants;
        this.orders = orders;
        this.mapper = mapper;
    }

    // ---------- public (customers) ----------

    @Transactional(readOnly = true)
    public List<RestaurantResponse> listPublic(String q) {
        List<Restaurant> list = (q == null || q.isBlank())
                ? restaurants.findByAvailableTrueOrderByNameAsc()
                : restaurants.search(q.trim());
        return list.stream().map(mapper::toRestaurant).toList();
    }

    @Transactional(readOnly = true)
    public RestaurantResponse getPublic(Long id) {
        Restaurant r = find(id);
        if (!r.isAvailable()) {
            throw new ResourceNotFoundException("Restaurant not found");
        }
        return mapper.toRestaurant(r);
    }

    // ---------- admin (only the owner's restaurants) ----------

    @Transactional(readOnly = true)
    public List<RestaurantResponse> listMine() {
        return restaurants.findByOwnerId(CurrentUser.get().getId()).stream().map(mapper::toRestaurant).toList();
    }

    @Transactional
    public RestaurantResponse create(RestaurantRequest req) {
        Restaurant r = new Restaurant();
        r.setOwner(CurrentUser.get());
        apply(r, req);
        return mapper.toRestaurant(restaurants.save(r));
    }

    @Transactional
    public RestaurantResponse update(Long id, RestaurantRequest req) {
        Restaurant r = findOwned(id);
        apply(r, req);
        return mapper.toRestaurant(restaurants.save(r));
    }

    @Transactional
    public void delete(Long id) {
        Restaurant r = findOwned(id);
        boolean hasOrders = orders.existsByRestaurantId(id);
        if (hasOrders) {
            // keep order history intact; ask the admin to hide the restaurant instead
            throw new ConflictException("This restaurant has orders and cannot be deleted. Mark it unavailable instead.");
        }
        restaurants.delete(r);
    }

    /** Loads a restaurant and checks that the logged-in admin owns it. Used by food/order services too. */
    @Transactional(readOnly = true)
    public Restaurant findOwned(Long id) {
        Restaurant r = find(id);
        User me = CurrentUser.get();
        if (r.getOwner() == null || !r.getOwner().getId().equals(me.getId())) {
            throw new AccessDeniedException("You do not own this restaurant");
        }
        return r;
    }

    private Restaurant find(Long id) {
        return restaurants.findById(id).orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
    }

    private void apply(Restaurant r, RestaurantRequest req) {
        r.setName(req.name().trim());
        r.setDescription(req.description());
        r.setCuisine(req.cuisine());
        r.setAddress(req.address().trim());
        r.setCity(req.city().trim());
        r.setPhone(req.phone() == null || req.phone().isBlank() ? null : req.phone());
        r.setImageUrl(req.imageUrl());
        if (req.available() != null) {
            r.setAvailable(req.available());
        }
    }
}
