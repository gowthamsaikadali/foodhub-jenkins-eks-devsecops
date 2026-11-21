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
