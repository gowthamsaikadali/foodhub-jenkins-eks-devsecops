package com.foodhub.validation;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StrongPasswordValidatorTest {

    private final StrongPasswordValidator validator = new StrongPasswordValidator();

    @Test
    void acceptsLetterAndDigitWithEnoughLength() {
        assertThat(validator.isValid("Passw0rd1", null)).isTrue();
    }

    @Test
    void rejectsShortOrMissingCharacterClasses() {
        assertThat(validator.isValid("Ab1", null)).isFalse();
        assertThat(validator.isValid("onlyletters", null)).isFalse();
        assertThat(validator.isValid("12345678", null)).isFalse();
    }

    @Test
    void rejectsLongerThanBcryptLimit() {
        assertThat(validator.isValid("a1".repeat(40), null)).isFalse();
    }
}
