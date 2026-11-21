import api from './api';

export const orderService = {
  place: (payload) => api.post('/orders', payload).then((r) => r.data),
  mine: () => api.get('/orders/my-orders').then((r) => r.data),
  get: (id) => api.get(`/orders/${id}`).then((r) => r.data),
  cancel: (id) => api.post(`/orders/${id}/cancel`).then((r) => r.data),
  pay: (orderId, simulateFailure = false) => api.post('/payments', { orderId, simulateFailure }).then((r) => r.data),
};
