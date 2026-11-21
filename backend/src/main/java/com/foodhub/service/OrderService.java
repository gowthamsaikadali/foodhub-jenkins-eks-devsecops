package com.foodhub.service;

import com.foodhub.dto.OrderResponse;
import com.foodhub.dto.PlaceOrderRequest;
import com.foodhub.entity.*;
import com.foodhub.exception.BadRequestException;
import com.foodhub.exception.ResourceNotFoundException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.CartRepository;
import com.foodhub.repository.OrderRepository;
import com.foodhub.repository.PaymentRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class OrderService {

    private final OrderRepository orders;
    private final CartRepository carts;
    private final PaymentRepository payments;
    private final OrderPricing pricing;
    private final EntityMapper mapper;

    public OrderService(OrderRepository orders, CartRepository carts, PaymentRepository payments,
                        OrderPricing pricing, EntityMapper mapper) {
        this.orders = orders;
        this.carts = carts;
        this.payments = payments;
        this.pricing = pricing;
        this.mapper = mapper;
    }

    /**
     * Turns the logged-in user's server-side cart into an order. ONE transaction: if anything fails
     * (item unavailable, DB error) nothing is saved and the cart is untouched.
     * Prices come from the database, never from the request.
     */
    @Transactional
    public OrderResponse place(PlaceOrderRequest req) {
        User me = CurrentUser.get();
        Cart cart = carts.findByUserId(me.getId()).orElseThrow(() -> new BadRequestException("Your cart is empty"));
        if (cart.getItems().isEmpty() || cart.getRestaurant() == null) {
            throw new BadRequestException("Your cart is empty");
        }
        Restaurant restaurant = cart.getRestaurant();
        if (!restaurant.isAvailable()) {
            throw new BadRequestException("This restaurant is not accepting orders right now");
        }

        Order order = new Order();
        order.setUser(me);
        order.setRestaurant(restaurant);
        order.setStatus(OrderStatus.PLACED);
        order.setDeliveryAddress(req.deliveryAddress().trim());
        order.setNotes(req.notes() == null || req.notes().isBlank() ? null : req.notes().trim());

        BigDecimal subtotal = BigDecimal.ZERO;
        for (CartItem ci : cart.getItems()) {
            FoodItem food = ci.getFoodItem();
            if (!food.isAvailable()) {
                throw new BadRequestException("'" + food.getName() + "' is no longer available. Please remove it from your cart.");
            }
            BigDecimal line = food.getPrice().multiply(BigDecimal.valueOf(ci.getQuantity()));
            OrderItem oi = new OrderItem();
            oi.setOrder(order);
            oi.setFoodItem(food);
            oi.setFoodName(food.getName());       // snapshot
            oi.setUnitPrice(food.getPrice());     // snapshot
            oi.setQuantity(ci.getQuantity());
            oi.setLineTotal(line);
            order.getItems().add(oi);
            subtotal = subtotal.add(line);
        }

        OrderPricing.Totals t = pricing.calculate(subtotal);
        order.setSubtotal(t.subtotal());
        order.setDeliveryFee(t.deliveryFee());
        order.setTax(t.tax());
        order.setTotalAmount(t.total());
        Order saved = orders.save(order);

        Payment payment = new Payment();
        payment.setOrder(saved);
        payment.setMethod(req.paymentMethod());
        payment.setStatus(PaymentStatus.PENDING);
        payment.setAmount(saved.getTotalAmount());
        saved.setPayment(payments.save(payment));

        cart.getItems().clear();
        cart.setRestaurant(null);
        carts.save(cart);

        return mapper.toOrder(saved);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> myOrders() {
        return orders.findByUserIdOrderByCreatedAtDesc(CurrentUser.get().getId()).stream().map(mapper::toOrder).toList();
    }

    /** Customers see only their own orders. An admin can see orders of restaurants they own. */
    @Transactional(readOnly = true)
    public OrderResponse getOne(Long id) {
        Order o = find(id);
        assertCanView(o);
        return mapper.toOrder(o);
    }

    /** Customer cancels their own order, only while it is still PLACED. */
    @Transactional
    public OrderResponse cancelMine(Long id) {
        Order o = find(id);
        if (!o.getUser().getId().equals(CurrentUser.get().getId())) {
            throw new ResourceNotFoundException("Order not found"); // do not reveal other people's order ids
        }
        if (o.getStatus() != OrderStatus.PLACED) {
            throw new BadRequestException("Only orders that are still PLACED can be cancelled");
        }
        return mapper.toOrder(moveTo(o, OrderStatus.CANCELLED));
    }

    // ---------- admin ----------

    @Transactional(readOnly = true)
    public List<OrderResponse> adminOrders() {
        return orders.findByRestaurantOwnerIdOrderByCreatedAtDesc(CurrentUser.get().getId())
                .stream().map(mapper::toOrder).toList();
    }

    @Transactional
    public OrderResponse updateStatus(Long id, OrderStatus next) {
        Order o = find(id);
        User owner = o.getRestaurant().getOwner();
        if (owner == null || !owner.getId().equals(CurrentUser.get().getId())) {
            throw new AccessDeniedException("This order does not belong to your restaurant");
        }
        if (!o.getStatus().canMoveTo(next)) {
            throw new BadRequestException("Cannot change order status from " + o.getStatus() + " to " + next);
        }
        return mapper.toOrder(moveTo(o, next));
    }

    // ---------- helpers ----------

    private Order moveTo(Order o, OrderStatus next) {
        o.setStatus(next);
        Payment p = o.getPayment();
        if (p != null && p.getStatus() == PaymentStatus.PENDING) {
            if (next == OrderStatus.DELIVERED && p.getMethod() == PaymentMethod.CASH_ON_DELIVERY) {
                p.setStatus(PaymentStatus.SUCCESS);   // cash collected at the door
            } else if (next == OrderStatus.CANCELLED || next == OrderStatus.REJECTED) {
                p.setStatus(PaymentStatus.FAILED);    // nothing was collected
            }
            payments.save(p);
        }
        return orders.save(o);
    }

    private Order find(Long id) {
        return orders.findById(id).orElseThrow(() -> new ResourceNotFoundException("Order not found"));
    }

    private void assertCanView(Order o) {
        User me = CurrentUser.get();
        boolean mine = o.getUser().getId().equals(me.getId());
        User owner = o.getRestaurant().getOwner();
        boolean restaurantAdmin = me.isAdmin() && owner != null && owner.getId().equals(me.getId());
        if (!mine && !restaurantAdmin) {
            throw new ResourceNotFoundException("Order not found");
        }
    }
}
