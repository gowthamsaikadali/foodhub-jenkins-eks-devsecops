package com.foodhub.config;

import com.foodhub.entity.Restaurant;
import com.foodhub.entity.Role;
import com.foodhub.entity.User;
import com.foodhub.repository.RestaurantRepository;
import com.foodhub.repository.RoleRepository;
import com.foodhub.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;

/**
 * Creates a demo admin and demo customer on startup ONLY when SEED_*_PASSWORD env vars are provided.
 * Passwords are never written in source code. Leave them unset in production.
 */
@Component
public class DataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private final UserRepository users;
    private final RoleRepository roles;
    private final RestaurantRepository restaurants;
    private final PasswordEncoder encoder;
    private final boolean enabled;
    private final String adminEmail;
    private final String adminPassword;
    private final String customerEmail;
    private final String customerPassword;

    public DataInitializer(UserRepository users, RoleRepository roles, RestaurantRepository restaurants,
                           PasswordEncoder encoder,
                           @Value("${app.seed.enabled}") boolean enabled,
                           @Value("${app.seed.admin-email}") String adminEmail,
                           @Value("${app.seed.admin-password}") String adminPassword,
                           @Value("${app.seed.customer-email}") String customerEmail,
                           @Value("${app.seed.customer-password}") String customerPassword) {
        this.users = users;
        this.roles = roles;
        this.restaurants = restaurants;
        this.encoder = encoder;
        this.enabled = enabled;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
        this.customerEmail = customerEmail;
        this.customerPassword = customerPassword;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            return;
        }
        if (!adminPassword.isBlank()) {
            User admin = users.findByEmailIgnoreCase(adminEmail)
                    .orElseGet(() -> create("FoodHub Admin", adminEmail, adminPassword, "ROLE_ADMIN"));
            // give the sample restaurants (owner is NULL) to the demo admin so the admin dashboard has data
            for (Restaurant r : restaurants.findAll()) {
                if (r.getOwner() == null) {
                    r.setOwner(admin);
                }
            }
        }
        if (!customerPassword.isBlank() && !users.existsByEmailIgnoreCase(customerEmail)) {
            create("Demo Customer", customerEmail, customerPassword, "ROLE_CUSTOMER");
        }
    }

    private User create(String name, String email, String rawPassword, String roleName) {
        Role role = roles.findByName(roleName).orElseThrow();
        User u = new User();
        u.setFullName(name);
        u.setEmail(email.toLowerCase());
        u.setPasswordHash(encoder.encode(rawPassword));
        u.setRoles(Set.of(role));
        log.info("Seeded demo user {} with role {}", email, roleName);
        return users.save(u);
    }
}
