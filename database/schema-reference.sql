-- Concatenation of the three Flyway migrations, for reading only. Flyway runs the originals.
-- FoodHub schema (MySQL 8.x, InnoDB, utf8mb4). Money columns are DECIMAL, never FLOAT.

CREATE TABLE roles (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  name VARCHAR(30)  NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT uk_roles_name UNIQUE (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  full_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL,
  password_hash VARCHAR(100) NOT NULL,
  phone         VARCHAR(20)  NULL,
  address       VARCHAR(300) NULL,
  enabled       TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT uk_users_email UNIQUE (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_roles (
  user_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE restaurants (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  owner_id    BIGINT        NULL,
  name        VARCHAR(120)  NOT NULL,
  description VARCHAR(1000) NULL,
  cuisine     VARCHAR(60)   NULL,
  address     VARCHAR(300)  NOT NULL,
  city        VARCHAR(80)   NOT NULL,
  phone       VARCHAR(20)   NULL,
  image_url   VARCHAR(500)  NULL,
  rating      DECIMAL(2,1)  NOT NULL DEFAULT 4.0,
  available   TINYINT(1)    NOT NULL DEFAULT 1,
  created_at  DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at  DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_restaurants_owner (owner_id),
  KEY idx_restaurants_city (city),
  KEY idx_restaurants_name (name),
  CONSTRAINT fk_restaurants_owner FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_restaurants_rating CHECK (rating >= 0 AND rating <= 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE food_categories (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  name        VARCHAR(60)   NOT NULL,
  description VARCHAR(300)  NULL,
  PRIMARY KEY (id),
  CONSTRAINT uk_food_categories_name UNIQUE (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE food_items (
  id            BIGINT         NOT NULL AUTO_INCREMENT,
  restaurant_id BIGINT         NOT NULL,
  category_id   BIGINT         NULL,
  name          VARCHAR(120)   NOT NULL,
  description   VARCHAR(1000)  NULL,
  price         DECIMAL(10,2)  NOT NULL,
  image_url     VARCHAR(500)   NULL,
  available     TINYINT(1)     NOT NULL DEFAULT 1,
  created_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_food_items_restaurant (restaurant_id),
  KEY idx_food_items_category (category_id),
  KEY idx_food_items_name (name),
  CONSTRAINT fk_food_items_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id) ON DELETE CASCADE,
  CONSTRAINT fk_food_items_category   FOREIGN KEY (category_id)   REFERENCES food_categories (id) ON DELETE SET NULL,
  CONSTRAINT chk_food_items_price CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE carts (
  id            BIGINT      NOT NULL AUTO_INCREMENT,
  user_id       BIGINT      NOT NULL,
  restaurant_id BIGINT      NULL,
  updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT uk_carts_user UNIQUE (user_id),
  CONSTRAINT fk_carts_user       FOREIGN KEY (user_id)       REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_carts_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cart_items (
  id           BIGINT NOT NULL AUTO_INCREMENT,
  cart_id      BIGINT NOT NULL,
  food_item_id BIGINT NOT NULL,
  quantity     INT    NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT uk_cart_items_cart_food UNIQUE (cart_id, food_item_id),
  CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id)      REFERENCES carts (id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_food FOREIGN KEY (food_item_id) REFERENCES food_items (id) ON DELETE CASCADE,
  CONSTRAINT chk_cart_items_qty CHECK (quantity > 0 AND quantity <= 50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
  id               BIGINT         NOT NULL AUTO_INCREMENT,
  user_id          BIGINT         NOT NULL,
  restaurant_id    BIGINT         NOT NULL,
  status           VARCHAR(20)    NOT NULL,
  subtotal         DECIMAL(10,2)  NOT NULL,
  delivery_fee     DECIMAL(10,2)  NOT NULL,
  tax              DECIMAL(10,2)  NOT NULL,
  total_amount     DECIMAL(10,2)  NOT NULL,
  delivery_address VARCHAR(500)   NOT NULL,
  notes            VARCHAR(500)   NULL,
  created_at       DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at       DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_orders_user (user_id),
  KEY idx_orders_restaurant (restaurant_id),
  KEY idx_orders_status (status),
  KEY idx_orders_created (created_at),
  CONSTRAINT fk_orders_user       FOREIGN KEY (user_id)       REFERENCES users (id),
  CONSTRAINT fk_orders_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
  CONSTRAINT chk_orders_status CHECK (status IN ('PLACED','CONFIRMED','PREPARING','READY','DELIVERED','CANCELLED','REJECTED')),
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_items (
  id           BIGINT         NOT NULL AUTO_INCREMENT,
  order_id     BIGINT         NOT NULL,
  food_item_id BIGINT         NULL,
  food_name    VARCHAR(120)   NOT NULL,
  unit_price   DECIMAL(10,2)  NOT NULL,
  quantity     INT            NOT NULL,
  line_total   DECIMAL(10,2)  NOT NULL,
  PRIMARY KEY (id),
  KEY idx_order_items_order (order_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)     REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_food  FOREIGN KEY (food_item_id) REFERENCES food_items (id) ON DELETE SET NULL,
  CONSTRAINT chk_order_items_qty CHECK (quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments (
  id              BIGINT         NOT NULL AUTO_INCREMENT,
  order_id        BIGINT         NOT NULL,
  method          VARCHAR(20)    NOT NULL,
  status          VARCHAR(20)    NOT NULL,
  amount          DECIMAL(10,2)  NOT NULL,
  transaction_ref VARCHAR(60)    NULL,
  created_at      DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at      DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT uk_payments_order UNIQUE (order_id),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT chk_payments_method CHECK (method IN ('CASH_ON_DELIVERY','SIMULATED_ONLINE')),
  CONSTRAINT chk_payments_status CHECK (status IN ('PENDING','SUCCESS','FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO roles (name) VALUES ('ROLE_CUSTOMER'), ('ROLE_ADMIN');
-- Sample catalogue. owner_id is NULL here; DataInitializer assigns these restaurants to the seeded admin.
INSERT INTO food_categories (name, description) VALUES
 ('Starters',  'Light bites to begin your meal'),
 ('Main Course', 'Hearty main dishes'),
 ('Biryani & Rice', 'Rice based specialities'),
 ('Pizza', 'Freshly baked pizzas'),
 ('Desserts', 'Sweet endings'),
 ('Beverages', 'Hot and cold drinks');

INSERT INTO restaurants (name, description, cuisine, address, city, phone, image_url, rating, available) VALUES
 ('Hyderabad Spice House', 'Authentic Hyderabadi dum biryani and kebabs.', 'Hyderabadi', '12 Banjara Hills Road', 'Hyderabad', '9000000001', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 4.6, 1),
 ('Pizza Corner',          'Wood-fired pizzas and Italian favourites.',     'Italian',    '45 Jubilee Hills',      'Hyderabad', '9000000002', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800', 4.3, 1),
 ('Green Bowl Kitchen',    'Fresh vegetarian meals and desserts.',          'Vegetarian', '8 Madhapur Main Road',  'Hyderabad', '9000000003', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800', 4.4, 1);

INSERT INTO food_items (restaurant_id, category_id, name, description, price, image_url, available)
SELECT r.id, c.id, v.name, v.description, v.price, v.image_url, 1
FROM (
  SELECT 'Hyderabad Spice House' AS rname, 'Biryani & Rice' AS cname, 'Chicken Dum Biryani' AS name, 'Slow-cooked basmati rice with spiced chicken.' AS description, 280.00 AS price, 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600' AS image_url
  UNION ALL SELECT 'Hyderabad Spice House', 'Biryani & Rice', 'Veg Dum Biryani', 'Fragrant rice with seasonal vegetables.', 220.00, 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600'
  UNION ALL SELECT 'Hyderabad Spice House', 'Starters', 'Chicken 65', 'Crispy spicy fried chicken bites.', 180.00, 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?w=600'
  UNION ALL SELECT 'Hyderabad Spice House', 'Desserts', 'Double Ka Meetha', 'Traditional bread pudding dessert.', 90.00, 'https://images.unsplash.com/photo-1666190092689-e3968aa0c32c?w=600'
  UNION ALL SELECT 'Hyderabad Spice House', 'Beverages', 'Masala Chai', 'Hot spiced milk tea.', 30.00, 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=600'
  UNION ALL SELECT 'Pizza Corner', 'Pizza', 'Margherita Pizza', 'Tomato, mozzarella and basil.', 250.00, 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600'
  UNION ALL SELECT 'Pizza Corner', 'Pizza', 'Farmhouse Pizza', 'Loaded with fresh vegetables.', 320.00, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600'
  UNION ALL SELECT 'Pizza Corner', 'Starters', 'Garlic Bread', 'Toasted bread with garlic butter.', 120.00, 'https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=600'
  UNION ALL SELECT 'Pizza Corner', 'Beverages', 'Cold Coffee', 'Chilled coffee with ice cream.', 110.00, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=600'
  UNION ALL SELECT 'Green Bowl Kitchen', 'Main Course', 'Paneer Butter Masala', 'Cottage cheese in rich tomato gravy.', 240.00, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600'
  UNION ALL SELECT 'Green Bowl Kitchen', 'Main Course', 'Dal Tadka', 'Yellow lentils tempered with spices.', 160.00, 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600'
  UNION ALL SELECT 'Green Bowl Kitchen', 'Desserts', 'Gulab Jamun', 'Soft milk dumplings in sugar syrup.', 80.00, 'https://images.unsplash.com/photo-1666190092689-e3968aa0c32c?w=600'
  UNION ALL SELECT 'Green Bowl Kitchen', 'Beverages', 'Fresh Lime Soda', 'Sweet or salted.', 60.00, 'https://images.unsplash.com/photo-1523371054106-bbf80586c38c?w=600'
) v
JOIN restaurants r ON r.name = v.rname
JOIN food_categories c ON c.name = v.cname;
