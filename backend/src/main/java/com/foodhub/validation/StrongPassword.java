package com.foodhub.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.*;

@Documented
@Constraint(validatedBy = StrongPasswordValidator.class)
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
public @interface StrongPassword {
    String message() default "must be 8-72 characters and contain at least one letter and one digit";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
