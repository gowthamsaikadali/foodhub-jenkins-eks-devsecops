package com.foodhub.service;

import com.foodhub.dto.DashboardResponse;
import com.foodhub.dto.UserResponse;
import com.foodhub.entity.OrderStatus;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.FoodItemRepository;
import com.foodhub.repository.OrderRepository;
import com.foodhub.repository.RestaurantRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/** Statistics are scoped to the logged-in admin's own restaurants. */
@Service
public class DashboardService {

    private static final List<OrderStatus> PENDING = List.of(OrderStatus.PLACED, OrderStatus.CONFIRMED,
            OrderStatus.PREPARING, OrderStatus.READY);

    private final OrderRepository orders;
    private final RestaurantRepository restaurants;
    private final FoodItemRepository foods;
    private final EntityMapper mapper;

    public DashboardService(OrderRepository orders, RestaurantRepository restaurants, FoodItemRepository foods,
                            EntityMapper mapper) {
        this.orders = orders;
        this.restaurants = restaurants;
        this.foods = foods;
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public DashboardResponse stats() {
        Long me = CurrentUser.get().getId();
        return new DashboardResponse(
                orders.findCustomersOfOwner(me).size(),
                restaurants.countByOwnerId(me),
                foods.countByRestaurantOwnerId(me),
                orders.countByRestaurantOwnerId(me),
                orders.countByRestaurantOwnerIdAndStatusIn(me, PENDING),
                orders.countByRestaurantOwnerIdAndStatusIn(me, List.of(OrderStatus.DELIVERED)),
                orders.sumValidOrderValue(me, List.of(OrderStatus.CANCELLED, OrderStatus.REJECTED)));
    }

    /** Customers who have ordered from this admin's restaurants. */
    @Transactional(readOnly = true)
    public List<UserResponse> myCustomers() {
        return orders.findCustomersOfOwner(CurrentUser.get().getId()).stream().map(mapper::toUser).toList();
    }
}
