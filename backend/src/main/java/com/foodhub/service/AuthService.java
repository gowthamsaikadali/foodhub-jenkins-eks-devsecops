package com.foodhub.service;

import com.foodhub.dto.*;
import com.foodhub.entity.Role;
import com.foodhub.entity.User;
import com.foodhub.exception.ConflictException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.RoleRepository;
import com.foodhub.repository.UserRepository;
import com.foodhub.security.JwtService;
import com.foodhub.security.UserPrincipal;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;

@Service
public class AuthService {

    private final UserRepository users;
    private final RoleRepository roles;
    private final PasswordEncoder encoder;
    private final AuthenticationManager authManager;
    private final JwtService jwt;
    private final EntityMapper mapper;

    public AuthService(UserRepository users, RoleRepository roles, PasswordEncoder encoder,
                       AuthenticationManager authManager, JwtService jwt, EntityMapper mapper) {
        this.users = users;
        this.roles = roles;
        this.encoder = encoder;
        this.authManager = authManager;
        this.jwt = jwt;
        this.mapper = mapper;
    }

    /** Public registration always creates a CUSTOMER. Admins are never self-registered. */
    @Transactional
    public AuthResponse register(RegisterRequest req) {
        String email = req.email().trim().toLowerCase();
        if (users.existsByEmailIgnoreCase(email)) {
            throw new ConflictException("An account with this email already exists");
        }
        Role customer = roles.findByName("ROLE_CUSTOMER").orElseThrow(() -> new IllegalStateException("Roles not seeded"));
        User u = new User();
        u.setFullName(req.fullName().trim());
        u.setEmail(email);
        u.setPasswordHash(encoder.encode(req.password()));
        u.setPhone(blankToNull(req.phone()));
        u.setRoles(Set.of(customer));
        users.save(u);
        return tokenFor(u);
    }

    public AuthResponse login(LoginRequest req) {
        Authentication auth = authManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.email().trim().toLowerCase(), req.password()));
        User user = ((UserPrincipal) auth.getPrincipal()).getUser();
        return tokenFor(user);
    }

    private AuthResponse tokenFor(User u) {
        return new AuthResponse(jwt.generateToken(u.getEmail()), "Bearer", jwt.ttlSeconds(), mapper.toUser(u));
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
