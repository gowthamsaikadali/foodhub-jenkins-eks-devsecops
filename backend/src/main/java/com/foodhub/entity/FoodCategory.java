package com.foodhub.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "food_categories")
@Getter @Setter @NoArgsConstructor
public class FoodCategory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 60)
    private String name;

    @Column(length = 300)
    private String description;
}
