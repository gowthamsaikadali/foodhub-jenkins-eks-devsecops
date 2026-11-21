import api from './api';

export const catalogService = {
  restaurants: (q) => api.get('/restaurants', { params: q ? { q } : {} }).then((r) => r.data),
  restaurant: (id) => api.get(`/restaurants/${id}`).then((r) => r.data),
  menu: (id) => api.get(`/restaurants/${id}/foods`).then((r) => r.data),
  searchFoods: (q, categoryId) =>
    api.get('/foods', { params: { q: q || undefined, categoryId: categoryId || undefined } }).then((r) => r.data),
  categories: () => api.get('/categories').then((r) => r.data),
};
