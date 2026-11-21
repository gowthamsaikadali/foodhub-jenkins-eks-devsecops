package com.foodhub.controller;

import com.foodhub.dto.UpdateProfileRequest;
import com.foodhub.dto.UserResponse;
import com.foodhub.service.ProfileService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me")
@Tag(name = "Profile")
public class ProfileController {

    private final ProfileService profile;

    public ProfileController(ProfileService profile) {
        this.profile = profile;
    }

    @GetMapping
    public UserResponse me() {
        return profile.me();
    }

    @PutMapping
    public UserResponse update(@Valid @RequestBody UpdateProfileRequest req) {
        return profile.update(req);
    }
}
