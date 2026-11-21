package com.foodhub.service;

import com.foodhub.dto.UpdateProfileRequest;
import com.foodhub.dto.UserResponse;
import com.foodhub.entity.User;
import com.foodhub.mapper.EntityMapper;
import com.foodhub.repository.UserRepository;
import com.foodhub.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileService {

    private final UserRepository users;
    private final EntityMapper mapper;

    public ProfileService(UserRepository users, EntityMapper mapper) {
        this.users = users;
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public UserResponse me() {
        return mapper.toUser(users.findById(CurrentUser.get().getId()).orElseThrow());
    }

    @Transactional
    public UserResponse update(UpdateProfileRequest req) {
        User u = users.findById(CurrentUser.get().getId()).orElseThrow();
        u.setFullName(req.fullName().trim());
        u.setPhone(req.phone() == null || req.phone().isBlank() ? null : req.phone().trim());
        u.setAddress(req.address() == null || req.address().isBlank() ? null : req.address().trim());
        return mapper.toUser(users.save(u));
    }
}
