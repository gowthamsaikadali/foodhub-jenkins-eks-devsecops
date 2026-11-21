# FoodHub database: ER diagram

Rendered automatically by GitHub (Mermaid). The real, executable schema is
`backend/src/main/resources/db/migration/V1__create_schema.sql`.

```mermaid
erDiagram
    users ||--o{ user_roles : has
    roles ||--o{ user_roles : grants
    users ||--o{ restaurants : owns
    users ||--|| carts : has
    users ||--o{ orders : places
    restaurants ||--o{ food_items : serves
    restaurants ||--o{ orders : receives
    restaurants |o--o{ carts : "cart is for"
    food_categories |o--o{ food_items : classifies
    carts ||--o{ cart_items : contains
    food_items ||--o{ cart_items : "is in"
    orders ||--|{ order_items : contains
    food_items |o--o{ order_items : "was sold as"
    orders ||--|| payments : "is paid by"

    users { bigint id PK
            varchar email UK
            varchar password_hash "BCrypt"
            varchar full_name
            varchar phone
            varchar address
            tinyint enabled }
    roles { bigint id PK
            varchar name UK "ROLE_CUSTOMER or ROLE_ADMIN" }
    user_roles { bigint user_id PK,FK
                 bigint role_id PK,FK }
    restaurants { bigint id PK
                  bigint owner_id FK
                  varchar name
                  varchar cuisine
                  varchar city
                  decimal rating
                  tinyint available }
    food_categories { bigint id PK
                      varchar name UK }
    food_items { bigint id PK
                 bigint restaurant_id FK
                 bigint category_id FK
                 varchar name
                 decimal price "DECIMAL(10,2)"
                 tinyint available }
    carts { bigint id PK
            bigint user_id FK,UK
            bigint restaurant_id FK }
    cart_items { bigint id PK
                 bigint cart_id FK
                 bigint food_item_id FK
                 int quantity "1 to 50" }
    orders { bigint id PK
             bigint user_id FK
             bigint restaurant_id FK
             varchar status "PLACED...REJECTED"
             decimal subtotal
             decimal delivery_fee
             decimal tax
             decimal total_amount
             varchar delivery_address }
    order_items { bigint id PK
                  bigint order_id FK
                  bigint food_item_id FK
                  varchar food_name "snapshot"
                  decimal unit_price "snapshot"
                  int quantity
                  decimal line_total }
    payments { bigint id PK
               bigint order_id FK,UK
               varchar method "CASH_ON_DELIVERY or SIMULATED_ONLINE"
               varchar status "PENDING SUCCESS FAILED"
               decimal amount
               varchar transaction_ref }
```

## Design decisions worth explaining in an interview

| Decision | Why |
|---|---|
| `DECIMAL(10,2)` for money | Floating-point types cannot represent 0.10 exactly; money needs exact arithmetic. |
| `order_items` stores `food_name` and `unit_price` | A snapshot: changing a menu price later must not rewrite old orders. |
| `order_items.food_item_id` is `ON DELETE SET NULL` | Deleting a menu item keeps the order history readable. |
| `orders.restaurant_id` has no cascade | A restaurant with orders cannot be deleted (the API returns 409; hide it instead). |
| `payments.order_id` is unique | Exactly one payment record per order. |
| `carts.user_id` is unique | One server-side cart per user; it follows the user between devices. |
| `CHECK` constraints on status, price, quantity | The database refuses invalid data even if a bug slips past the application. |
| Indexes on `email`, `owner_id`, `restaurant_id`, `status`, `created_at` | Fast login, admin lists, and order filtering. |
| Flyway `V1`, `V2`, `V3` migrations | Schema changes are versioned and repeatable, never edited by hand in production. |
