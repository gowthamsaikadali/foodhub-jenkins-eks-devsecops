package com.foodhub.service;

import com.foodhub.dto.PaymentRequest;
import com.foodhub.dto.PaymentResponse;
import com.foodhub.entity.*;
import com.foodhub.exception.BadRequestException;
import com.foodhub.exception.ResourceNotFoundException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.OrderRepository;
import com.foodhub.repository.PaymentRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/** Simulated payments only. No card numbers, CVVs or real gateway are involved. */
@Service
public class PaymentService {

    private final PaymentRepository payments;
    private final OrderRepository orders;
    private final EntityMapper mapper;

    public PaymentService(PaymentRepository payments, OrderRepository orders, EntityMapper mapper) {
        this.payments = payments;
        this.orders = orders;
        this.mapper = mapper;
    }

    @Transactional
    public PaymentResponse pay(PaymentRequest req) {
        User me = CurrentUser.get();
        Order order = orders.findById(req.orderId()).orElseThrow(() -> new ResourceNotFoundException("Order not found"));
        if (!order.getUser().getId().equals(me.getId())) {
            throw new ResourceNotFoundException("Order not found");
        }
        if (order.getStatus() == OrderStatus.CANCELLED || order.getStatus() == OrderStatus.REJECTED) {
            throw new BadRequestException("This order is " + order.getStatus() + " and cannot be paid");
        }
        Payment p = payments.findByOrderId(order.getId()).orElseThrow(() -> new ResourceNotFoundException("Payment not found"));
        if (p.getMethod() != PaymentMethod.SIMULATED_ONLINE) {
            throw new BadRequestException("This order is Cash on Delivery; there is nothing to pay online");
        }
        if (p.getStatus() == PaymentStatus.SUCCESS) {
            throw new BadRequestException("This order is already paid");
        }
        if (req.simulateFailure()) {
            p.setStatus(PaymentStatus.FAILED);
            p.setTransactionRef(null);
        } else {
            p.setStatus(PaymentStatus.SUCCESS);
            p.setTransactionRef("SIM-" + UUID.randomUUID().toString().substring(0, 12).toUpperCase());
        }
        return mapper.toPayment(payments.save(p));
    }

    @Transactional(readOnly = true)
    public PaymentResponse getForOrder(Long orderId) {
        User me = CurrentUser.get();
        Order order = orders.findById(orderId).orElseThrow(() -> new ResourceNotFoundException("Order not found"));
        User owner = order.getRestaurant().getOwner();
        boolean mine = order.getUser().getId().equals(me.getId());
        boolean restaurantAdmin = me.isAdmin() && owner != null && owner.getId().equals(me.getId());
        if (!mine && !restaurantAdmin) {
            throw new ResourceNotFoundException("Order not found");
        }
        return payments.findByOrderId(orderId).map(mapper::toPayment)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));
    }
}
