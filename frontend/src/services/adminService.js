import api from './api';

export const adminService = {
  dashboard: () => api.get('/admin/dashboard').then((r) => r.data),
  customers: () => api.get('/admin/customers').then((r) => r.data),

  restaurants: () => api.get('/admin/restaurants').then((r) => r.data),
  createRestaurant: (p) => api.post('/admin/restaurants', p).then((r) => r.data),
  updateRestaurant: (id, p) => api.put(`/admin/restaurants/${id}`, p).then((r) => r.data),
  deleteRestaurant: (id) => api.delete(`/admin/restaurants/${id}`),

  foods: (restaurantId) => api.get('/admin/foods', { params: { restaurantId } }).then((r) => r.data),
  createFood: (p) => api.post('/admin/foods', p).then((r) => r.data),
  updateFood: (id, p) => api.put(`/admin/foods/${id}`, p).then((r) => r.data),
  deleteFood: (id) => api.delete(`/admin/foods/${id}`),

  createCategory: (p) => api.post('/admin/categories', p).then((r) => r.data),
  deleteCategory: (id) => api.delete(`/admin/categories/${id}`),

  orders: () => api.get('/admin/orders').then((r) => r.data),
  updateOrderStatus: (id, status) => api.patch(`/admin/orders/${id}/status`, { status }).then((r) => r.data),
};
