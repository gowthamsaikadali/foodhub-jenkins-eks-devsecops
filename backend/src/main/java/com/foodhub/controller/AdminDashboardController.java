package com.foodhub.controller;

import com.foodhub.dto.DashboardResponse;
import com.foodhub.dto.UserResponse;
import com.foodhub.service.DashboardService;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@Tag(name = "Admin - Dashboard")
public class AdminDashboardController {

    private final DashboardService dashboard;

    public AdminDashboardController(DashboardService dashboard) {
        this.dashboard = dashboard;
    }

    @GetMapping("/dashboard")
    public DashboardResponse stats() {
        return dashboard.stats();
    }

    @GetMapping("/customers")
    public List<UserResponse> customers() {
        return dashboard.myCustomers();
    }
}
