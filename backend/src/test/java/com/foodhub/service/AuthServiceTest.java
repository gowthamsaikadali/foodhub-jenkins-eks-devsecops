package com.foodhub.service;

import com.foodhub.dto.AuthResponse;
import com.foodhub.dto.RegisterRequest;
import com.foodhub.entity.Role;
import com.foodhub.entity.User;
import com.foodhub.exception.ConflictException;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.RoleRepository;
import com.foodhub.repository.UserRepository;
import com.foodhub.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock UserRepository users;
    @Mock RoleRepository roles;
    @Mock AuthenticationManager authManager;

    private final PasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final JwtService jwt = new JwtService("unit-test-secret-which-is-at-least-32-chars-long", 5);
    private AuthService service;

    @BeforeEach
    void setUp() {
        service = new AuthService(users, roles, encoder, authManager, jwt, new EntityMapper());
    }

    @Test
    void registerCreatesCustomerWithHashedPassword() {
        when(users.existsByEmailIgnoreCase("new@foodhub.com")).thenReturn(false);
        when(roles.findByName("ROLE_CUSTOMER")).thenReturn(Optional.of(new Role(2L, "ROLE_CUSTOMER")));
        when(users.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        AuthResponse res = service.register(new RegisterRequest("New User", "New@FoodHub.com", "Passw0rd1", ""));

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getEmail()).isEqualTo("new@foodhub.com");
        assertThat(saved.getValue().getPasswordHash()).isNotEqualTo("Passw0rd1");
        assertThat(encoder.matches("Passw0rd1", saved.getValue().getPasswordHash())).isTrue();
        assertThat(saved.getValue().isAdmin()).isFalse();
        assertThat(res.token()).isNotBlank();
        assertThat(res.user().roles()).containsExactly("ROLE_CUSTOMER");
    }

    @Test
    void registerRejectsDuplicateEmail() {
        when(users.existsByEmailIgnoreCase("dup@foodhub.com")).thenReturn(true);
        assertThatThrownBy(() -> service.register(new RegisterRequest("Dup", "dup@foodhub.com", "Passw0rd1", null)))
                .isInstanceOf(ConflictException.class);
        verify(users, never()).save(any());
    }
}
