package com.foodhub.repository;

import com.foodhub.entity.Order;
import com.foodhub.entity.OrderStatus;
import com.foodhub.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;

public interface OrderRepository extends JpaRepository<Order, Long> {

    List<Order> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<Order> findByRestaurantOwnerIdOrderByCreatedAtDesc(Long ownerId);

    boolean existsByRestaurantId(Long restaurantId);

    long countByRestaurantOwnerId(Long ownerId);

    long countByRestaurantOwnerIdAndStatusIn(Long ownerId, Collection<OrderStatus> statuses);

    @Query("select coalesce(sum(o.totalAmount), 0) from CustomerOrder o " +
           "where o.restaurant.owner.id = :ownerId and o.status not in :excluded")
    BigDecimal sumValidOrderValue(@Param("ownerId") Long ownerId, @Param("excluded") Collection<OrderStatus> excluded);

    @Query("select distinct o.user from CustomerOrder o where o.restaurant.owner.id = :ownerId")
    List<User> findCustomersOfOwner(@Param("ownerId") Long ownerId);
}
