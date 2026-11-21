package com.foodhub;

import com.foodhub.config.AppProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AppProperties.class)
public class FoodHubApplication {
    public static void main(String[] args) {
        SpringApplication.run(FoodHubApplication.class, args);
    }
}
