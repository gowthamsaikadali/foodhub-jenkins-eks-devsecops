package com.foodhub.security;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private static final String SECRET = "unit-test-secret-which-is-at-least-32-chars-long";

    @Test
    void roundTripReturnsSubject() {
        JwtService jwt = new JwtService(SECRET, 5);
        String token = jwt.generateToken("a@b.com");
        assertThat(jwt.validateAndGetSubject(token)).contains("a@b.com");
    }

    @Test
    void tamperedTokenIsRejected() {
        JwtService jwt = new JwtService(SECRET, 5);
        String token = jwt.generateToken("a@b.com");
        assertThat(jwt.validateAndGetSubject(token + "x")).isEmpty();
    }

    @Test
    void tokenSignedWithAnotherKeyIsRejected() {
        String token = new JwtService("another-secret-that-is-also-32-characters-long!", 5).generateToken("a@b.com");
        assertThat(new JwtService(SECRET, 5).validateAndGetSubject(token)).isEmpty();
    }

    @Test
    void expiredTokenIsRejected() {
        JwtService jwt = new JwtService(SECRET, -1);
        assertThat(jwt.validateAndGetSubject(jwt.generateToken("a@b.com"))).isEmpty();
    }

    @Test
    void shortSecretIsRefused() {
        assertThatThrownBy(() -> new JwtService("short", 5)).isInstanceOf(IllegalStateException.class);
    }
}
