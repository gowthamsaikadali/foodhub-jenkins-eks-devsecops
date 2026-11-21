package com.foodhub.service;

import com.foodhub.config.AppProperties;
import com.foodhub.dto.OrderResponse;
import com.foodhub.dto.PlaceOrderRequest;
import com.foodhub.entity.*;
import com.foodhub.exception.BadRequestException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.CartRepository;
import com.foodhub.repository.OrderRepository;
import com.foodhub.repository.PaymentRepository;
import com.foodhub.security.UserPrincipal;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock OrderRepository orders;
    @Mock CartRepository carts;
    @Mock PaymentRepository payments;

    private OrderService service;
    private User customer;
    private User admin;
    private Restaurant restaurant;

    @BeforeEach
    void setUp() {
        OrderPricing pricing = new OrderPricing(
                new AppProperties(new BigDecimal("40.00"), new BigDecimal("500.00"), new BigDecimal("0.05")));
        service = new OrderService(orders, carts, payments, pricing, new EntityMapper());

        customer = user(1L, "cust@x.com", "ROLE_CUSTOMER");
        admin = user(2L, "admin@x.com", "ROLE_ADMIN");
        restaurant = new Restaurant();
        restaurant.setId(10L);
        restaurant.setName("Test Kitchen");
        restaurant.setOwner(admin);
        login(customer);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void placeOrderUsesDatabasePricesAndClearsCart() {
        FoodItem biryani = food(100L, "Biryani", "280.00");
        Cart cart = cartWith(biryani, 2);                       // 560.00
        when(carts.findByUserId(1L)).thenReturn(Optional.of(cart));
        when(orders.save(any(Order.class))).thenAnswer(inv -> inv.getArgument(0));
        when(payments.save(any(Payment.class))).thenAnswer(inv -> inv.getArgument(0));

        OrderResponse res = service.place(new PlaceOrderRequest("12 Test Street", null, PaymentMethod.CASH_ON_DELIVERY));

        assertThat(res.subtotal()).isEqualByComparingTo("560.00");
        assertThat(res.deliveryFee()).isEqualByComparingTo("0.00");   // free above 500
        assertThat(res.tax()).isEqualByComparingTo("28.00");
        assertThat(res.totalAmount()).isEqualByComparingTo("588.00");
        assertThat(res.status()).isEqualTo(OrderStatus.PLACED);
        assertThat(res.payment().status()).isEqualTo(PaymentStatus.PENDING);
        assertThat(cart.getItems()).isEmpty();
    }

    @Test
    void placeOrderFailsOnEmptyCart() {
        Cart empty = new Cart();
        empty.setUser(customer);
        when(carts.findByUserId(1L)).thenReturn(Optional.of(empty));
        assertThatThrownBy(() -> service.place(new PlaceOrderRequest("12 Test Street", null, PaymentMethod.CASH_ON_DELIVERY)))
                .isInstanceOf(BadRequestException.class);
        verify(orders, never()).save(any());
    }

    @Test
    void placeOrderFailsWhenItemUnavailable() {
        FoodItem gone = food(101L, "Gone", "100.00");
        gone.setAvailable(false);
        when(carts.findByUserId(1L)).thenReturn(Optional.of(cartWith(gone, 1)));
        assertThatThrownBy(() -> service.place(new PlaceOrderRequest("12 Test Street", null, PaymentMethod.CASH_ON_DELIVERY)))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("no longer available");
        verify(orders, never()).save(any());
    }

    @Test
    void customerCannotSeeSomeoneElsesOrder() {
        Order other = order(55L, user(99L, "other@x.com", "ROLE_CUSTOMER"), OrderStatus.PLACED);
        when(orders.findById(55L)).thenReturn(Optional.of(other));
        assertThatThrownBy(() -> service.getOne(55L)).hasMessage("Order not found");
    }

    @Test
    void adminCanAdvanceStatusAlongAllowedPath() {
        login(admin);
        Order o = order(56L, customer, OrderStatus.PLACED);
        when(orders.findById(56L)).thenReturn(Optional.of(o));
        when(orders.save(any(Order.class))).thenAnswer(inv -> inv.getArgument(0));

        assertThat(service.updateStatus(56L, OrderStatus.CONFIRMED).status()).isEqualTo(OrderStatus.CONFIRMED);
    }

    @Test
    void adminCannotSkipStatuses() {
        login(admin);
        when(orders.findById(57L)).thenReturn(Optional.of(order(57L, customer, OrderStatus.PLACED)));
        assertThatThrownBy(() -> service.updateStatus(57L, OrderStatus.DELIVERED)).isInstanceOf(BadRequestException.class);
    }

    @Test
    void adminOfAnotherRestaurantIsDenied() {
        login(user(3L, "other-admin@x.com", "ROLE_ADMIN"));
        when(orders.findById(58L)).thenReturn(Optional.of(order(58L, customer, OrderStatus.PLACED)));
        assertThatThrownBy(() -> service.updateStatus(58L, OrderStatus.CONFIRMED)).isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void deliveringACashOrderMarksPaymentSuccessful() {
        login(admin);
        Order o = order(59L, customer, OrderStatus.READY);
        Payment p = new Payment();
        p.setOrder(o);
        p.setMethod(PaymentMethod.CASH_ON_DELIVERY);
        p.setStatus(PaymentStatus.PENDING);
        p.setAmount(o.getTotalAmount());
        o.setPayment(p);
        when(orders.findById(59L)).thenReturn(Optional.of(o));
        when(orders.save(any(Order.class))).thenAnswer(inv -> inv.getArgument(0));

        service.updateStatus(59L, OrderStatus.DELIVERED);

        assertThat(p.getStatus()).isEqualTo(PaymentStatus.SUCCESS);
    }

    @Test
    void customerCanCancelOnlyPlacedOrders() {
        when(orders.findById(60L)).thenReturn(Optional.of(order(60L, customer, OrderStatus.PREPARING)));
        assertThatThrownBy(() -> service.cancelMine(60L)).isInstanceOf(BadRequestException.class);
    }

    // ---------- helpers ----------

    private void login(User u) {
        UserPrincipal p = new UserPrincipal(u);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(p, null, p.getAuthorities()));
    }

    private static User user(Long id, String email, String role) {
        User u = new User();
        u.setId(id);
        u.setEmail(email);
        u.setFullName(email);
        u.setPasswordHash("x");
        u.setRoles(Set.of(new Role(1L, role)));
        return u;
    }

    private FoodItem food(Long id, String name, String price) {
        FoodItem f = new FoodItem();
        f.setId(id);
        f.setName(name);
        f.setPrice(new BigDecimal(price));
        f.setRestaurant(restaurant);
        return f;
    }

    private Cart cartWith(FoodItem f, int qty) {
        Cart c = new Cart();
        c.setUser(customer);
        c.setRestaurant(restaurant);
        CartItem ci = new CartItem();
        ci.setCart(c);
        ci.setFoodItem(f);
        ci.setQuantity(qty);
        c.getItems().add(ci);
        return c;
    }

    private Order order(Long id, User owner, OrderStatus status) {
        Order o = new Order();
        o.setId(id);
        o.setUser(owner);
        o.setRestaurant(restaurant);
        o.setStatus(status);
        o.setSubtotal(new BigDecimal("100.00"));
        o.setDeliveryFee(new BigDecimal("40.00"));
        o.setTax(new BigDecimal("5.00"));
        o.setTotalAmount(new BigDecimal("145.00"));
        o.setDeliveryAddress("addr");
        return o;
    }
}
