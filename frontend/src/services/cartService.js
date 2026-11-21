import api from './api';

export const cartService = {
  get: () => api.get('/cart').then((r) => r.data),
  add: (foodItemId, quantity = 1) => api.post('/cart/items', { foodItemId, quantity }).then((r) => r.data),
  setQuantity: (foodItemId, quantity) =>
    api.put(`/cart/items/${foodItemId}`, null, { params: { quantity } }).then((r) => r.data),
  remove: (foodItemId) => api.delete(`/cart/items/${foodItemId}`).then((r) => r.data),
  clear: () => api.delete('/cart').then((r) => r.data),
};
