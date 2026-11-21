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
