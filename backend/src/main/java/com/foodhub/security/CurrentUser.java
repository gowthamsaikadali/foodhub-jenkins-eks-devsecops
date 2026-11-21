package com.foodhub.security;

import com.foodhub.entity.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/** Helper to read the logged-in user inside services. */
public final class CurrentUser {
    private CurrentUser() { }

    public static User get() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal p)) {
            throw new org.springframework.security.access.AccessDeniedException("Not authenticated");
        }
        return p.getUser();
    }
}
